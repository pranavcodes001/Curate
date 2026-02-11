from fastapi import APIRouter, Depends, HTTPException, Request
from app.config import settings
from app.services.cache.summary_cache import SummaryCache
from app.schemas.summary import SummaryOut
from app.repositories.summary_repo import SummaryRepository
from datetime import datetime, timezone
from app.repositories.story_repo import StoryRepository
from app.services.sources.hackernews.client import AsyncHNClient
from app.services.sources.hackernews.fetcher import HNFetcher
from app.db.session import get_session
from app.services.cache.redis import RedisCache
from app.services.auth.deps import require_user
from app.services.ai.factory import get_ai_provider
from app.repositories.comment_summary_repo import CommentSummaryRepository
from app.services.cache.comment_summary_cache import CommentSummaryCache
from app.repositories.comment_repo import CommentRepository


router = APIRouter()


async def _get_summary_cache(request: Request) -> SummaryCache:
    redis_cache: RedisCache = request.app.state.redis_cache
    repo = SummaryRepository()
    return SummaryCache(redis_cache, repo)


async def _get_session(request: Request):
    SessionLocal = request.app.state.SessionLocal
    with get_session(SessionLocal) as session:
        yield session


@router.get("/stories/{hn_id}/summary", response_model=SummaryOut)
async def get_summary(hn_id: int, session=Depends(_get_session), summary_cache: SummaryCache = Depends(_get_summary_cache)):
    model_version = settings.SUMMARIZATION_MODEL_VERSION
    payload = await summary_cache.get_or_db(session, hn_id, model_version)
    if payload is None:
        # 404 chosen because the resource (summary) does not exist yet; client can distinguish between missing and available
        raise HTTPException(status_code=404, detail="summary not available")

    # Return a compact summary object
    return SummaryOut(
        hn_id=hn_id,
        model_version=model_version,
        tldr=payload.get("tldr"),
        key_points=payload.get("key_points"),
        consensus=payload.get("consensus"),
        model_name=payload.get("model_name"),
        created_at=payload.get("created_at"),
        updated_at=payload.get("updated_at"),
    )


@router.post("/stories/{hn_id}/summary/generate", response_model=SummaryOut, status_code=200)
async def generate_summary(
    hn_id: int,
    session=Depends(_get_session),
    summary_cache: SummaryCache = Depends(_get_summary_cache),
    _user=Depends(require_user),
):
    model_version = settings.SUMMARIZATION_MODEL_VERSION
    summary_repo = SummaryRepository()

    existing = summary_repo.fetch_latest(session, hn_id, model_version)
    if existing is not None:
        payload = {
            "tldr": existing.tldr,
            "key_points": existing.key_points,
            "consensus": existing.consensus,
            "model_version": existing.model_version,
            "model_name": existing.model_name,
            "created_at": existing.created_at.isoformat() if existing.created_at else None,
            "updated_at": existing.updated_at.isoformat() if existing.updated_at else None,
        }
        await summary_cache.set(hn_id, model_version, payload)
        return SummaryOut(
            hn_id=hn_id,
            model_version=model_version,
            tldr=existing.tldr,
            key_points=existing.key_points,
            consensus=existing.consensus,
            model_name=existing.model_name,
            created_at=existing.created_at,
            updated_at=existing.updated_at,
        )

    # Rate limit per user per hour
    redis_cache: RedisCache = summary_cache.redis
    if redis_cache and redis_cache.enabled():
        hour_key = datetime.now(timezone.utc).strftime("%Y%m%d%H")
        rate_key = f"rate:summary:{_user.id}:{hour_key}"
        count = await redis_cache.incr(rate_key, ex=3600)
        if count and count > settings.SUMMARY_RATE_LIMIT_PER_HOUR:
            raise HTTPException(status_code=429, detail="summary generation rate limit exceeded")

    # Fetch story
    story_repo = StoryRepository()
    story = story_repo.get_by_hn_id(session, hn_id)
    if story is None:
        # Fetch from HN API on-demand (for search results not in DB)
        client = AsyncHNClient(base_url=str(settings.HN_API_URL))
        await client.init()
        try:
            fetcher = HNFetcher(client)
            sd = await fetcher.fetch_and_normalize(hn_id)
        except Exception:
            sd = None
        finally:
            await client.close()
        if sd is None:
            raise HTTPException(status_code=404, detail="story not found")
        story, _created, _updated = story_repo.upsert(session, sd)

    provider = get_ai_provider()
    summary = await provider.summarize_story(story.raw_payload or {"id": story.hn_id, "title": story.title})
    model_name = settings.OPENAI_MODEL if settings.AI_PROVIDER == "openai" else "mock"
    saved, _created, _updated = summary_repo.upsert_summary(session, story.hn_id, summary, model_version, model_name)

    payload = {
        "tldr": saved.tldr,
        "key_points": saved.key_points,
        "consensus": saved.consensus,
        "model_version": saved.model_version,
        "model_name": saved.model_name,
        "created_at": saved.created_at.isoformat() if saved.created_at else None,
        "updated_at": saved.updated_at.isoformat() if saved.updated_at else None,
    }
    await summary_cache.set(story.hn_id, model_version, payload)

    return SummaryOut(
        hn_id=story.hn_id,
        model_version=saved.model_version,
        tldr=saved.tldr,
        key_points=saved.key_points,
        consensus=saved.consensus,
        model_name=saved.model_name,
        created_at=saved.created_at,
        updated_at=saved.updated_at,
    )


@router.get("/comments/{hn_id}/summary", response_model=SummaryOut)
async def get_comment_summary(
    hn_id: int,
    session=Depends(_get_session),
    request: Request = None,
):
    redis_cache: RedisCache = request.app.state.redis_cache
    repo = CommentSummaryRepository()
    cache = CommentSummaryCache(redis_cache, repo)
    model_version = settings.SUMMARIZATION_MODEL_VERSION
    payload = await cache.get_or_db(session, hn_id, model_version)
    if payload is None:
        raise HTTPException(status_code=404, detail="summary not available")

    return SummaryOut(
        hn_id=hn_id,
        model_version=model_version,
        tldr=payload.get("tldr"),
        key_points=payload.get("key_points"),
        consensus=payload.get("consensus"),
        model_name=payload.get("model_name"),
        created_at=payload.get("created_at"),
        updated_at=payload.get("updated_at"),
    )


@router.post("/comments/{hn_id}/summary/generate", response_model=SummaryOut, status_code=200)
async def generate_comment_summary(
    hn_id: int,
    session=Depends(_get_session),
    request: Request = None,
    _user=Depends(require_user),
):
    model_version = settings.SUMMARIZATION_MODEL_VERSION
    redis_cache: RedisCache = request.app.state.redis_cache
    repo = CommentSummaryRepository()
    cache = CommentSummaryCache(redis_cache, repo)

    existing = repo.fetch_latest(session, hn_id, model_version)
    if existing is not None:
        return SummaryOut(
            hn_id=hn_id,
            model_version=model_version,
            tldr=existing.tldr,
            key_points=existing.key_points,
            consensus=existing.consensus,
            model_name=existing.model_name,
            created_at=existing.created_at,
            updated_at=existing.updated_at,
        )

    # Rate limit
    if redis_cache and redis_cache.enabled():
        hour_key = datetime.now(timezone.utc).strftime("%Y%m%d%H")
        rate_key = f"rate:summary:{_user.id}:{hour_key}"
        count = await redis_cache.incr(rate_key, ex=3600)
        if count and count > settings.SUMMARY_RATE_LIMIT_PER_HOUR:
            raise HTTPException(status_code=429, detail="rate limit exceeded")

    comment_repo = CommentRepository()
    comment = comment_repo.get_by_hn_id(session, hn_id)
    if comment is None:
        # fetch from HN
        client = AsyncHNClient(base_url=str(settings.HN_API_URL))
        await client.init()
        try:
            raw = await client.fetch_item(hn_id)
            if not raw or raw.get("type") != "comment":
                raise HTTPException(status_code=404, detail="comment not found")
            # We need a story_id to upsert a comment. For now, we can try to find it or just mock it.
            # But the UI usually handles this for comments already in DB.
            raise HTTPException(status_code=404, detail="comment must be in DB for summarization")
        finally:
            await client.close()

    provider = get_ai_provider()
    summary = await provider.summarize_story(comment.raw_payload or {"id": comment.comment_hn_id, "text": comment.text})
    model_name = settings.OPENAI_MODEL if settings.AI_PROVIDER == "openai" else "mock"
    saved, _, _ = repo.upsert(session, hn_id, summary, model_version, model_name)

    payload = {
        "tldr": saved.tldr,
        "key_points": saved.key_points,
        "consensus": saved.consensus,
        "model_version": saved.model_version,
        "model_name": saved.model_name,
        "created_at": saved.created_at.isoformat() if saved.created_at else None,
        "updated_at": saved.updated_at.isoformat() if saved.updated_at else None,
    }
    await cache.set(hn_id, model_version, payload)

    return SummaryOut(
        hn_id=hn_id,
        model_version=model_version,
        tldr=saved.tldr,
        key_points=saved.key_points,
        consensus=saved.consensus,
        model_name=saved.model_name,
        created_at=saved.created_at,
        updated_at=saved.updated_at,
    )
