from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime, JSON, UniqueConstraint

from app.db.session import Base


class SearchQuery(Base):
    __tablename__ = "search_queries"
    __table_args__ = (UniqueConstraint("query", "limit", name="uq_search_query_limit"),)

    id = Column(Integer, primary_key=True, index=True)
    query = Column(String, nullable=False, index=True)
    limit = Column(Integer, nullable=False)
    results = Column(JSON, nullable=False)
    fetched_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    def __repr__(self) -> str:
        return f"<SearchQuery query={self.query!r} limit={self.limit}>"
