from __future__ import annotations
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from app.db.session import get_session
from app.repositories.search_query_repo import SearchQueryRepository
from app.repositories.story_repo import StoryRepository
from app.services.sources.hackernews.fetcher import StoryData

from app.config import settings
from app.schemas.story import StoryOut
from app.services.cache.search_cache import SearchCache
from app.services.cache.redis import RedisCache
from app.services.sources.hackernews.search_client import HNSearchClient

router = APIRouter()


async def _get_cache(request: Request) -> SearchCache:
    redis_cache: RedisCache = request.app.state.redis_cache
    return SearchCache(redis_cache)

async def _get_session(request: Request):
    SessionLocal = request.app.state.SessionLocal
    with get_session(SessionLocal) as session:
        yield session

def _normalize_query(q: str) -> str:
    return " ".join([t for t in q.strip().split() if t])


@router.get("/search", response_model=List[StoryOut])
async def search_stories(
    q: str = Query(..., min_length=1),
    limit: int = Query(default=None, ge=1),
    cache: SearchCache = Depends(_get_cache),
    session=Depends(_get_session),
):
    # enforce limit
    max_limit = settings.SEARCH_LIMIT
    limit = limit or max_limit
    if limit > max_limit:
        limit = max_limit

    # enforce keywords up to 5
    normalized = _normalize_query(q)
    keywords = normalized.split()
    if len(keywords) > settings.SEARCH_MAX_KEYWORDS:
        raise HTTPException(status_code=400, detail=f"max {settings.SEARCH_MAX_KEYWORDS} keywords allowed")

    # cache (db)
    search_repo = SearchQueryRepository()
    row = search_repo.get(session, normalized, limit)
    if row is not None and search_repo.is_fresh(row, settings.SEARCH_DB_TTL_DAYS):
        return row.results

    # cache (redis)
    cached = await cache.get(normalized, limit)
    if cached is not None:
        return cached

    client = HNSearchClient()
    hits = await client.search(normalized, limit)
    results: List[StoryOut] = []
    story_repo = StoryRepository()
    for h in hits:
        try:
            hn_id = int(h.get("objectID")) if h.get("objectID") else None
        except Exception:
            hn_id = None
        if hn_id is None:
            continue
        title = h.get("title")
        url = h.get("url")
        score = h.get("points")
        time_val = h.get("created_at_i")

        results.append(StoryOut(hn_id=hn_id, title=title, url=url, score=score, time=time_val))

        # upsert minimal story row for detail views
        raw_payload = {"id": hn_id, "title": title, "url": url, "score": score, "time": time_val}
        sd = StoryData(
            hn_id=hn_id,
            title=title,
            url=url,
            score=score,
            time=time_val,
            descendants=None,
            raw_payload=raw_payload,
        )
        try:
            story_repo.upsert(session, sd)
        except Exception:
            # best-effort upsert
            pass

    payload = [r.dict() for r in results]
    await cache.set(normalized, limit, payload)
    search_repo.upsert(session, normalized, limit, payload)
    return results
