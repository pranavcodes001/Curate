from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime, JSON, Text

from app.db.session import Base


class SavedThreadItem(Base):
    __tablename__ = "saved_thread_items"

    id = Column(Integer, primary_key=True, index=True)
    saved_thread_id = Column(Integer, nullable=False, index=True)
    item_type = Column(String, nullable=False)  # "story" | "comment"
    hn_id = Column(Integer, nullable=False, index=True)
    raw_text = Column(Text, nullable=True)
    ai_summary = Column(JSON, nullable=True)
    model_name = Column(String, nullable=True)
    model_version = Column(String, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    def __repr__(self) -> str:
        return f"<SavedThreadItem thread={self.saved_thread_id} type={self.item_type} hn_id={self.hn_id}>"
