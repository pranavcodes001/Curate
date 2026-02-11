from __future__ import annotations
from datetime import datetime, timezone
from typing import Optional

from app.services.cache.redis import RedisCache

QUEUE_KEY = "summary:queue"


async def enqueue_summary(redis_cache: RedisCache, hn_id: int, user_id: int) -> Optional[int]:
    payload = {
        "hn_id": hn_id,
        "user_id": user_id,
        "requested_at": datetime.now(timezone.utc).isoformat(),
    }
    return await redis_cache.lpush(QUEUE_KEY, payload)


async def dequeue_summary(redis_cache: RedisCache) -> Optional[dict]:
    return await redis_cache.rpop(QUEUE_KEY)


async def queue_length(redis_cache: RedisCache) -> Optional[int]:
    return await redis_cache.llen(QUEUE_KEY)
