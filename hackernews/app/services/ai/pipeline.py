"""Summary pipeline that uses an AI provider to summarize stories."""
from __future__ import annotations
from typing import Protocol, Any

from app.services.sources.hackernews.fetcher import StoryData
from app.services.ai.schemas import SummaryData


class ProviderProtocol(Protocol):
    async def summarize_story(self, story_payload: dict) -> SummaryData: ...


class SummaryPipeline:
    def __init__(self, provider: ProviderProtocol):
        self.provider = provider

    async def summarize(self, story: StoryData) -> SummaryData:
        # Convert StoryData to raw payload (provider expects dict)
        payload = story.raw_payload or {"id": story.hn_id}
        summary = await self.provider.summarize_story(payload)
        return summary
