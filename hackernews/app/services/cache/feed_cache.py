"""Top stories cache helpers for global list priming and reads."""
from typing import List, Dict

from app.services.cache.redis import RedisCache
from app.repositories.top_story_repo import TopStoryRepository

from app.config import settings

FEED_KEY = "top:global:v1"
LOCK_KEY = "lock:top:global:v1"


class FeedCache:
    def __init__(self, redis_cache: RedisCache, repo: TopStoryRepository):
        self.redis = redis_cache
        self.repo = repo

    async def read_feed(self) -> List[Dict]:
        """Read feed from Redis. If missing, caller should fallback to DB using `fallback_to_db`."""
        data = await self.redis.get_json(FEED_KEY)
        return data if data is not None else []

    async def prime_feed(self, session, limit: int | None = None) -> List[Dict]:
        """Prime the top stories cache by reading from DB and writing atomically to Redis.

        Uses a Redis lock to avoid stampede.
        Returns the serialized feed written to cache.
        """
        limit = limit or settings.TOP_STORIES_LIMIT
        async with self.redis.lock(LOCK_KEY, timeout=10):
            # Re-check cache after acquiring lock to avoid double work
            existing = await self.redis.get_json(FEED_KEY)
            if existing is not None:
                return existing

            rows = self.repo.list_top_stories(session, limit=limit)

            serialized = [
                {
                    "hn_id": r.hn_id,
                    "title": r.title,
                    "url": r.url,
                    "score": (r.raw_payload or {}).get("score"),
                    "time": (r.raw_payload or {}).get("time"),
                }
                for r in rows
            ]

            # Atomic write (set with TTL)
            await self.redis.set_json(FEED_KEY, serialized, ex=settings.FEED_TTL_SECONDS)
            return serialized

    async def read_or_fallback(self, session) -> List[Dict]:
        """Read feed from cache, fallback to DB if empty (without priming cache)."""
        data = await self.read_feed()
        if data:
            return data

        # fallback to DB (serialize same shape)
        rows = self.repo.list_top_stories(session, limit=settings.TOP_STORIES_LIMIT)
        return [
            {
                "hn_id": r.hn_id,
                "title": r.title,
                "url": r.url,
                "score": (r.raw_payload or {}).get("score"),
                "time": (r.raw_payload or {}).get("time"),
            }
            for r in rows
        ]
