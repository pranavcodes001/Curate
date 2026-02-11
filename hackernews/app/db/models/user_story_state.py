from datetime import datetime
from sqlalchemy import Column, Integer, DateTime, UniqueConstraint

from app.db.session import Base


class UserStoryState(Base):
    __tablename__ = "user_story_state"
    __table_args__ = (UniqueConstraint("user_id", "story_hn_id", name="uq_user_story_state"),)

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, nullable=False, index=True)
    story_hn_id = Column(Integer, nullable=False, index=True)
    last_seen_at = Column(DateTime, nullable=True)
    last_read_at = Column(DateTime, nullable=True)
    dismissed_at = Column(DateTime, nullable=True)
    read_count = Column(Integer, default=0, nullable=False)

    def __repr__(self) -> str:
        return f"<UserStoryState user={self.user_id} story={self.story_hn_id} reads={self.read_count}>"
