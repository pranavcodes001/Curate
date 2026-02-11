from datetime import datetime
from typing import Optional

from sqlalchemy.orm import Session
from sqlalchemy import func

from app.db.models.user import User


class UserRepository:
    def get_by_email(self, session: Session, email: str) -> Optional[User]:
        normalized = email.strip().lower()
        return (
            session.query(User)
            .filter(func.lower(User.email) == normalized)
            .one_or_none()
        )

    def create(self, session: Session, email: str, password_hash: str, name: Optional[str] = None) -> User:
        now = datetime.utcnow()
        user = User(
            name=name,
            email=email.strip().lower(),
            password_hash=password_hash,
            is_active=True,
            created_at=now,
            updated_at=now,
        )
        session.add(user)
        session.commit()
        session.refresh(user)
        return user
