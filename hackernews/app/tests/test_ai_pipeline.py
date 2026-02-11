import pytest

from app.services.ai.mock_provider import MockAIProvider
from app.services.ai.pipeline import SummaryPipeline
from app.services.sources.hackernews.fetcher import StoryData


@pytest.mark.asyncio
async def test_mock_provider_deterministic():
    provider = MockAIProvider()
    payload = {"id": 123, "title": "Test Post", "score": 10, "time": 1}
    s1 = await provider.summarize_story(payload)
    s2 = await provider.summarize_story(payload)
    assert s1.tldr == s2.tldr
    assert s1.key_points == s2.key_points
    assert s1.consensus == s2.consensus
    assert s1.consensus == "mixed"


@pytest.mark.asyncio
async def test_pipeline_uses_provider():
    provider = MockAIProvider()
    pipeline = SummaryPipeline(provider)

    sd = StoryData(hn_id=123, title="T", url="u", score=5, time=1, descendants=0, raw_payload={"id": 123, "title": "T", "score": 5})
    summary = await pipeline.summarize(sd)
    assert summary.tldr.startswith("TL;DR:" )
    assert isinstance(summary.key_points, list)
    assert summary.consensus == "mixed"
