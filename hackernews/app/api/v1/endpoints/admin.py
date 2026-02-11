from fastapi import APIRouter, Depends, Request
from app.db.session import get_session
from app.services.auth.deps import require_admin

router = APIRouter()


async def _get_session(request: Request):
    SessionLocal = request.app.state.SessionLocal
    with get_session(SessionLocal) as session:
        yield session


@router.get("/admin/health")
def admin_health(_payload=Depends(require_admin)):
    return {"status": "ok"}


@router.get("/admin/users")
def list_users(session=Depends(_get_session), _payload=Depends(require_admin)):
    from app.db.models.user import User
    users = session.query(User).all()
    return [{"id": u.id, "name": u.name, "email": u.email, "created_at": u.created_at} for u in users]
