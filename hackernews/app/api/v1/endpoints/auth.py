from fastapi import APIRouter, HTTPException, status, Depends, Request

from app.config import settings
from app.schemas.auth import LoginIn, TokenOut, RefreshIn
from app.schemas.user import UserCreate, UserLogin, UserOut
from app.services.auth.jwt import create_access_token, create_refresh_token, decode_token
from app.services.auth.deps import require_user
from app.services.auth.passwords import hash_password, verify_password
from app.repositories.user_repo import UserRepository
from app.db.session import get_session

router = APIRouter()


async def _get_session(request: Request):
    SessionLocal = request.app.state.SessionLocal
    with get_session(SessionLocal) as session:
        yield session


@router.post("/auth/admin/login", response_model=TokenOut)
def admin_login(payload: LoginIn):
    if settings.ADMIN_USERNAME is None or settings.ADMIN_PASSWORD is None:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Auth not configured")
    if payload.username != settings.ADMIN_USERNAME or payload.password != settings.ADMIN_PASSWORD:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")

    token = create_access_token(subject=payload.username)
    refresh = create_refresh_token(subject=payload.username)
    return TokenOut(access_token=token, refresh_token=refresh)


@router.post("/auth/register", response_model=UserOut)
def register_user(payload: UserCreate, session=Depends(_get_session)):
    repo = UserRepository()
    existing = repo.get_by_email(session, payload.email)
    if existing is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already registered")
    user = repo.create(session, payload.email, hash_password(payload.password), name=payload.name)
    return user


@router.post("/auth/login", response_model=TokenOut)
def user_login(payload: UserLogin, session=Depends(_get_session)):
    repo = UserRepository()
    user = repo.get_by_email(session, payload.email)
    if user is None or not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    if not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    token = create_access_token(subject=str(user.id))
    refresh = create_refresh_token(subject=str(user.id))
    return TokenOut(access_token=token, refresh_token=refresh)


@router.get("/auth/me", response_model=UserOut)
def get_me(user=Depends(require_user)):
    return user


@router.post("/auth/refresh", response_model=TokenOut)
def refresh_token(payload: RefreshIn):
    try:
        decoded = decode_token(payload.refresh_token)
    except Exception:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired token")

    if decoded.get("typ") != "refresh":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token type")

    subject = decoded.get("sub")
    if subject is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")

    token = create_access_token(subject=str(subject))
    refresh = create_refresh_token(subject=str(subject))
    return TokenOut(access_token=token, refresh_token=refresh)
