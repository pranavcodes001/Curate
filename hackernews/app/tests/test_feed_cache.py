import asyncio
import pytest

import fakeredis.aioredis as fakeredis

from app.services.cache.redis import RedisCache
from app.services.cache.feed_cache import FeedCache, FEED_KEY, LOCK_KEY
from app.repositories.story_repo import StoryRepository
from app.db.session import get_engine, init_sessionmaker, Base, get_session
from app.services.sources.hackernews.fetcher import StoryData


@pytest.mark.asyncio
async def test_cache_write_and_read():
    fake = fakeredis.FakeRedis()
    cache = RedisCache(client=fake)
    await cache.init()

    engine = get_engine("sqlite:///:memory:")
    SessionLocal = init_sessionmaker(engine)
    Base.metadata.create_all(engine)

    repo = StoryRepository()

    with get_session(SessionLocal) as session:
        # seed DB
        s1 = StoryData(hn_id=1, title="a", url="u", score=1, time=1, descendants=0, raw_payload={"id": 1, "score": 1, "time": 1})
        s2 = StoryData(hn_id=2, title="b", url="v", score=2, time=2, descendants=0, raw_payload={"id": 2, "score": 2, "time": 2})
        repo.upsert(session, s1)
        repo.upsert(session, s2)

        fc = FeedCache(cache, repo)
        # prime cache
        serialized = await fc.prime_feed(session, limit=10)
        assert isinstance(serialized, list)
        assert len(serialized) == 2

        # read from cache
        read = await fc.read_feed()
        assert read == serialized


@pytest.mark.asyncio
async def test_lock_prevents_concurrent_writes():
    fake = fakeredis.FakeRedis()
    cache = RedisCache(client=fake)
    await cache.init()

    engine = get_engine("sqlite:///:memory:")
    SessionLocal = init_sessionmaker(engine)
    Base.metadata.create_all(engine)

    repo = StoryRepository()

    with get_session(SessionLocal) as session:
        s1 = StoryData(hn_id=1, title="a", url="u", score=1, time=1, descendants=0, raw_payload={"id": 1})
        repo.upsert(session, s1)

        fc = FeedCache(cache, repo)

        # start two concurrent prime_feed calls
        async def worker():
            return await fc.prime_feed(session, limit=10)

        res = await asyncio.gather(worker(), worker())
        # both calls should return a list and be identical
        assert res[0] == res[1]


@pytest.mark.asyncio
async def test_db_fallback_when_cache_empty():
    fake = fakeredis.FakeRedis()
    cache = RedisCache(client=fake)
    await cache.init()

    engine = get_engine("sqlite:///:memory:")
    SessionLocal = init_sessionmaker(engine)
    Base.metadata.create_all(engine)

    repo = StoryRepository()

    with get_session(SessionLocal) as session:
        s1 = StoryData(hn_id=1, title="a", url="u", score=1, time=1, descendants=0, raw_payload={"id": 1, "score": 1, "time": 1})
        repo.upsert(session, s1)

        fc = FeedCache(cache, repo)
        # cache is empty
        read = await fc.read_or_fallback(session)
        assert len(read) == 1
        assert read[0]["hn_id"] == 1
