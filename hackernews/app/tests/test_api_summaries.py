from fastapi.testclient import TestClient
import asyncio

import fakeredis.aioredis as fakeredis

from app.main import create_app
from app.services.cache.redis import RedisCache
from app.db.session import get_engine, init_sessionmaker, Base, get_session
from app.repositories.summary_repo import SummaryRepository
from app.services.ai.schemas import SummaryData
from app.config import settings
from app.services.cache.summary_cache import SummaryCache


def test_summary_returned_when_exists():
    engine = get_engine("sqlite:///:memory:")
    SessionLocal = init_sessionmaker(engine)
    Base.metadata.create_all(engine)

    repo = SummaryRepository()

    with get_session(SessionLocal) as session:
        s = SummaryData(tldr="t1", key_points=["a"], consensus="mixed")
        repo.upsert_summary(session, story_hn_id=1, summary=s, model_version=settings.SUMMARIZATION_MODEL_VERSION)

    fake = fakeredis.FakeRedis()
    redis = RedisCache(client=fake)
    asyncio.get_event_loop().run_until_complete(redis.init())

    app = create_app(redis_cache=redis, engine=engine)

    with TestClient(app) as client:
        resp = client.get(f"/v1/stories/1/summary")
        assert resp.status_code == 200
        data = resp.json()
        assert data["hn_id"] == 1
        assert data["tldr"] == "t1"


def test_summary_404_when_missing():
    engine = get_engine("sqlite:///:memory:")
    SessionLocal = init_sessionmaker(engine)
    Base.metadata.create_all(engine)

    fake = fakeredis.FakeRedis()
    redis = RedisCache(client=fake)
    asyncio.get_event_loop().run_until_complete(redis.init())

    app = create_app(redis_cache=redis, engine=engine)

    with TestClient(app) as client:
        resp = client.get(f"/v1/stories/999/summary")
        assert resp.status_code == 404


def test_cache_hit_vs_db_fallback():
    engine = get_engine("sqlite:///:memory:")
    SessionLocal = init_sessionmaker(engine)
    Base.metadata.create_all(engine)

    repo = SummaryRepository()

    with get_session(SessionLocal) as session:
        s = SummaryData(tldr="t1", key_points=["a"], consensus="mixed")
        repo.upsert_summary(session, story_hn_id=2, summary=s, model_version=settings.SUMMARIZATION_MODEL_VERSION)

    fake = fakeredis.FakeRedis()
    redis = RedisCache(client=fake)
    asyncio.get_event_loop().run_until_complete(redis.init())

    # Create cache and set a different payload (simulate cache being primed)
    cache = SummaryCache(redis, repo)
    asyncio.get_event_loop().run_until_complete(cache.set(2, settings.SUMMARIZATION_MODEL_VERSION, {"tldr": "cached"}))

    app = create_app(redis_cache=redis, engine=engine)

    with TestClient(app) as client:
        resp = client.get(f"/v1/stories/2/summary")
        assert resp.status_code == 200
        data = resp.json()
        assert data["tldr"] == "cached"
