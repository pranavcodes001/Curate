"""HN search client (Algolia API)."""
from __future__ import annotations
from typing import Any, List

import httpx

from app.config import settings


class HNSearchClient:
    def __init__(self, base_url: str | None = None, timeout: float = 10.0) -> None:
        self.base_url = str(base_url or settings.SEARCH_API_URL)
        self._timeout = timeout
        self._client: httpx.AsyncClient | None = None

    async def init(self):
        if self._client is None:
            self._client = httpx.AsyncClient(timeout=self._timeout)

    async def close(self):
        if self._client is not None:
            await self._client.aclose()
            self._client = None

    async def search(self, query: str, limit: int, min_timestamp: int = 0) -> List[dict[str, Any]]:
        await self.init()
        assert self._client is not None
        
        # Use search_by_date to get newest items first
        url = self.base_url.replace("/search", "/search_by_date")
        
        params = {
            "query": query,
            "tags": "story",
            "hitsPerPage": limit,
        }
        
        if min_timestamp > 0:
            params["numericFilters"] = f"created_at_i>{min_timestamp}"
            
        resp = await self._client.get(url, params=params)
        resp.raise_for_status()
        data = resp.json()
        return data.get("hits", []) if isinstance(data, dict) else []
