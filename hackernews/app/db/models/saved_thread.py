from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime

from app.db.session import Base


class SavedThread(Base):
    __tablename__ = "saved_threads"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, nullable=False, index=True)
    story_hn_id = Column(Integer, nullable=False, index=True)
    title = Column(String, nullable=True)
    url = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    def __repr__(self) -> str:
        return f"<SavedThread id={self.id} story={self.story_hn_id} user={self.user_id}>"
