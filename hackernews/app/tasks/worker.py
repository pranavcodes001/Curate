"""Simple loop-based worker for MVP.

This worker initializes resources (DB engine/session, Redis), creates a fetcher and repository
and runs a periodic fetch cycle that persists data and primes the cache.

Graceful shutdown is handled via cancellation and signal handlers.
"""
import asyncio
import logging
import signal
import math
from datetime import datetime, timedelta, timezone
from typing import Optional
import sys
from app.config import settings
from app.db.session import get_engine, init_sessionmaker, get_session
from app.services.cache.redis import RedisCache
from app.repositories.story_repo import StoryRepository
from app.repositories.top_story_repo import TopStoryRepository
from app.services.cache.feed_cache import FeedCache
from app.services.sources.hackernews.client import AsyncHNClient
from app.services.sources.hackernews.fetcher import HNFetcher
from app.tasks.fetch_jobs import run_fetch_once
from app.repositories.summary_repo import SummaryRepository
from app.services.cache.summary_cache import SummaryCache
from app.services.ai.factory import get_ai_provider
from app.services.queue.summary_queue import dequeue_summary
from app.repositories.comment_repo import CommentRepository
from app.services.queue.saved_thread_queue import dequeue_saved_thread
from app.repositories.saved_thread_repo import SavedThreadRepository
from app.db.models.comment import Comment
from app.db.models.story import Story
from app.db.models.top_story import TopStory
from app.db.models.interest_story import InterestStory
from app.db.models.saved_thread_item import SavedThreadItem
from app.db.models.ai_summary import AiSummary
from app.db.models.search_query import SearchQuery
from app.repositories.comment_summary_repo import CommentSummaryRepository
from app.services.cache.comment_summary_cache import CommentSummaryCache
from app.repositories.interest_repo import InterestRepository
from app.services.sources.hackernews.search_client import HNSearchClient
from app.services.interests.catalog import INTEREST_GROUPS
from app.repositories.search_query_repo import SearchQueryRepository
from sqlalchemy import or_


logger = logging.getLogger(__name__)


def _rank_interest(points: int | None, time_val: int | None, read_count: int | None) -> float:
    p = points or 0
    rc = read_count or 0
    if time_val:
        age_hours = max(0.0, (datetime.now(timezone.utc).timestamp() - time_val) / 3600.0)
        recency = max(0.0, 1.0 - (age_hours / 72.0))
    else:
        recency = 0.0
    return 0.6 * math.log1p(p) + 0.3 * recency - 0.1 * math.log1p(rc)


async def _cleanup_stories(SessionLocal):
    retention_days = settings.CLEANUP_RETENTION_DAYS
    cutoff = datetime.utcnow() - timedelta(days=retention_days)
    search_repo = SearchQueryRepository()

    with get_session(SessionLocal) as session:
        # prune stale search queries
        search_repo.delete_stale(session, settings.SEARCH_DB_TTL_DAYS)

        keep_ids: set[int] = set()
        keep_ids.update([r[0] for r in session.query(TopStory.hn_id).all()])
        keep_ids.update([r[0] for r in session.query(InterestStory.story_hn_id).all()])
        keep_ids.update([r[0] for r in session.query(SavedThreadItem.hn_id).filter_by(item_type="story").all()])
        keep_ids.update([r[0] for r in session.query(AiSummary.story_hn_id).all()])
        keep_ids.update([r[0] for r in session.query(Comment.story_hn_id).all()])

        # keep stories referenced by recent search results
        for q in session.query(SearchQuery).all():
            for item in (q.results or []):
                try:
                    hn_id = int(item.get("hn_id"))
                except Exception:
                    continue
                keep_ids.add(hn_id)

        query = session.query(Story).filter(or_(Story.last_fetched_at == None, Story.last_fetched_at < cutoff))
        if keep_ids:
            query = query.filter(~Story.hn_id.in_(keep_ids))

        deleted = query.delete(synchronize_session=False)
        session.commit()
        if deleted:
            logger.info("cleanup_deleted_stories=%d", deleted)


async def _process_summary_queue(SessionLocal, redis_cache: RedisCache, story_repo: StoryRepository):
    summary_repo = SummaryRepository()
    summary_cache = SummaryCache(redis_cache, summary_repo)
    provider = get_ai_provider()
    model_version = settings.SUMMARIZATION_MODEL_VERSION
    model_name = settings.OPENAI_MODEL if settings.AI_PROVIDER == "openai" else "mock"

    for _ in range(settings.SUMMARY_QUEUE_MAX_PER_TICK):
        job = await dequeue_summary(redis_cache)
        if not job:
            break

        hn_id = job.get("hn_id") if isinstance(job, dict) else None
        if hn_id is None:
            continue

        with get_session(SessionLocal) as session:
            story = story_repo.get_by_hn_id(session, int(hn_id))
            if story is None:
                continue

            existing = summary_repo.fetch_latest(session, story.hn_id, model_version)
            if existing is not None:
                continue

            summary = await provider.summarize_story(story.raw_payload or {"id": story.hn_id, "title": story.title})
            row, _created, _updated = summary_repo.upsert_summary(session, story.hn_id, summary, model_version, model_name)

            payload = {
                "tldr": row.tldr,
                "key_points": row.key_points,
                "consensus": row.consensus,
                "model_version": row.model_version,
                "model_name": row.model_name,
                "created_at": row.created_at.isoformat() if row.created_at else None,
                "updated_at": row.updated_at.isoformat() if row.updated_at else None,
            }
            await summary_cache.set(story.hn_id, model_version, payload)


async def _ingest_comments(SessionLocal, client: AsyncHNClient, story_repo: StoryRepository):
    comment_repo = CommentRepository()
    limit = settings.COMMENTS_FETCH_LIMIT

    with get_session(SessionLocal) as session:
        story_ids = story_repo.fetch_latest_ids(session, limit=settings.FEED_LIMIT)

    for hn_id in story_ids:
        with get_session(SessionLocal) as session:
            story = story_repo.get_by_hn_id(session, hn_id)
            if story is None or not story.raw_payload:
                continue
            kids = story.raw_payload.get("kids") or []
            if not kids:
                continue
            kids = kids[:limit]

        # fetch comments concurrently
        coros = [client.fetch_item(k) for k in kids]
        try:
            results = await asyncio.gather(*coros, return_exceptions=False)
        except Exception:
            logger.exception("Failed fetching comments for story %s", hn_id)
            continue

        # persist comments
        with get_session(SessionLocal) as session:
            for raw in results:
                if not isinstance(raw, dict):
                    continue
                if raw.get("type") != "comment":
                    continue
                if raw.get("dead") or raw.get("deleted"):
                    continue
                try:
                    comment_repo.upsert(session, hn_id, raw)
                except Exception:
                    logger.exception("Failed upserting comment %s", raw.get("id"))

async def _refresh_interest_stories(SessionLocal, search_client: HNSearchClient, interest_repo: InterestRepository, story_repo: StoryRepository):
    # ensure interests seeded
    with get_session(SessionLocal) as session:
        for group in INTEREST_GROUPS:
            for item in group["items"]:
                interest_repo.upsert_interest(session, group["group"], item["name"], item["keywords"])
        interests = interest_repo.list_interests(session)

    for interest in interests:
        # query by keywords (space-separated)
        keywords = interest.keywords or []
        if not keywords:
            continue
        query = " ".join(keywords[:5])
        try:
            hits = await search_client.search(query, settings.INTEREST_BACKLOG_LIMIT)
        except Exception:
            logger.exception("Interest search failed: %s", interest.name)
            continue

        keep_ids: list[int] = []
        with get_session(SessionLocal) as session:
            for h in hits:
                try:
                    hn_id = int(h.get("objectID"))
                except Exception:
                    continue
                title = h.get("title")
                url = h.get("url")
                points = h.get("points")
                time_val = h.get("created_at_i")

                # upsert minimal story
                raw_payload = {"id": hn_id, "title": title, "url": url, "score": points, "time": time_val}
                from app.services.sources.hackernews.fetcher import StoryData

                sd = StoryData(
                    hn_id=hn_id,
                    title=title,
                    url=url,
                    score=points,
                    time=time_val,
                    descendants=None,
                    raw_payload=raw_payload,
                )
                story_repo.upsert(session, sd)

                interest_repo.upsert_interest_story(session, interest.id, hn_id, points, time_val)
                keep_ids.append(hn_id)

            # prune to top N by rank
            rows = interest_repo.list_interest_stories(session, interest.id)
            ranked = sorted(rows, key=lambda r: _rank_interest(r.points, r.time, r.read_count), reverse=True)
            top_ids = [r.story_hn_id for r in ranked[: settings.INTEREST_STORY_LIMIT]]
            if top_ids:
                interest_repo.delete_interest_story_not_in(session, interest.id, top_ids)

async def _process_saved_thread_queue(SessionLocal, redis_cache: RedisCache, story_repo: StoryRepository, comment_repo: CommentRepository, fetcher: HNFetcher, client: AsyncHNClient):
    provider = get_ai_provider()
    model_version = settings.SUMMARIZATION_MODEL_VERSION
    model_name = settings.OPENAI_MODEL if settings.AI_PROVIDER == "openai" else "mock"
    repo = SavedThreadRepository()
    comment_summary_repo = CommentSummaryRepository()
    comment_summary_cache = CommentSummaryCache(redis_cache, comment_summary_repo)

    for _ in range(settings.SAVED_THREAD_QUEUE_MAX_PER_TICK):
        job = await dequeue_saved_thread(redis_cache)
        if not job:
            break

        user_id = job.get("user_id")
        story_hn_id = job.get("story_hn_id")
        comment_hn_ids = job.get("comment_hn_ids") or []
        if user_id is None or story_hn_id is None:
            continue

        with get_session(SessionLocal) as session:
            story = story_repo.get_by_hn_id(session, int(story_hn_id))
            if story is None:
                try:
                    sd = await fetcher.fetch_and_normalize(int(story_hn_id))
                    story, _c, _u = story_repo.upsert(session, sd)
                except Exception:
                    logger.exception("Failed fetching story %s", story_hn_id)
                    continue

            thread = repo.create_thread(session, int(user_id), story.hn_id, story.title, url=story.url)

            # Story summary
            story_payload = story.raw_payload or {"id": story.hn_id, "title": story.title}
            story_summary = await provider.summarize_story(story_payload)
            repo.add_item(
                session,
                thread.id,
                "story",
                story.hn_id,
                story.title,
                story_summary.dict(),
                model_name,
                model_version,
            )

            # Comment summaries
            for cid in comment_hn_ids:
                comment = session.query(Comment).filter_by(comment_hn_id=int(cid)).one_or_none()
                if comment is None:
                    try:
                        raw = await client.fetch_item(int(cid))
                        if raw and isinstance(raw, dict) and raw.get("type") == "comment" and not raw.get("dead") and not raw.get("deleted"):
                            comment, _c, _u = comment_repo.upsert(session, story.hn_id, raw)
                        else:
                            continue
                    except Exception:
                        logger.exception("Failed fetching comment %s", cid)
                        continue
                existing = comment_summary_repo.fetch_latest(session, comment.comment_hn_id, model_version)
                if existing is None:
                    comment_payload = comment.raw_payload or {"id": comment.comment_hn_id, "text": comment.text}
                    comment_summary = await provider.summarize_story(comment_payload)
                    existing, _c, _u = comment_summary_repo.upsert(session, comment.comment_hn_id, comment_summary, model_version, model_name)
                    await comment_summary_cache.set(
                        comment.comment_hn_id,
                        model_version,
                        {
                            "tldr": existing.tldr,
                            "key_points": existing.key_points,
                            "consensus": existing.consensus,
                            "model_version": existing.model_version,
                            "model_name": existing.model_name,
                            "created_at": existing.created_at.isoformat() if existing.created_at else None,
                            "updated_at": existing.updated_at.isoformat() if existing.updated_at else None,
                        },
                    )
                comment_summary = existing
                repo.add_item(
                    session,
                    thread.id,
                    "comment",
                    comment.comment_hn_id,
                    comment.text,
                    {
                        "tldr": comment_summary.tldr,
                        "key_points": comment_summary.key_points,
                        "consensus": comment_summary.consensus,
                    },
                    model_name,
                    model_version,
                )

async def _run_loop(SessionLocal, redis_cache: RedisCache):
    client = AsyncHNClient(base_url=str(settings.HN_API_URL))
    await client.init()
    fetcher = HNFetcher(client)
    story_repo = StoryRepository()
    top_story_repo = TopStoryRepository()
    feed_cache = FeedCache(redis_cache, top_story_repo)
    comment_repo = CommentRepository()
    interest_repo = InterestRepository()
    search_client = HNSearchClient()
    last_interest_refresh = -settings.INTEREST_REFRESH_SECONDS
    last_top_refresh = -settings.TOP_STORIES_REFRESH_SECONDS
    last_cleanup = 0.0

    interval = 1.0  # Check signals every 1s

    logger.info("Worker entering reactive signal loop")

    try:
        while True:
            try:
                # --- 1. Top Stories (The Daily Newspaper) ---
                # Check if it has been 24 hours
                now_ts = asyncio.get_event_loop().time()
                if now_ts - last_top_refresh >= settings.TOP_STORIES_REFRESH_SECONDS:
                    logger.info("Fetching Daily Edition (Top Stories)")
                    await run_fetch_once(
                        SessionLocal,
                        fetcher,
                        story_repo,
                        feed_cache,
                        limit=settings.TOP_STORIES_LIMIT,
                        top_story_repo=top_story_repo,
                    )
                    last_top_refresh = now_ts

                # --- 2. Interest Signaling (Pressure Hook) ---
                # Listen for pressure signals from API
                interest_id = await redis_cache.get_next_interest_signal(timeout=1)
                if interest_id:
                    logger.info("Pressure signal received for interest_id=%d", interest_id)
                    from app.db.models.interest import Interest
                    with get_session(SessionLocal) as session:
                        interest = session.query(Interest).filter_by(id=interest_id).one_or_none()
                        if interest:
                            # Use watermark for efficient fetch
                            watermark = await redis_cache.get_interest_watermark(interest_id)
                            keywords = " ".join((interest.keywords or [])[:5])
                            hits = await search_client.search(keywords, settings.INTEREST_BACKLOG_LIMIT, min_timestamp=watermark)
                            
                            max_ts = watermark
                            for h in hits:
                                try:
                                    hn_id = int(h.get("objectID"))
                                    ts = h.get("created_at_i") or 0
                                    max_ts = max(max_ts, ts)
                                    
                                    # Upsert story
                                    raw = {"id": hn_id, "title": h.get("title"), "url": h.get("url"), "score": h.get("points"), "time": ts}
                                    from app.services.sources.hackernews.fetcher import StoryData
                                    sd = StoryData(hn_id=hn_id, title=h.get("title"), url=h.get("url"), score=h.get("points"), time=ts, raw_payload=raw)
                                    story_repo.upsert(session, sd)
                                    interest_repo.upsert_interest_story(session, interest.id, hn_id, h.get("points"), ts)
                                except Exception:
                                    continue
                            
                            # Rotate shelf to keep it at 50
                            interest_repo.rotate_shelf(session, interest.id, max_size=settings.INTEREST_STORY_LIMIT)
                            # Update watermark
                            await redis_cache.set_interest_watermark(interest_id, max_ts)

                # --- 3. Comment Signaling (Predictive Discussion) ---
                # --- 3. Comment Signaling (Predictive Discussion) ---
                story_hn_id = await redis_cache.get_next_comment_signal(timeout=1)
                if story_hn_id:
                    logger.info("Comment signal received for story_hn_id=%d", story_hn_id)
                    with get_session(SessionLocal) as session:
                        story = story_repo.get_by_hn_id(session, story_hn_id)
                        if story and story.raw_payload:
                            kids = story.raw_payload.get("kids") or []
                            if kids:
                                # Fetch deep discussion (BFS)
                                # Limit total comments to prevent explosion (e.g. 50-100)
                                total_limit = settings.COMMENTS_FETCH_LIMIT * 5
                                
                                # BFS state
                                queue = list(kids)
                                seen = set(kids)
                                fetched_count = 0
                                
                                logger.info("Starting recursive fetch for story %d (limit=%d)", story_hn_id, total_limit)
                                
                                while queue and fetched_count < total_limit:
                                    # Batch fetch for concurrency
                                    batch_size = 10
                                    batch = queue[:batch_size]
                                    queue = queue[batch_size:]
                                    
                                    coros = [client.fetch_item(k) for k in batch]
                                    try:
                                        results = await asyncio.gather(*coros, return_exceptions=True)
                                        
                                        for res in results:
                                            if isinstance(res, Exception):
                                                continue
                                            
                                            raw = res
                                            if not isinstance(raw, dict):
                                                continue
                                                
                                            # Validate item type
                                            if raw.get("type") != "comment" or raw.get("dead") or raw.get("deleted"):
                                                continue
                                                
                                            # Upsert
                                            comment_repo.upsert(session, story_hn_id, raw)
                                            fetched_count += 1
                                            
                                            # Enqueue kids
                                            item_kids = raw.get("kids")
                                            if item_kids and isinstance(item_kids, list):
                                                for k in item_kids:
                                                    if k not in seen:
                                                        seen.add(k)
                                                        queue.append(k)
                                                        
                                    except Exception:
                                        logger.exception("Batch fetch failed for story %d", story_hn_id)
                                        
                                logger.info("Recursive fetch complete. Fetched %d comments for story %d", fetched_count, story_hn_id)

                # --- 4. Background Tasks ---
                await _process_summary_queue(SessionLocal, redis_cache, story_repo)
                await _process_saved_thread_queue(SessionLocal, redis_cache, story_repo, comment_repo, fetcher, client)

                if now_ts - last_cleanup >= settings.CLEANUP_INTERVAL_SECONDS:
                    await _cleanup_stories(SessionLocal)
                    last_cleanup = now_ts
                    
                # Pause briefly to prevent CPU spinning if no signals
                if interest_id is None:
                    await asyncio.sleep(interval)
            except Exception:
                logger.exception("Error in fetch cycle")
                await asyncio.sleep(5)
    finally:
        await client.close()
        await search_client.close()


def _run_worker_blocking():
    engine = get_engine(settings.DATABASE_URL)
    SessionLocal = init_sessionmaker(engine)

    redis_cache = RedisCache(url=settings.REDIS_URL)

    loop = asyncio.get_event_loop()

    # handle startup
    async def _startup():
        await redis_cache.init()

    async def _shutdown():
        await redis_cache.close()

    loop.run_until_complete(_startup())

    # run the repeating task
    main_task = loop.create_task(_run_loop(SessionLocal, redis_cache))

    # install signal handlers for graceful shutdown
    stop_signals = (signal.SIGINT, signal.SIGTERM)

    if sys.platform != "win32":
        for s in (signal.SIGINT, signal.SIGTERM):
            loop.add_signal_handler(s, main_task.cancel)


    try:
        loop.run_until_complete(main_task)
    except asyncio.CancelledError:
        logger.info("Worker main task cancelled, shutting down")
    finally:
        loop.run_until_complete(_shutdown())


if __name__ == "__main__":
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler("worker.log"),
            logging.StreamHandler()
        ]
    )
    logger.info("Worker starting up...")
    _run_worker_blocking()
