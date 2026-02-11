from datetime import datetime
from typing import Iterable

from sqlalchemy.orm import Session

from app.db.models.user_story_state import UserStoryState


class UserStoryStateRepository:
    def get_state_map(self, session: Session, user_id: int, hn_ids: Iterable[int]) -> dict[int, UserStoryState]:
        ids = list({int(i) for i in hn_ids})
        if not ids:
            return {}
        rows = (
            session.query(UserStoryState)
            .filter(UserStoryState.user_id == user_id, UserStoryState.story_hn_id.in_(ids))
            .all()
        )
        return {r.story_hn_id: r for r in rows}

    def mark_seen(self, session: Session, user_id: int, hn_ids: Iterable[int]) -> int:
        ids = list({int(i) for i in hn_ids})
        if not ids:
            return 0
        now = datetime.utcnow()
        count = 0
        for hn_id in ids:
            row = (
                session.query(UserStoryState)
                .filter_by(user_id=user_id, story_hn_id=hn_id)
                .one_or_none()
            )
            if row is None:
                session.add(
                    UserStoryState(
                        user_id=user_id,
                        story_hn_id=hn_id,
                        last_seen_at=now,
                        read_count=0,
                    )
                )
            else:
                row.last_seen_at = now
            count += 1
        session.commit()
        return count

    def mark_read(self, session: Session, user_id: int, hn_id: int) -> UserStoryState:
        now = datetime.utcnow()
        row = (
            session.query(UserStoryState)
            .filter_by(user_id=user_id, story_hn_id=int(hn_id))
            .one_or_none()
        )
        if row is None:
            row = UserStoryState(
                user_id=user_id,
                story_hn_id=int(hn_id),
                last_seen_at=now,
                last_read_at=now,
                read_count=1,
            )
            session.add(row)
            session.commit()
            session.refresh(row)
            return row

        row.read_count = (row.read_count or 0) + 1
        row.last_read_at = now
        row.last_seen_at = now
        session.commit()
        session.refresh(row)
        return row

    def mark_dismissed(self, session: Session, user_id: int, hn_ids: Iterable[int]) -> int:
        ids = list({int(i) for i in hn_ids})
        if not ids:
            return 0
        now = datetime.utcnow()
        count = 0
        for hn_id in ids:
            row = (
                session.query(UserStoryState)
                .filter_by(user_id=user_id, story_hn_id=hn_id)
                .one_or_none()
            )
            if row is None:
                session.add(
                    UserStoryState(
                        user_id=user_id,
                        story_hn_id=hn_id,
                        last_seen_at=now,
                        dismissed_at=now,
                        read_count=0,
                    )
                )
            else:
                row.dismissed_at = now
            count += 1
        session.commit()
        return count
