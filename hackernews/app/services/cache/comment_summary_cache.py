"""Caching helpers for AI comment summaries keyed by comment and model version."""
from typing import Optional

from app.services.cache.redis import RedisCache
from app.config import settings
from app.repositories.comment_summary_repo import CommentSummaryRepository


def _comment_summary_key(comment_hn_id: int, model_version: str) -> str:
    return f"summary:comment:{comment_hn_id}:model:{model_version}"


class CommentSummaryCache:
    def __init__(self, redis_cache: RedisCache, repo: CommentSummaryRepository):
        self.redis = redis_cache
        self.repo = repo

    async def get(self, comment_hn_id: int, model_version: str) -> Optional[dict]:
        key = _comment_summary_key(comment_hn_id, model_version)
        data = await self.redis.get_json(key)
        if data is not None:
            return data
        return None

    async def set(self, comment_hn_id: int, model_version: str, payload: dict) -> None:
        key = _comment_summary_key(comment_hn_id, model_version)
        await self.redis.set_json(key, payload, ex=settings.SUMMARY_TTL_SECONDS)

    async def get_or_db(self, session, comment_hn_id: int, model_version: str) -> Optional[dict]:
        cached = await self.get(comment_hn_id, model_version)
        if cached is not None:
            return cached

        row = self.repo.fetch_latest(session, comment_hn_id, model_version)
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
        await self.set(comment_hn_id, model_version, payload)
        return payload
