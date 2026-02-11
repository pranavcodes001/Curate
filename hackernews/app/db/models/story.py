from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime, JSON

from app.db.session import Base


class Story(Base):
    __tablename__ = "stories"

    id = Column(Integer, primary_key=True, index=True)
    hn_id = Column(Integer, unique=True, nullable=False, index=True)
    title = Column(String, nullable=True)
    url = Column(String, nullable=True)
    raw_payload = Column(JSON, nullable=True)
    content_hash = Column(String(128), nullable=True, index=True)
    last_fetched_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    # `updated_at` is managed by application logic to ensure it only changes when
    # content fields change (not on each fetch which updates `last_fetched_at`).
    updated_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    def __repr__(self) -> str:
        return f"<Story hn_id={self.hn_id} title={self.title!r}>"
