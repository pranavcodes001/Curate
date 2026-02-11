from fastapi import APIRouter, Depends, HTTPException, Request

from app.config import settings
from app.db.session import get_session
from app.services.auth.deps import require_user
from app.repositories.story_repo import StoryRepository
from app.repositories.saved_thread_repo import SavedThreadRepository
from app.schemas.saved_thread import SavedThreadCreate, SavedThreadOut, SavedThreadItemOut, SavedThreadQueueOut
from app.services.cache.redis import RedisCache
from app.services.queue.saved_thread_queue import enqueue_saved_thread

router = APIRouter()


async def _get_session(request: Request):
    SessionLocal = request.app.state.SessionLocal
    with get_session(SessionLocal) as session:
        yield session


async def _get_redis(request: Request) -> RedisCache:
    return request.app.state.redis_cache


@router.post("/saved_threads", response_model=SavedThreadQueueOut, status_code=202)
async def create_saved_thread(
    payload: SavedThreadCreate,
    session=Depends(_get_session),
    redis_cache: RedisCache = Depends(_get_redis),
    user=Depends(require_user),
):
    if not redis_cache.enabled():
        raise HTTPException(status_code=503, detail="redis required for queued saved threads")

    await enqueue_saved_thread(redis_cache, user.id, payload.story_hn_id, payload.comment_hn_ids)
    return SavedThreadQueueOut(status="queued", story_hn_id=payload.story_hn_id, comment_count=len(payload.comment_hn_ids))


@router.get("/saved_threads", response_model=list[SavedThreadOut])
async def list_saved_threads(
    session=Depends(_get_session),
    user=Depends(require_user),
):
    repo = SavedThreadRepository()
    threads = repo.list_threads(session, user.id)
    results = []
    for t in threads:
        items = repo.list_items(session, t.id)
        results.append(
            SavedThreadOut(
                id=t.id,
                story_hn_id=t.story_hn_id,
                title=t.title,
                url=t.url,
                created_at=t.created_at,
                items=[SavedThreadItemOut.from_orm(i) for i in items],
            )
        )
    return results


@router.get("/saved_threads/{thread_id}", response_model=SavedThreadOut)
async def get_saved_thread(
    thread_id: int,
    session=Depends(_get_session),
    user=Depends(require_user),
):
    repo = SavedThreadRepository()
    t = repo.get_thread(session, user.id, thread_id)
    if t is None:
        raise HTTPException(status_code=404, detail="thread not found")
    items = repo.list_items(session, t.id)
    return SavedThreadOut(
        id=t.id,
        story_hn_id=t.story_hn_id,
        title=t.title,
        url=t.url,
        created_at=t.created_at,
        items=[SavedThreadItemOut.from_orm(i) for i in items],
    )
