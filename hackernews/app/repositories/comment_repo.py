from datetime import datetime
from typing import List

from sqlalchemy.orm import Session

from app.db.models.comment import Comment


class CommentRepository:
    def get_by_hn_id(self, session: Session, comment_hn_id: int) -> Comment | None:
        return session.query(Comment).filter_by(comment_hn_id=comment_hn_id).one_or_none()

    def upsert(self, session: Session, story_hn_id: int, raw: dict) -> tuple[Comment, bool, bool]:
        now = datetime.utcnow()
        comment_hn_id = raw.get("id")
        if comment_hn_id is None:
            raise ValueError("comment id missing")

        row = session.query(Comment).filter_by(comment_hn_id=comment_hn_id).one_or_none()
        text = raw.get("text")
        author = raw.get("by")
        time_val = raw.get("time")
        parent = raw.get("parent")

        if row is None:
            row = Comment(
                comment_hn_id=comment_hn_id,
                story_hn_id=story_hn_id,
                parent_hn_id=parent,
                author=author,
                time=time_val,
                text=text,
                raw_payload=raw,
                created_at=now,
                updated_at=now,
            )
            session.add(row)
            session.commit()
            session.refresh(row)
            return row, True, False

        # Update fields if changed
        changed = False
        if row.text != text:
            row.text = text
            changed = True
        if row.author != author:
            row.author = author
            changed = True
        if row.time != time_val:
            row.time = time_val
            changed = True
        if row.parent_hn_id != parent:
            row.parent_hn_id = parent
            changed = True
        if row.story_hn_id != story_hn_id:
            row.story_hn_id = story_hn_id
            changed = True
        if row.raw_payload != raw:
            row.raw_payload = raw
            changed = True

        if changed:
            row.updated_at = now
            session.commit()
            session.refresh(row)
            return row, False, True

        return row, False, False

    def fetch_for_story(self, session: Session, story_hn_id: int, limit: int = 10) -> List[Comment]:
        return (
            session.query(Comment)
            .filter_by(story_hn_id=story_hn_id)
            .order_by(Comment.time.asc().nullslast(), Comment.id.asc())
            .limit(limit)
            .all()
        )
