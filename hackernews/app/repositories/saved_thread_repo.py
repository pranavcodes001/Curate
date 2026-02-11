from datetime import datetime
from typing import List

from sqlalchemy.orm import Session

from app.db.models.saved_thread import SavedThread
from app.db.models.saved_thread_item import SavedThreadItem


class SavedThreadRepository:
    def create_thread(self, session: Session, user_id: int, story_hn_id: int, title: str | None, url: str | None = None) -> SavedThread:
        row = SavedThread(
            user_id=user_id,
            story_hn_id=story_hn_id,
            title=title,
            url=url,
            created_at=datetime.utcnow(),
        )
        session.add(row)
        session.commit()
        session.refresh(row)
        return row

    def add_item(
        self,
        session: Session,
        saved_thread_id: int,
        item_type: str,
        hn_id: int,
        raw_text: str | None,
        ai_summary: dict | None,
        model_name: str | None,
        model_version: str,
    ) -> SavedThreadItem:
        row = SavedThreadItem(
            saved_thread_id=saved_thread_id,
            item_type=item_type,
            hn_id=hn_id,
            raw_text=raw_text,
            ai_summary=ai_summary,
            model_name=model_name,
            model_version=model_version,
            created_at=datetime.utcnow(),
        )
        session.add(row)
        session.commit()
        session.refresh(row)
        return row

    def list_threads(self, session: Session, user_id: int) -> List[SavedThread]:
        return (
            session.query(SavedThread)
            .filter_by(user_id=user_id)
            .order_by(SavedThread.created_at.desc())
            .all()
        )

    def get_thread(self, session: Session, user_id: int, thread_id: int) -> SavedThread | None:
        return (
            session.query(SavedThread)
            .filter_by(id=thread_id, user_id=user_id)
            .one_or_none()
        )

    def list_items(self, session: Session, saved_thread_id: int) -> List[SavedThreadItem]:
        return (
            session.query(SavedThreadItem)
            .filter_by(saved_thread_id=saved_thread_id)
            .order_by(SavedThreadItem.id.asc())
            .all()
        )
