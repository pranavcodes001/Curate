import asyncio
import time

import httpx
import pytest

from httpx import Response
from httpx import AsyncClient, Request
from httpx._transports.base import AsyncByteStream
from httpx._content_streams import IteratorStream
from httpx._models import Headers
from httpx import MockTransport

from app.services.sources.hackernews.client import AsyncHNClient


@pytest.mark.asyncio
async def test_fetch_top_ids_success():
    def handler(request: Request):
        if request.url.path == "/topstories.json":
            return Response(200, json=[12345, 23456, 34567])
        return Response(404)

    transport = MockTransport(handler)
    async with AsyncClient(transport=transport, base_url="https://example.com") as ac:
        client = AsyncHNClient(base_url="https://example.com", client=ac)
        ids = await client.fetch_top_story_ids()
        assert ids == [12345, 23456, 34567]


@pytest.mark.asyncio
async def test_fetch_item_retry_and_backoff():
    # first return 500, then 200
    state = {"calls": 0}

    def handler(request: Request):
        if request.url.path == "/item/12345.json":
            state["calls"] += 1
            if state["calls"] == 1:
                return Response(500)
            return Response(200, json={"id": 12345, "title": "ok"})
        return Response(404)

    transport = MockTransport(handler)
    async with AsyncClient(transport=transport, base_url="https://example.com") as ac:
        # small backoff for faster test
        client = AsyncHNClient(base_url="https://example.com", client=ac, backoff_factor=0.01, max_retries=3)
        data = await client.fetch_item(12345)
        assert data["id"] == 12345
        assert state["calls"] == 2


@pytest.mark.asyncio
async def test_rate_limit_enforced():
    # return small payload for item requests
    def handler(request: Request):
        if request.url.path.startswith("/item/"):
            return Response(200, json={"id": int(request.url.path.split("/")[-1].split(".")[0])})
        return Response(404)

    transport = MockTransport(handler)
    async with AsyncClient(transport=transport, base_url="https://example.com") as ac:
        # rate limit = 1 req/sec to force delay
        client = AsyncHNClient(base_url="https://example.com", client=ac, rate_limit_per_sec=1.0)

        start = time.monotonic()
        # schedule two fetches concurrently
        results = await asyncio.gather(client.fetch_item(1), client.fetch_item(2))
        elapsed = time.monotonic() - start
        # Since rate is 1 per sec and we made 2 requests, elapsed should be at least ~1s
        assert elapsed >= 0.9
        assert results[0]["id"] == 1
        assert results[1]["id"] == 2
