import pytest
import asyncio
import fakeredis.aioredis as fakeredis
from app.services.cache.summary_cache import SummaryCache
from app.services.cache.redis import RedisCache
from app.repositories.summary_repo import SummaryRepository
from app.db.session import get_engine, init_sessionmaker, Base, get_session
from app.services.ai.schemas import SummaryData


@pytest.mark.asyncio
async def test_summary_cache_set_get_and_db_fallback():
    fake = fakeredis.FakeRedis()
    redis = RedisCache(client=fake)
    await redis.init()
    cache = SummaryCache(redis, SummaryRepository())

    engine = get_engine("sqlite:///:memory:")
    SessionLocal = init_sessionmaker(engine)
    Base.metadata.create_all(engine)

    repo = SummaryRepository()

    with get_session(SessionLocal) as session:
        s = SummaryData(tldr="t1", key_points=["a"], consensus="mixed")
        row, created, updated = repo.upsert_summary(session, story_hn_id=1, summary=s, model_version="v1")

        # cache miss -> db fallback
        payload = await cache.get_or_db(session, 1, "v1")
        assert payload["tldr"] == "t1"

        # set cache explicitly and read
        await cache.set(1, "v1", {"tldr": "x"})
        got = await cache.get(1, "v1")
        assert got["tldr"] == "x"

