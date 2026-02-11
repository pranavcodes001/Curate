"""Deterministic mock AI provider for development & tests."""
from __future__ import annotations
import hashlib
from typing import List

from app.services.ai.base import AIProvider
from app.services.ai.schemas import SummaryData


class MockAIProvider(AIProvider):
    """Produces deterministic summaries based on the story payload.

    Rules (deterministic):
      - `tldr` is: "TL;DR: <title>" when title present, else a fallback using id
      - `key_points` are stable extractions from title and first 3 raw field keys
      - `consensus` inferred from `score` in payload: >100 positive, >0 mixed, 0 unclear, <0 negative
    """

    async def summarize_story(self, story_payload: dict) -> SummaryData:
        if story_payload is None:
            raise ValueError("story_payload cannot be None")

        title = story_payload.get("title")
        s_id = story_payload.get("id")
        score = story_payload.get("score")

        if title:
            tldr = f"TL;DR: {title}"
        else:
            tldr = f"TL;DR: story {s_id}"

        # deterministic key points: hash of title and first up to 3 keys
        keys = list(story_payload.keys())[:3]
        kps: List[str] = []
        if title:
            kps.append(f"Title: {title}")
        for k in keys:
            if k != "title":
                kps.append(f"{k}: {story_payload.get(k)!r}")
        # limit to 5 points
        kps = kps[:5]

        # consensus heuristic (deterministic)
        consensus = "unclear"
        try:
            if score is None:
                consensus = "unclear"
            else:
                s = int(score)
                if s > 100:
                    consensus = "positive"
                elif s > 0:
                    consensus = "mixed"
                elif s == 0:
                    consensus = "unclear"
                else:
                    consensus = "negative"
        except Exception:
            consensus = "unclear"

        return SummaryData(tldr=tldr, key_points=kps, consensus=consensus)
