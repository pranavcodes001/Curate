from __future__ import annotations
from datetime import datetime, timezone
from typing import Optional

from app.services.cache.redis import RedisCache

QUEUE_KEY = "saved_thread:queue"


async def enqueue_saved_thread(redis_cache: RedisCache, user_id: int, story_hn_id: int, comment_hn_ids: list[int]) -> Optional[int]:
    payload = {
        "user_id": user_id,
        "story_hn_id": story_hn_id,
        "comment_hn_ids": comment_hn_ids,
        "requested_at": datetime.now(timezone.utc).isoformat(),
    }
    return await redis_cache.lpush(QUEUE_KEY, payload)


async def dequeue_saved_thread(redis_cache: RedisCache) -> Optional[dict]:
    return await redis_cache.rpop(QUEUE_KEY)
