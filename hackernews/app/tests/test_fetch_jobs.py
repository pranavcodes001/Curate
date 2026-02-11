import pytest
import json

import fakeredis.aioredis as fakeredis

from app.services.cache.redis import RedisCache
from app.repositories.story_repo import StoryRepository
from app.repositories.top_story_repo import TopStoryRepository
from app.db.session import get_engine, init_sessionmaker, Base, get_session
from app.tasks.fetch_jobs import run_fetch_once
from app.services.sources.hackernews.fetcher import StoryData


class DummyFetcher:
    def __init__(self, items):
        self._items = items

    async def fetch_top_ids(self):
        return [i.hn_id for i in self._items]

    async def fetch_and_normalize(self, hn_id: int):
        for i in self._items:
            if i.hn_id == hn_id:
                return i
        return None


@pytest.mark.asyncio
async def test_run_fetch_once_primes_db_and_cache():
    fake = fakeredis.FakeRedis()
    cache = RedisCache(client=fake)
    await cache.init()

    engine = get_engine("sqlite:///:memory:")
    SessionLocal = init_sessionmaker(engine)
    Base.metadata.create_all(engine)

    repo = StoryRepository()
    top_repo = TopStoryRepository()

    s1 = StoryData(hn_id=1, title="a", url="u", score=1, time=1, descendants=0, raw_payload={"id": 1, "score": 1, "time": 1})
    s2 = StoryData(hn_id=2, title="b", url="v", score=2, time=2, descendants=0, raw_payload={"id": 2, "score": 2, "time": 2})

    fetcher = DummyFetcher([s1, s2])
    feed_cache = None

    # Monkeypatch a FeedCache-like thin object that uses repo/cache
    from app.services.cache.feed_cache import FeedCache
    feed_cache = FeedCache(cache, top_repo)

    inserted, updated = await run_fetch_once(SessionLocal, fetcher, repo, feed_cache, limit=10, top_story_repo=top_repo)
    assert inserted == 2
    assert updated == 0

    # Verify cache populated
    read = await feed_cache.read_feed()
    assert len(read) == 2
    ids = [item["hn_id"] for item in read]
    assert set(ids) == {1, 2}

    # Running again with same fetcher should result in zero inserts/updates
    inserted2, updated2 = await run_fetch_once(SessionLocal, fetcher, repo, feed_cache, limit=10, top_story_repo=top_repo)
    assert inserted2 == 0
    assert updated2 == 0
