import asyncio
import pytest

import fakeredis.aioredis as fakeredis

from app.services.cache.redis import RedisCache


@pytest.mark.asyncio
async def test_set_get_json_and_ttl():
    fake = fakeredis.FakeRedis()
    cache = RedisCache(client=fake)
    await cache.init()

    await cache.set_json("test:k", {"a": 1}, ex=1)
    v = await cache.get_json("test:k")
    assert v == {"a": 1}

    # wait for expiry
    await asyncio.sleep(1.1)
    v2 = await cache.get_json("test:k")
    assert v2 is None


@pytest.mark.asyncio
async def test_lock_context_manager():
    fake = fakeredis.FakeRedis()
    cache = RedisCache(client=fake)
    await cache.init()

    async with cache.lock("lock:1", timeout=1):
        # inside lock
        assert True

    # lock released, should be able to re-acquire
    async with cache.lock("lock:1", timeout=1):
        assert True
