from fastapi import APIRouter, Depends, HTTPException

from app.config import settings
from app.db.session import get_session
from app.services.auth.deps import require_user
from app.services.ai.factory import get_ai_provider
from app.db.models.comment import Comment
from app.repositories.comment_repo import CommentRepository
from app.services.sources.hackernews.client import AsyncHNClient
from app.repositories.comment_summary_repo import CommentSummaryRepository
from app.services.cache.comment_summary_cache import CommentSummaryCache
from app.services.cache.redis import RedisCache
from app.schemas.summary import SummaryOut

router = APIRouter()


async def _get_session(request):
    SessionLocal = request.app.state.SessionLocal
    with get_session(SessionLocal) as session:
        yield session


async def _get_cache(request) -> CommentSummaryCache:
    redis_cache: RedisCache = request.app.state.redis_cache
    repo = CommentSummaryRepository()
    return CommentSummaryCache(redis_cache, repo)


@router.get("/comments/{comment_hn_id}/summary", response_model=SummaryOut)
async def get_comment_summary(
    comment_hn_id: int,
    session=Depends(_get_session),
    cache: CommentSummaryCache = Depends(_get_cache),
):
    payload = await cache.get_or_db(session, comment_hn_id, settings.SUMMARIZATION_MODEL_VERSION)
    if payload is None:
        raise HTTPException(status_code=404, detail="summary not available")
    return SummaryOut(
        hn_id=comment_hn_id,
        model_version=settings.SUMMARIZATION_MODEL_VERSION,
        tldr=payload.get("tldr"),
        key_points=payload.get("key_points"),
        consensus=payload.get("consensus"),
        model_name=payload.get("model_name"),
        created_at=payload.get("created_at"),
        updated_at=payload.get("updated_at"),
    )


@router.post("/comments/{comment_hn_id}/summary/generate", response_model=SummaryOut, status_code=200)
async def generate_comment_summary(
    comment_hn_id: int,
    session=Depends(_get_session),
    cache: CommentSummaryCache = Depends(_get_cache),
    _user=Depends(require_user),
):
    existing_repo = CommentSummaryRepository()
    existing = existing_repo.fetch_latest(session, comment_hn_id, settings.SUMMARIZATION_MODEL_VERSION)
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
        await cache.set(comment_hn_id, existing.model_version, payload)
        return SummaryOut(
            hn_id=comment_hn_id,
            model_version=existing.model_version,
            tldr=existing.tldr,
            key_points=existing.key_points,
            consensus=existing.consensus,
            model_name=existing.model_name,
            created_at=existing.created_at,
            updated_at=existing.updated_at,
        )

    row = session.query(Comment).filter_by(comment_hn_id=comment_hn_id).one_or_none()
    if row is None:
        client = AsyncHNClient(base_url=str(settings.HN_API_URL))
        await client.init()
        try:
            raw = await client.fetch_item(comment_hn_id)
            if not raw or raw.get("type") != "comment":
                raise HTTPException(status_code=404, detail="comment not found")

            # Resolve story id by walking parents until we hit a story.
            story_hn_id = None
            parent_id = raw.get("parent")
            for _ in range(10):
                if parent_id is None:
                    break
                parent_raw = await client.fetch_item(int(parent_id))
                if not parent_raw:
                    break
                if parent_raw.get("type") == "story":
                    story_hn_id = int(parent_raw.get("id"))
                    break
                parent_id = parent_raw.get("parent")

            if story_hn_id is None:
                raise HTTPException(status_code=404, detail="comment must be in DB for summarization")

            comment_repo = CommentRepository()
            row, _c, _u = comment_repo.upsert(session, story_hn_id, raw)
        finally:
            await client.close()

    provider = get_ai_provider()
    payload = row.raw_payload or {"id": row.comment_hn_id, "text": row.text}
    summary = await provider.summarize_story(payload)

    summary_repo = CommentSummaryRepository()
    model_version = settings.SUMMARIZATION_MODEL_VERSION
    model_name = settings.OPENAI_MODEL if settings.AI_PROVIDER == "openai" else "mock"
    saved, _created, _updated = summary_repo.upsert(session, comment_hn_id, summary, model_version, model_name)

    payload = {
        "tldr": saved.tldr,
        "key_points": saved.key_points,
        "consensus": saved.consensus,
        "model_version": saved.model_version,
        "model_name": saved.model_name,
        "created_at": saved.created_at.isoformat() if saved.created_at else None,
        "updated_at": saved.updated_at.isoformat() if saved.updated_at else None,
    }
    await cache.set(comment_hn_id, model_version, payload)

    return SummaryOut(
        hn_id=comment_hn_id,
        model_version=saved.model_version,
        tldr=saved.tldr,
        key_points=saved.key_points,
        consensus=saved.consensus,
        model_name=saved.model_name,
        created_at=saved.created_at,
        updated_at=saved.updated_at,
    )
