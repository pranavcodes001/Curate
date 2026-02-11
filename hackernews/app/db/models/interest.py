from sqlalchemy import Column, Integer, String, JSON, UniqueConstraint, DateTime
from datetime import datetime

from app.db.session import Base


class Interest(Base):
    __tablename__ = "interests"
    __table_args__ = (UniqueConstraint("group_name", "name", name="uq_interest_group_name"),)

    id = Column(Integer, primary_key=True, index=True)
    group_name = Column(String, nullable=False, index=True)
    name = Column(String, nullable=False, index=True)
    keywords = Column(JSON, nullable=False)
    read_count = Column(Integer, default=0, nullable=False)
    last_read_at = Column(DateTime, nullable=True)

    def __repr__(self) -> str:
        return f"<Interest {self.group_name}:{self.name}>"
