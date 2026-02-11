from __future__ import annotations
from abc import ABC, abstractmethod
from typing import Protocol

from app.services.ai.schemas import SummaryData


class AIProvider(ABC):
    """Abstract AI provider interface for summarization."""

    @abstractmethod
    async def summarize_story(self, story_payload: dict) -> SummaryData:
        """Return a deterministic summary for a given story payload."""
        raise NotImplementedError
