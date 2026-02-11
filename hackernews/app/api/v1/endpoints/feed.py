import math
from datetime import datetime, timezone, timedelta
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel

from app.config import settings
from app.db.session import get_session
from app.repositories.interest_repo import InterestRepository
from app.repositories.story_repo import StoryRepository
from app.repositories.user_story_state_repo import UserStoryStateRepository
from app.services.auth.deps import require_user

router = APIRouter()


async def _get_session(request: Request):
    SessionLocal = request.app.state.SessionLocal
    with get_session(SessionLocal) as session:
        yield session


def _rank(points: int | None, time: int | None, read_count: int | None) -> float:
    p = points or 0
    rc = read_count or 0
    if time:
        age_hours = max(0.0, (datetime.now(timezone.utc).timestamp() - time) / 3600.0)
        recency = max(0.0, 1.0 - (age_hours / 72.0))
    else:
        recency = 0.0
    return 0.6 * math.log1p(p) + 0.3 * recency - 0.1 * math.log1p(rc)


class FeedSeenRequest(BaseModel):
    hn_ids: list[int]


class FeedDismissRequest(BaseModel):
    hn_ids: list[int]


@router.get("/feed")
async def interest_feed(
    request: Request,
    limit: int = Query(default=None, ge=1),
    session=Depends(_get_session),
    user=Depends(require_user),
):
    max_limit = 50
    limit = limit or max_limit
    if limit > max_limit:
        limit = max_limit

    # --- 1. Track Activity & Metrics ---
    redis_cache = request.app.state.redis_cache
    await redis_cache.track_active_user(user.id)

    repo = InterestRepository()
    story_repo = StoryRepository()
    state_repo = UserStoryStateRepository()
    
    interest_ids = repo.get_user_interest_ids(session, user.id)
    import logging
    logger = logging.getLogger(__name__)
    logger.info("Feed request: user_id=%s, interest_ids=%s", user.id, interest_ids)
    
    if not interest_ids:
        logger.warning("User %s has no interests selected", user.id)
        return []

    # Get interest names for tags
    interest_interests_map = {}
    for iid in interest_ids:
        obj = repo.get_by_id(session, iid)
        if obj:
            interest_interests_map[iid] = obj.name
            logger.info("Interest %s -> %s", iid, obj.name)

    # --- 2. Build shelves & track global size ---
    all_story_pools: dict[int, list[int]] = {}
    all_story_ids: set[int] = set()
    for iid in interest_ids:
        rows = repo.list_interest_stories(session, iid)
        logger.info("Interest %s: found %s stories in shelf", iid, len(rows))
        # Sort by rank locally
        ranked = sorted(rows, key=lambda r: _rank(r.points, r.time, r.read_count), reverse=True)
        ids = [r.story_hn_id for r in ranked]
        all_story_pools[iid] = ids
        all_story_ids.update(ids)

    # --- 3. Filter unseen (read + dismissed are excluded) ---
    state_map = state_repo.get_state_map(session, user.id, all_story_ids)

    def _is_excluded(hn_id: int) -> bool:
        state = state_map.get(hn_id)
        if state is None:
            return False
        return (state.read_count or 0) > 0 or state.dismissed_at is not None

    unseen_pools: dict[int, list[int]] = {}
    for iid in interest_ids:
        ids = all_story_pools.get(iid, [])
        unseen = [hid for hid in ids if not _is_excluded(hid)]
        unseen_pools[iid] = unseen

        # Signal worker only if shelf is truly low or user exhausted this interest
        if len(ids) < settings.INTEREST_STORY_LIMIT or len(unseen) == 0:
            logger.info("Signaling interest fetch for %s", iid)
            await redis_cache.signal_interest_fetch(iid)

    # --- 4. Diversity Interleaving Algorithm (unseen only) ---
    results_ids = []
    pointer = 0
    added_ids = set()
    while len(results_ids) < limit:
        exhausted_all = True
        for iid in interest_ids:
            pool = unseen_pools.get(iid, [])
            if pointer < len(pool):
                hn_id = pool[pointer]
                if hn_id not in added_ids:
                    results_ids.append(hn_id)
                    added_ids.add(hn_id)
                    exhausted_all = False
            if len(results_ids) >= limit:
                break
        if exhausted_all:
            break
        pointer += 1

    logger.info("Interleaved results count: %s", len(results_ids))

    # --- 5. Personalize Status ---
    state_map = state_repo.get_state_map(session, user.id, results_ids)
    
    id_to_interests = {}
    for iid in interest_interests_map:
        name = interest_interests_map[iid]
        for hid in unseen_pools.get(iid, []):
            if hid in added_ids:
                if hid not in id_to_interests:
                    id_to_interests[hid] = set()
                id_to_interests[hid].add(name)

    final_results = []
    for hn_id in results_ids:
        story = story_repo.get_by_hn_id(session, hn_id)
        if story is None:
            logger.warning("Story %s in interest shelf but not in stories table!", hn_id)
            continue
        
        state = state_map.get(hn_id)
        is_read = state.read_count > 0 if state else False
        
        final_results.append({
            "hn_id": story.hn_id,
            "title": story.title,
            "url": story.url,
            "score": story.raw_payload.get("score") if story.raw_payload else None,
            "time": story.raw_payload.get("time") if story.raw_payload else None,
            "is_read": is_read,
            "tags": list(id_to_interests.get(hn_id, []))
        })

    logger.info("Returning %s final results", len(final_results))
    return final_results


@router.post("/feed/seen")
async def mark_feed_seen(
    payload: FeedSeenRequest,
    session=Depends(_get_session),
    user=Depends(require_user),
):
    state_repo = UserStoryStateRepository()
    updated = state_repo.mark_seen(session, user.id, payload.hn_ids)
    return {"status": "ok", "updated": updated}


@router.post("/feed/dismiss")
async def dismiss_feed_items(
    payload: FeedDismissRequest,
    session=Depends(_get_session),
    user=Depends(require_user),
):
    state_repo = UserStoryStateRepository()
    updated = state_repo.mark_dismissed(session, user.id, payload.hn_ids)
    return {"status": "ok", "updated": updated}


@router.post("/stories/{hn_id}/read")
async def mark_story_read(hn_id: int, session=Depends(_get_session), user=Depends(require_user)):
    repo = InterestRepository()
    state_repo = UserStoryStateRepository()
    count = repo.increment_story_reads(session, hn_id)
    interest_count = repo.increment_interest_reads_for_story(session, hn_id)
    state_repo.mark_read(session, user.id, hn_id)
    return {"status": "ok", "updated": count, "interest_updated": interest_count}
