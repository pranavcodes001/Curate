from datetime import datetime
from sqlalchemy import Column, Integer, DateTime, UniqueConstraint

from app.db.session import Base


class TopStory(Base):
    __tablename__ = "top_stories"
    __table_args__ = (UniqueConstraint("hn_id", name="uq_top_story_hn_id"),)

    id = Column(Integer, primary_key=True, index=True)
    hn_id = Column(Integer, nullable=False, index=True)
    rank = Column(Integer, nullable=False)
    fetched_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    def __repr__(self) -> str:
        return f"<TopStory hn_id={self.hn_id} rank={self.rank}>"
