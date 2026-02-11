from sqlalchemy import Column, Integer, UniqueConstraint

from app.db.session import Base


class UserInterest(Base):
    __tablename__ = "user_interests"
    __table_args__ = (UniqueConstraint("user_id", "interest_id", name="uq_user_interest"),)

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, nullable=False, index=True)
    interest_id = Column(Integer, nullable=False, index=True)

    def __repr__(self) -> str:
        return f"<UserInterest user={self.user_id} interest={self.interest_id}>"
