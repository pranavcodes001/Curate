"""Fetcher and normalization utilities for Hacker News items."""
from __future__ import annotations

from dataclasses import dataclass
from typing import Optional

from app.services.sources.hackernews.client import AsyncHNClient


@dataclass(frozen=True)
class StoryData:
    hn_id: int
    title: Optional[str]
    url: Optional[str]
    score: Optional[int]
    time: Optional[int]
    descendants: Optional[int]
    raw_payload: dict


class HNFetcher:
    def __init__(self, client: AsyncHNClient):
        self._client = client

    async def fetch_top_ids(self) -> list[int]:
        return await self._client.fetch_top_story_ids()

    async def fetch_and_normalize(self, hn_id: int) -> StoryData:
        raw = await self._client.fetch_item(hn_id)
        return normalize_story(raw)


def normalize_story(raw: dict) -> StoryData:
    # Pure function: safe defaults and explicit fields
    if raw is None:
        raise ValueError("raw payload is None")

    hn_id = raw.get("id")
    return StoryData(
        hn_id=hn_id,
        title=raw.get("title"),
        url=raw.get("url"),
        score=raw.get("score"),
        time=raw.get("time"),
        descendants=raw.get("descendants"),
        raw_payload=raw,
    )
