"""Caching helpers for AI summaries keyed by story and model version."""
from typing import Optional

from app.services.cache.redis import RedisCache
from app.config import settings
from app.repositories.summary_repo import SummaryRepository


def _summary_key(hn_id: int, model_version: str) -> str:
    return f"summary:story:{hn_id}:model:{model_version}"


class SummaryCache:
    def __init__(self, redis_cache: RedisCache, repo: SummaryRepository):
        self.redis = redis_cache
        self.repo = repo

    async def get(self, hn_id: int, model_version: str) -> Optional[dict]:
        key = _summary_key(hn_id, model_version)
        data = await self.redis.get_json(key)
        if data is not None:
            return data
        return None

    async def set(self, hn_id: int, model_version: str, payload: dict) -> None:
        key = _summary_key(hn_id, model_version)
        await self.redis.set_json(key, payload, ex=settings.SUMMARY_TTL_SECONDS)

    async def delete(self, hn_id: int, model_version: str) -> None:
        key = _summary_key(hn_id, model_version)
        await self.redis.delete(key)

    async def get_or_db(self, session, hn_id: int, model_version: str) -> Optional[dict]:
        # Try cache
        cached = await self.get(hn_id, model_version)
        if cached is not None:
            return cached

        # Fallback to DB
        row = self.repo.fetch_latest(session, hn_id, model_version)
        if row is None:
            return None

        payload = {
            "tldr": row.tldr,
            "key_points": row.key_points,
            "consensus": row.consensus,
            "model_version": row.model_version,
            "model_name": row.model_name,
            "created_at": row.created_at.isoformat() if row.created_at else None,
            "updated_at": row.updated_at.isoformat() if row.updated_at else None,
        }
        # Populate cache for quicker reads
        await self.set(hn_id, model_version, payload)
        return payload
