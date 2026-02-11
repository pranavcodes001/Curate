from fastapi.testclient import TestClient
import asyncio

import fakeredis.aioredis as fakeredis

from app.main import create_app
from app.services.cache.redis import RedisCache
from app.db.session import get_engine, init_sessionmaker, Base, get_session
from app.repositories.story_repo import StoryRepository
from app.services.sources.hackernews.fetcher import StoryData
from app.services.cache.feed_cache import FeedCache


def test_api_returns_feed_from_cache_and_db_fallback():
    # Setup DB
    engine = get_engine("sqlite:///:memory:")
    SessionLocal = init_sessionmaker(engine)
    Base.metadata.create_all(engine)

    repo = StoryRepository()

    with get_session(SessionLocal) as session:
        s1 = StoryData(hn_id=1, title="a", url="u", score=1, time=1, descendants=0, raw_payload={"id": 1, "score": 1, "time": 1})
        s2 = StoryData(hn_id=2, title="b", url="v", score=2, time=2, descendants=0, raw_payload={"id": 2, "score": 2, "time": 2})
        repo.upsert(session, s1)
        repo.upsert(session, s2)

    # Setup fake redis and prime cache
    fake = fakeredis.FakeRedis()
    cache = RedisCache(client=fake)

    asyncio.get_event_loop().run_until_complete(cache.init())

    fc = FeedCache(cache, repo)
    with get_session(SessionLocal) as session:
        asyncio.get_event_loop().run_until_complete(fc.prime_feed(session, limit=10))

    # Create app with our redis cache and engine
    app = create_app(redis_cache=cache, engine=engine)

    with TestClient(app) as client:
        # Request feed (from cache)
        resp = client.get("/v1/stories")
        assert resp.status_code == 200
        data = resp.json()
        assert isinstance(data, list)
        assert len(data) == 2

        # Clear cache and test DB fallback
        asyncio.get_event_loop().run_until_complete(cache.delete("feed:global:v1"))

        resp2 = client.get("/v1/stories")
        assert resp2.status_code == 200
        data2 = resp2.json()
        assert isinstance(data2, list)
        assert len(data2) == 2
