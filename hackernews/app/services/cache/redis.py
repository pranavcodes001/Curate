"""Redis cache helpers for MVP v1."""
import json
import logging
from typing import Any, Optional
import asyncio

import redis.asyncio as aioredis


class RedisCache:
    """Async Redis cache wrapper.

    - Supports injection of a redis client for testing (`client=`).
    - Provides simple JSON get/set and a lock context manager for stampede protection.
    """

    def __init__(self, url: Optional[str] = None, client: Optional[Any] = None):
        self._url = url
        self._client = client
        self._own_client = False

    async def init(self):
        if self._url is None:
            # Redis disabled (local dev)
            self._client = None
            return

        if self._client is None:
            try:
                self._client = aioredis.from_url(
                    self._url, encoding="utf-8", decode_responses=True
                )
                # Validate connection early to avoid runtime failures
                await self._client.ping()
                self._own_client = True
            except Exception:
                logging.getLogger(__name__).warning(
                    "Redis unavailable at %s; continuing without cache",
                    self._url,
                )
                self._client = None
                self._own_client = False



    async def close(self):
        if self._own_client and self._client:
            await self._client.close()

    def enabled(self) -> bool:
        return self._client is not None

    async def set_json(self, key: str, value: Any, ex: Optional[int] = None) -> None:
        if not self._client:
            return
        payload = json.dumps(value)
        await self._client.set(key, payload, ex=ex)

    async def get_json(self, key: str) -> Optional[Any]:
        if not self._client:
            return None
        data = await self._client.get(key)
        return json.loads(data) if data is not None else None

    async def delete(self, key: str) -> None:
        if not self._client:
            return
        await self._client.delete(key)

    async def incr(self, key: str, ex: Optional[int] = None) -> Optional[int]:
        if not self._client:
            return None
        val = await self._client.incr(key)
        if ex:
            await self._client.expire(key, ex)
        return int(val)

    # --- Reactive Signaling ---

    async def signal_interest_fetch(self, interest_id: int) -> None:
        """Signal the worker to fetch new stories for a specific interest."""
        if not self._client:
            return
        # Use a Set to avoid duplicate signals for the same interest in the queue
        # This acts as a "de-bouncer"
        already_queued = await self._client.sismember("pending_interests_set", str(interest_id))
        if not already_queued:
            await self._client.sadd("pending_interests_set", str(interest_id))
            await self._client.lpush("interest_fetch_queue", str(interest_id))

    async def get_next_interest_signal(self, timeout: int = 5) -> Optional[int]:
        """Worker: Wait for a signal to fetch an interest."""
        if not self._client:
            return None
        res = await self._client.brpop("interest_fetch_queue", timeout=timeout)
        if res:
            _, iid_str = res
            await self._client.srem("pending_interests_set", iid_str)
            return int(iid_str)
        return None

    async def signal_comment_fetch(self, hn_id: int) -> None:
        """Signal the worker to fetch comments for a specific story."""
        if not self._client:
            return
        already_queued = await self._client.sismember("pending_comments_set", str(hn_id))
        if not already_queued:
            await self._client.sadd("pending_comments_set", str(hn_id))
            await self._client.lpush("comment_fetch_queue", str(hn_id))

    async def get_next_comment_signal(self, timeout: int = 5) -> Optional[int]:
        """Worker: Wait for a signal to fetch comments."""
        if not self._client:
            return None
        res = await self._client.brpop("comment_fetch_queue", timeout=timeout)
        if res:
            _, hn_id_str = res
            await self._client.srem("pending_comments_set", hn_id_str)
            return int(hn_id_str)
        return None

    # --- Watermarking ---

    async def set_interest_watermark(self, interest_id: int, hn_id: int) -> None:
        """Store the latest hn_id fetched for this interest."""
        if not self._client:
            return
        await self._client.hset("interest_watermarks", str(interest_id), str(hn_id))

    async def get_interest_watermark(self, interest_id: int) -> int:
        """Get the latest hn_id fetched for this interest."""
        if not self._client:
            return 0
        val = await self._client.hget("interest_watermarks", str(interest_id))
        return int(val) if val else 0

    # --- Active User Tracking ---

    async def track_active_user(self, user_id: int, window_seconds: int = 600) -> None:
        import time
        if not self._client:
            return
        now = time.time()
        await self._client.zadd("active_users", {str(user_id): now})
        # Cleanup and expire
        await self._client.zremrangebyscore("active_users", 0, now - window_seconds)
        await self._client.expire("active_users", window_seconds * 2)

    async def get_active_user_count(self) -> int:
        import time
        if not self._client:
            return 0
        now = time.time()
        # count users active in last 10 mins
        count = await self._client.zcount("active_users", now - 600, now)
        return int(count) if count else 0

    async def lpush(self, key: str, value: Any) -> Optional[int]:
        if not self._client:
            return None
        payload = json.dumps(value)
        return await self._client.lpush(key, payload)

    async def rpop(self, key: str) -> Optional[Any]:
        if not self._client:
            return None
        data = await self._client.rpop(key)
        if data is None:
            return None
        try:
            return json.loads(data)
        except Exception:
            return data

    async def llen(self, key: str) -> Optional[int]:
        if not self._client:
            return None
        return int(await self._client.llen(key))

    
    def lock(self, name: str, timeout: int = 10):
        if not self._client:
            return _NoOpLock()
        return _RedisLock(self._client, name, timeout)

    

class _RedisLock:
    def __init__(self, client, name: str, timeout: int = 10):
        self._client = client
        self._name = name
        self._timeout = timeout
        # redis-py provides an asyncio-compatible Lock via client.lock
        self._lock = client.lock(name, timeout=timeout)

    async def __aenter__(self):
        # Acquire the lock, waiting until it's available.
        acquired = await self._lock.acquire()
        if not acquired:
            # If acquire returned False for whatever reason, raise
            raise RuntimeError("Failed to acquire redis lock")
        return self

    async def __aexit__(self, exc_type, exc, tb):
        try:
            await self._lock.release()
        except Exception:
            # best-effort release
            pass

class _NoOpLock:
    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc, tb):
        return False

