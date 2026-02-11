from app.db.session import get_engine, init_sessionmaker, Base, get_session
from app.db.models.story import Story


def test_db_insert_and_query():
    engine = get_engine("sqlite:///:memory:")
    SessionLocal = init_sessionmaker(engine)
    # create tables in the in-memory DB
    Base.metadata.create_all(engine)

    with get_session(SessionLocal) as session:
        s = Story(hn_id=100, title="Hello", url="http://example.com", raw_payload={"id": 100})
        session.add(s)
        session.commit()

        fetched = session.query(Story).filter_by(hn_id=100).one()
        assert fetched.title == "Hello"
        assert fetched.raw_payload["id"] == 100
