import pytest
import asyncio

import fakeredis.aioredis as fakeredis

from app.services.cache.redis import RedisCache
from app.repositories.story_repo import StoryRepository
from app.repositories.top_story_repo import TopStoryRepository
from app.repositories.summary_repo import SummaryRepository
from app.services.cache.summary_cache import SummaryCache
from app.db.session import get_engine, init_sessionmaker, Base, get_session
from app.tasks.fetch_jobs import run_fetch_once
from app.services.sources.hackernews.fetcher import StoryData
from app.services.ai.mock_provider import MockAIProvider
from app.config import settings
from app.services.cache.feed_cache import FeedCache


@pytest.mark.asyncio
async def test_summaries_run_only_when_enabled():
    fake = fakeredis.FakeRedis()
    redis = RedisCache(client=fake)
    await redis.init()

    engine = get_engine("sqlite:///:memory:")
    SessionLocal = init_sessionmaker(engine)
    Base.metadata.create_all(engine)

    repo = StoryRepository()
    top_repo = TopStoryRepository()
    summary_repo = SummaryRepository()
    summary_cache = SummaryCache(redis, summary_repo)
    feed_cache = FeedCache(redis, top_repo)

    s1 = StoryData(hn_id=1, title="a", url="u", score=150, time=1, descendants=0, raw_payload={"id": 1, "score": 150, "title": "a"})

    class DummyFetcher:
        async def fetch_top_ids(self):
            return [1]

        async def fetch_and_normalize(self, hn_id: int):
            return s1

    fetcher = DummyFetcher()

    # disabled -> no summary
    settings.ENABLE_SUMMARIZATION = False
    inserted, updated = await run_fetch_once(SessionLocal, fetcher, repo, feed_cache, limit=10, top_story_repo=top_repo, provider=MockAIProvider(), summary_repo=summary_repo, summary_cache=summary_cache)
    assert inserted == 1

    # Give background tasks time
    await asyncio.sleep(0.05)

    with get_session(SessionLocal) as session:
        row = summary_repo.fetch_latest(session, 1, settings.SUMMARIZATION_MODEL_VERSION)
        assert row is None

    # enabled -> summary should be created asynchronously
    settings.ENABLE_SUMMARIZATION = True
    inserted2, updated2 = await run_fetch_once(SessionLocal, fetcher, repo, feed_cache, limit=10, top_story_repo=top_repo, provider=MockAIProvider(), summary_repo=summary_repo, summary_cache=summary_cache)
    assert inserted2 == 0 or inserted2 == 1

    # Wait for background summary to finish
    await asyncio.sleep(0.1)

    with get_session(SessionLocal) as session:
        row2 = summary_repo.fetch_latest(session, 1, settings.SUMMARIZATION_MODEL_VERSION)
        assert row2 is not None
        assert row2.tldr is not None


@pytest.mark.asyncio
async def test_summary_failure_does_not_stop_fetch(caplog):
    fake = fakeredis.FakeRedis()
    redis = RedisCache(client=fake)
    await redis.init()

    engine = get_engine("sqlite:///:memory:")
    SessionLocal = init_sessionmaker(engine)
    Base.metadata.create_all(engine)

    repo = StoryRepository()
    top_repo = TopStoryRepository()
    summary_repo = SummaryRepository()
    summary_cache = SummaryCache(redis, summary_repo)
    feed_cache = FeedCache(redis, top_repo)

    s1 = StoryData(hn_id=2, title="b", url="u", score=150, time=1, descendants=0, raw_payload={"id": 2, "score": 150, "title": "b"})

    class FailingProvider:
        async def summarize_story(self, payload):
            raise RuntimeError("provider down")

    class DummyFetcher:
        async def fetch_top_ids(self):
            return [2]

        async def fetch_and_normalize(self, hn_id: int):
            return s1

    fetcher = DummyFetcher()

    settings.ENABLE_SUMMARIZATION = True

    inserted, updated = await run_fetch_once(SessionLocal, fetcher, repo, feed_cache, limit=10, top_story_repo=top_repo, provider=FailingProvider(), summary_repo=summary_repo, summary_cache=summary_cache)
    assert inserted == 1

    # Wait for background task
    await asyncio.sleep(0.1)

    # fetch again to ensure system still works
    inserted2, updated2 = await run_fetch_once(SessionLocal, fetcher, repo, feed_cache, limit=10, top_story_repo=top_repo, provider=MockAIProvider(), summary_repo=summary_repo, summary_cache=summary_cache)
    assert inserted2 == 0 or inserted2 == 1
