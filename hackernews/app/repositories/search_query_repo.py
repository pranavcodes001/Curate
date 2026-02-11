from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy.orm import Session

from app.db.models.search_query import SearchQuery


class SearchQueryRepository:
    def get(self, session: Session, query: str, limit: int) -> Optional[SearchQuery]:
        return session.query(SearchQuery).filter_by(query=query, limit=limit).one_or_none()

    def is_fresh(self, row: SearchQuery, ttl_days: int) -> bool:
        if row.fetched_at is None:
            return False
        cutoff = datetime.utcnow() - timedelta(days=ttl_days)
        return row.fetched_at >= cutoff

    def upsert(self, session: Session, query: str, limit: int, results: list[dict]) -> SearchQuery:
        now = datetime.utcnow()
        row = self.get(session, query, limit)
        if row is None:
            row = SearchQuery(query=query, limit=limit, results=results, fetched_at=now)
            session.add(row)
            session.commit()
            session.refresh(row)
            return row
        row.results = results
        row.fetched_at = now
        session.commit()
        session.refresh(row)
        return row

    def delete_stale(self, session: Session, ttl_days: int) -> int:
        cutoff = datetime.utcnow() - timedelta(days=ttl_days)
        deleted = session.query(SearchQuery).filter(SearchQuery.fetched_at < cutoff).delete(synchronize_session=False)
        session.commit()
        return deleted
