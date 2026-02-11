from datetime import datetime, timedelta, timezone
from typing import Any, Dict
import jwt

from app.config import settings


def create_access_token(subject: str, expires_minutes: int | None = None) -> str:
    now = datetime.now(timezone.utc)
    exp = now + timedelta(minutes=expires_minutes or settings.JWT_ACCESS_TTL_MINUTES)
    payload: Dict[str, Any] = {"sub": subject, "iat": now, "exp": exp, "typ": "access"}
    return jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)


def create_refresh_token(subject: str, expires_days: int | None = None) -> str:
    now = datetime.now(timezone.utc)
    exp = now + timedelta(days=expires_days or settings.JWT_REFRESH_TTL_DAYS)
    payload: Dict[str, Any] = {"sub": subject, "iat": now, "exp": exp, "typ": "refresh"}
    return jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)


def decode_token(token: str) -> Dict[str, Any]:
    return jwt.decode(token, settings.JWT_SECRET, algorithms=[settings.JWT_ALGORITHM])
