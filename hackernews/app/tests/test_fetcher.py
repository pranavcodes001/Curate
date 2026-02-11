import pytest
import json
import os

from httpx import Response, Request
from httpx import MockTransport, AsyncClient

from app.services.sources.hackernews.client import AsyncHNClient
from app.services.sources.hackernews.fetcher import HNFetcher, normalize_story, StoryData


@pytest.mark.asyncio
async def test_normalize_story_from_fixture():
    here = os.path.dirname(__file__)
    path = os.path.join(here, "../../tests/fixtures/item_12345.json")
    path = os.path.normpath(path)
    with open(path, "r", encoding="utf-8") as fh:
        raw = json.load(fh)

    sd = normalize_story(raw)
    assert isinstance(sd, StoryData)
    assert sd.hn_id == 12345
    assert sd.title == "An interesting HN post"
    assert sd.url == "https://example.com/article"


@pytest.mark.asyncio
async def test_fetcher_fetch_and_normalize():
    def handler(request: Request):
        if request.url.path == "/item/12345.json":
            return Response(200, json={"id": 12345, "title": "ok", "url": "http://a"})
        return Response(404)

    transport = MockTransport(handler)
    async with AsyncClient(transport=transport, base_url="https://example.com") as ac:
        client = AsyncHNClient(base_url="https://example.com", client=ac)
        fetcher = HNFetcher(client)
        sd = await fetcher.fetch_and_normalize(12345)
        assert sd.hn_id == 12345
        assert sd.title == "ok"
        assert sd.url == "http://a"
