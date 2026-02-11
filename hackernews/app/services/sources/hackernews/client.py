"""Async Hacker News HTTP client with rate limiting and retries."""
from __future__ import annotations

import asyncio
import time
from typing import Optional, Any, Callable

import httpx


class AsyncHNClient:
    """Thin async HTTP client for Hacker News.

    - Configurable base_url
    - Simple token-bucket rate limiting
    - Semaphore for concurrency limiting
    - Exponential backoff retries for network/5xx errors
    - Accepts an injected `httpx.AsyncClient` for testing
    """

    def __init__(
        self,
        base_url: str = "https://hacker-news.firebaseio.com/v0",
        rate_limit_per_sec: float = 10.0,
        max_concurrency: int = 5,
        timeout: float = 10.0,
        max_retries: int = 3,
        backoff_factor: float = 0.5,
        client: Optional[httpx.AsyncClient] = None,
    ) -> None:
        self.base_url = base_url.rstrip("/")
        self._rate = float(rate_limit_per_sec)
        self._tokens = self._rate
        self._last_refill = time.monotonic()
        self._lock = asyncio.Lock()

        self._semaphore = asyncio.Semaphore(max_concurrency)
        self._max_retries = max_retries
        self._backoff_factor = backoff_factor

        self._client = client
        self._own_client = False
        self._timeout = timeout

    async def init(self):
        if self._client is None:
            self._client = httpx.AsyncClient(base_url=self.base_url, timeout=self._timeout)
            self._own_client = True

    async def close(self):
        if self._own_client and self._client is not None:
            await self._client.aclose()

    async def _acquire_token(self):
        # token-bucket algorithm
        async with self._lock:
            now = time.monotonic()
            elapsed = now - self._last_refill
            # refill tokens
            self._tokens = min(self._rate, self._tokens + elapsed * self._rate)
            self._last_refill = now
            if self._tokens >= 1.0:
                self._tokens -= 1.0
                return
            # not enough tokens, compute wait time and release lock before sleeping
            needed = 1.0 - self._tokens
            wait_seconds = needed / self._rate
        await asyncio.sleep(wait_seconds)
        # after sleep, try again (recursive)
        await self._acquire_token()

    async def _request(self, method: str, url: str, **kwargs) -> httpx.Response:
        await self._acquire_token()
        async with self._semaphore:
            last_err: Optional[Exception] = None
            for attempt in range(1, self._max_retries + 1):
                try:
                    if self._client is None:
                        raise RuntimeError("HTTP client not initialized. Call init() first.")
                    resp = await self._client.request(method, url, **kwargs)
                    # 429 - respect Retry-After when present
                    if resp.status_code == 429:
                        retry_after = resp.headers.get("Retry-After")
                        sleep_for = float(retry_after) if retry_after is not None else self._backoff_factor * (2 ** (attempt - 1))
                        await asyncio.sleep(sleep_for)
                        last_err = httpx.HTTPStatusError("429 Too Many Requests", request=resp.request, response=resp)
                        continue
                    if resp.status_code >= 500:
                        last_err = httpx.HTTPStatusError("5xx server error", request=resp.request, response=resp)
                        # exponential backoff
                        await asyncio.sleep(self._backoff_factor * (2 ** (attempt - 1)))
                        continue
                    return resp
                except (httpx.NetworkError, httpx.TimeoutException, httpx.HTTPStatusError) as e:
                    last_err = e
                    if attempt == self._max_retries:
                        raise
                    await asyncio.sleep(self._backoff_factor * (2 ** (attempt - 1)))
            # If we exit loop, raise last error
            raise last_err if last_err is not None else RuntimeError("Unknown request failure")

    async def fetch_top_story_ids(self) -> list[int]:
        await self.init()
        resp = await self._request("GET", "/topstories.json")
        return resp.json()

    async def fetch_item(self, item_id: int) -> dict[str, Any]:
        await self.init()
        resp = await self._request("GET", f"/item/{item_id}.json")
        return resp.json()
