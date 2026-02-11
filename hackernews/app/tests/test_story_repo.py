from datetime import datetime, timedelta
import time

from app.db.session import get_engine, init_sessionmaker, Base, get_session
from app.services.sources.hackernews.fetcher import StoryData
from app.repositories.story_repo import StoryRepository


def test_upsert_insert_and_no_update_on_same_payload():
    engine = get_engine("sqlite:///:memory:")
    SessionLocal = init_sessionmaker(engine)
    Base.metadata.create_all(engine)

    repo = StoryRepository()

    with get_session(SessionLocal) as session:
        data = StoryData(hn_id=1, title="t1", url="http://x", score=10, time=1, descendants=0, raw_payload={"id": 1, "title": "t1"})
        story, created, updated = repo.upsert(session, data)
        assert created is True
        assert updated is False
        first_updated_at = story.updated_at

        # Re-insert same payload
        time.sleep(0.01)
        story2, created2, updated2 = repo.upsert(session, data)
        assert created2 is False
        assert updated2 is False
        assert story2.id == story.id
        assert story2.updated_at == first_updated_at
        assert story2.last_fetched_at is not None

        # Now change payload
        data2 = StoryData(hn_id=1, title="t2", url="http://y", score=20, time=2, descendants=1, raw_payload={"id": 1, "title": "t2"})
        story3, created3, updated3 = repo.upsert(session, data2)
        assert created3 is False
        assert updated3 is True
        assert story3.title == "t2"
        assert story3.url == "http://y"
        assert story3.updated_at > first_updated_at


def test_fetch_latest_ordering():
    engine = get_engine("sqlite:///:memory:")
    SessionLocal = init_sessionmaker(engine)
    Base.metadata.create_all(engine)

    repo = StoryRepository()

    with get_session(SessionLocal) as session:
        data1 = StoryData(hn_id=1, title="a", url="u", score=1, time=1, descendants=0, raw_payload={"id": 1})
        data2 = StoryData(hn_id=2, title="b", url="v", score=2, time=2, descendants=0, raw_payload={"id": 2})

        repo.upsert(session, data1)
        time.sleep(0.01)
        repo.upsert(session, data2)

        latest = repo.fetch_latest(session, limit=10)
        assert [s.hn_id for s in latest] == [2, 1]
