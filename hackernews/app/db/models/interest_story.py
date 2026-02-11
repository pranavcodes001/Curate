from datetime import datetime
from sqlalchemy import Column, Integer, DateTime, UniqueConstraint

from app.db.session import Base


class InterestStory(Base):
    __tablename__ = "interest_stories"
    __table_args__ = (UniqueConstraint("interest_id", "story_hn_id", name="uq_interest_story"),)

    id = Column(Integer, primary_key=True, index=True)
    interest_id = Column(Integer, nullable=False, index=True)
    story_hn_id = Column(Integer, nullable=False, index=True)
    points = Column(Integer, nullable=True)
    time = Column(Integer, nullable=True)
    read_count = Column(Integer, default=0, nullable=False)
    last_seen_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    def __repr__(self) -> str:
        return f"<InterestStory interest={self.interest_id} story={self.story_hn_id}>"
