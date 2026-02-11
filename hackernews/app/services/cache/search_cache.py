"""Cache for search results."""
from typing import Optional, Any
import json

from app.services.cache.redis import RedisCache
from app.config import settings


def _search_key(query: str, limit: int) -> str:
    return f"search:hn:q:{query}:limit:{limit}"


class SearchCache:
    def __init__(self, redis_cache: RedisCache):
        self.redis = redis_cache

    async def get(self, query: str, limit: int) -> Optional[list[dict[str, Any]]]:
        key = _search_key(query, limit)
        data = await self.redis.get_json(key)
        return data if isinstance(data, list) else None

    async def set(self, query: str, limit: int, payload: list[dict[str, Any]]) -> None:
        key = _search_key(query, limit)
        await self.redis.set_json(key, payload, ex=settings.SEARCH_TTL_SECONDS)
