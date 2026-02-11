from typing import List
from fastapi import APIRouter, Depends, Query, HTTPException
from app.config import settings
from app.schemas.story import StoryOut
from app.schemas.comment import CommentOut
from app.repositories.comment_repo import CommentRepository
from app.repositories.story_repo import StoryRepository
from app.services.sources.hackernews.client import AsyncHNClient
from app.services.sources.hackernews.fetcher import HNFetcher
from app.services.cache.feed_cache import FeedCache
from app.db.session import get_session

from fastapi import Request

router = APIRouter()


async def _get_feed_cache(request: Request) -> FeedCache:
    # `app.state` must have `redis_cache` and `SessionLocal` set by create_app
    redis_cache = request.app.state.redis_cache
    repo = request.app.state.top_story_repo
    return FeedCache(redis_cache, repo)


async def _get_session(request: Request):
    SessionLocal = request.app.state.SessionLocal
    with get_session(SessionLocal) as session:
        yield session


@router.get("/", response_model=List[StoryOut])
async def get_stories(
    limit: int = Query(default=None, ge=1),
    feed_cache: FeedCache = Depends(_get_feed_cache),
    session=Depends(_get_session),
):
    # enforce sensible default and max
    max_limit = settings.TOP_STORIES_LIMIT
    limit = limit or max_limit
    if limit > max_limit:
        limit = max_limit

    # Try cache first
    cached = await feed_cache.read_feed()
    if cached:
        return cached[:limit]

    # fallback to DB serialization
    result = await feed_cache.read_or_fallback(session)
    return result[:limit]


@router.get("/{hn_id}")
async def get_story_detail(
    hn_id: int,
    request: Request,
    session=Depends(_get_session),
):
    story_repo = StoryRepository()
    story = story_repo.get_by_hn_id(session, hn_id)
    if story is None:
        raise HTTPException(status_code=404, detail="story not found")

    redis_cache = request.app.state.redis_cache

    # If story has kids, signal worker to fetch the full thread in background
    if story.raw_payload and story.raw_payload.get("kids"):
        await redis_cache.signal_comment_fetch(hn_id)

    comment_repo = CommentRepository()
    comments = comment_repo.fetch_for_story(session, hn_id, limit=settings.COMMENTS_PREVIEW_LIMIT)

    # Optimization: If DB is empty, fetch just 3 comments synchronously for instant feedback
    if not comments and story.raw_payload and story.raw_payload.get("kids"):
        kids = story.raw_payload.get("kids")[: settings.COMMENTS_PREVIEW_LIMIT]
        client = AsyncHNClient(base_url=str(settings.HN_API_URL))
        await client.init()
        try:
            for kid in kids:
                try:
                    raw = await client.fetch_item(int(kid))
                    if raw and isinstance(raw, dict) and raw.get("type") == "comment" and not raw.get("dead") and not raw.get("deleted"):
                        comment_repo.upsert(session, hn_id, raw)
                except Exception:
                    continue
        finally:
            await client.close()
        comments = comment_repo.fetch_for_story(session, hn_id, limit=settings.COMMENTS_PREVIEW_LIMIT)

    return {
        "hn_id": story.hn_id,
        "title": story.title,
        "url": story.url,
        "score": story.raw_payload.get("score") if story.raw_payload else None,
        "time": story.raw_payload.get("time") if story.raw_payload else None,
        "text": story.raw_payload.get("text") if story.raw_payload else None,
        "comment_preview": [CommentOut.from_orm(c).dict() for c in comments],
    }


@router.get("/{hn_id}/comments", response_model=List[CommentOut])
async def get_story_comments(
    hn_id: int,
    request: Request,
    limit: int = Query(default=None, ge=1),
    session=Depends(_get_session),
):
    max_limit = settings.COMMENTS_FETCH_LIMIT
    limit = limit or max_limit
    if limit > max_limit:
        limit = max_limit

    redis_cache = request.app.state.redis_cache
    comment_repo = CommentRepository()
    
    # Check what we have
    comments = comment_repo.fetch_for_story(session, hn_id, limit=limit)
    
    # Trigger (or re-trigger) background fetch if we are below requested limit
    if len(comments) < limit:
        await redis_cache.signal_comment_fetch(hn_id)

    # If totally empty, do a small synchronous fetch like in detail view
    if not comments:
        story_repo = StoryRepository()
        story = story_repo.get_by_hn_id(session, hn_id)
        if story and story.raw_payload and story.raw_payload.get("kids"):
            kids = story.raw_payload.get("kids")[: settings.COMMENTS_PREVIEW_LIMIT]
            client = AsyncHNClient(base_url=str(settings.HN_API_URL))
            await client.init()
            try:
                for kid in kids:
                    try:
                        raw = await client.fetch_item(int(kid))
                        if raw and isinstance(raw, dict) and raw.get("type") == "comment" and not raw.get("dead") and not raw.get("deleted"):
                            comment_repo.upsert(session, hn_id, raw)
                    except Exception:
                        continue
            finally:
                await client.close()
            comments = comment_repo.fetch_for_story(session, hn_id, limit=limit)

    return comments
