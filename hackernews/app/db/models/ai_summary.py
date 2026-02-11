from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime, JSON, UniqueConstraint

from app.db.session import Base


class AiSummary(Base):
    __tablename__ = "ai_summaries"
    __table_args__ = (UniqueConstraint("story_hn_id", "model_version", name="uq_story_modelver"),)

    id = Column(Integer, primary_key=True, index=True)
    story_hn_id = Column(Integer, nullable=False, index=True)
    model_name = Column(String, nullable=True)
    model_version = Column(String, nullable=False)
    content_hash = Column(String(128), nullable=False, index=True)

    tldr = Column(String, nullable=True)
    key_points = Column(JSON, nullable=True)
    consensus = Column(String, nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    def __repr__(self) -> str:
        return f"<AiSummary story={self.story_hn_id} model={self.model_version}>"
