from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel

from app.db.session import get_session
from app.repositories.interest_repo import InterestRepository
from app.services.auth.deps import require_user
from app.services.interests.catalog import INTEREST_GROUPS

router = APIRouter()


class InterestSelectionIn(BaseModel):
    interest_ids: list[int]


async def _get_session(request: Request):
    SessionLocal = request.app.state.SessionLocal
    with get_session(SessionLocal) as session:
        yield session


def _seed_interests(session):
    repo = InterestRepository()
    for group in INTEREST_GROUPS:
        for item in group["items"]:
            repo.upsert_interest(session, group["group"], item["name"], item["keywords"])


@router.get("/interests")
async def list_interests(session=Depends(_get_session)):
    _seed_interests(session)
    repo = InterestRepository()
    rows = repo.list_interests(session)
    return [
        {"id": r.id, "group": r.group_name, "name": r.name, "keywords": r.keywords}
        for r in rows
    ]


@router.post("/interests/selection")
async def select_interests(payload: InterestSelectionIn, session=Depends(_get_session), user=Depends(require_user)):
    if len(payload.interest_ids) < 5 or len(payload.interest_ids) > 10:
        raise HTTPException(status_code=400, detail="select between 5 and 10 interests")
    _seed_interests(session)
    repo = InterestRepository()
    repo.set_user_interests(session, user.id, payload.interest_ids)
    return {"status": "ok", "count": len(payload.interest_ids)}


@router.get("/interests/me")
async def get_my_interests(session=Depends(_get_session), user=Depends(require_user)):
    repo = InterestRepository()
    ids = repo.get_user_interest_ids(session, user.id)
    all_interests = repo.list_interests(session)
    selected = [
        {"id": r.id, "group": r.group_name, "name": r.name, "keywords": r.keywords}
        for r in all_interests if r.id in ids
    ]
    return {"interest_ids": ids, "selected": selected}
