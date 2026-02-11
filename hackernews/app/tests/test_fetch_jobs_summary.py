import pytest
import asyncio

import fakeredis.aioredis as fakeredis

from app.tasks.fetch_jobs import run_summary_for_story_if_enabled
from app.services.ai.mock_provider import MockAIProvider
from app.repositories.summary_repo import SummaryRepository
from app.services.cache.summary_cache import SummaryCache
from app.services.cache.redis import RedisCache
from app.db.session import get_engine, init_sessionmaker, Base, get_session
from app.services.sources.hackernews.fetcher import StoryData
from app.config import settings


@pytest.mark.asyncio
async def test_run_summary_hook_respects_flag_and_persists(monkeypatch):
    fake = fakeredis.FakeRedis()
    redis = RedisCache(client=fake)
    await redis.init()

    engine = get_engine("sqlite:///:memory:")
    SessionLocal = init_sessionmaker(engine)
    Base.metadata.create_all(engine)

    summary_repo = SummaryRepository()
    summary_cache = SummaryCache(redis, summary_repo)
    provider = MockAIProvider()

    sd = StoryData(hn_id=99, title="T", url="u", score=150, time=1, descendants=0, raw_payload={"id": 99, "title": "T", "score": 150})

    # Insert story row to simulate persisted story (simple stub object with attributes)
    class StoryRow:
        def __init__(self, sd):
            self.hn_id = sd.hn_id
            self.raw_payload = sd.raw_payload

    story_row = StoryRow(sd)

    # Ensure flag is false -> no-op
    settings.ENABLE_SUMMARIZATION = False
    with get_session(SessionLocal) as session:
        res = await run_summary_for_story_if_enabled(session, story_row, provider, summary_repo, summary_cache, model_version="v1")
        assert res is None

    # Enable summarization -> should persist & cache
    settings.ENABLE_SUMMARIZATION = True
    with get_session(SessionLocal) as session:
        row, created, updated = await run_summary_for_story_if_enabled(session, story_row, provider, summary_repo, summary_cache, model_version="v1", model_name="mock")
        assert created is True
        assert updated is False

        # cache should be populated
        cached = await summary_cache.get(sd.hn_id, "v1")
        assert cached is not None
        assert cached["tldr"].startswith("TL;DR:")

    # Calling again with same provider should be idempotent (no update)
    with get_session(SessionLocal) as session:
        row2, created2, updated2 = await run_summary_for_story_if_enabled(session, story_row, provider, summary_repo, summary_cache, model_version="v1", model_name="mock")
        assert created2 is False
        assert updated2 is False
