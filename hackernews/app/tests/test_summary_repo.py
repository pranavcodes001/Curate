from app.db.session import get_engine, init_sessionmaker, Base, get_session
from app.repositories.summary_repo import SummaryRepository
from app.services.ai.schemas import SummaryData


def test_summary_repo_upsert_idempotency():
    engine = get_engine("sqlite:///:memory:")
    SessionLocal = init_sessionmaker(engine)
    Base.metadata.create_all(engine)

    repo = SummaryRepository()

    with get_session(SessionLocal) as session:
        s = SummaryData(tldr="t1", key_points=["a"], consensus="mixed")
        row, created, updated = repo.upsert_summary(session, story_hn_id=1, summary=s, model_version="v1")
        assert created is True
        assert updated is False

        # same summary -> no update
        row2, created2, updated2 = repo.upsert_summary(session, story_hn_id=1, summary=s, model_version="v1")
        assert created2 is False
        assert updated2 is False

        # changed summary -> update
        s2 = SummaryData(tldr="t2", key_points=["b"], consensus="positive")
        row3, created3, updated3 = repo.upsert_summary(session, story_hn_id=1, summary=s2, model_version="v1")
        assert created3 is False
        assert updated3 is True
        assert row3.tldr == "t2"
