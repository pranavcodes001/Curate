from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime, Text, JSON, Index

from app.db.session import Base


class Comment(Base):
    __tablename__ = "comments"

    id = Column(Integer, primary_key=True, index=True)
    comment_hn_id = Column(Integer, unique=True, nullable=False, index=True)
    story_hn_id = Column(Integer, nullable=False, index=True)
    parent_hn_id = Column(Integer, nullable=True, index=True)
    author = Column(String, nullable=True)
    time = Column(Integer, nullable=True)
    text = Column(Text, nullable=True)
    raw_payload = Column(JSON, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    def __repr__(self) -> str:
        return f"<Comment hn_id={self.comment_hn_id} story={self.story_hn_id}>"


Index("ix_comments_story_time", Comment.story_hn_id, Comment.time)
