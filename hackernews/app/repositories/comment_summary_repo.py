from datetime import datetime
from typing import Optional

from sqlalchemy.orm import Session

from app.db.models.comment_summary import CommentSummary
from app.services.ai.schemas import SummaryData


class CommentSummaryRepository:
    def upsert(self, session: Session, comment_hn_id: int, summary: SummaryData, model_version: str, model_name: Optional[str] = None) -> tuple[CommentSummary, bool, bool]:
        now = datetime.utcnow()
        row = (
            session.query(CommentSummary)
            .filter_by(comment_hn_id=comment_hn_id, model_version=model_version)
            .one_or_none()
        )

        if row is None:
            row = CommentSummary(
                comment_hn_id=comment_hn_id,
                model_name=model_name,
                model_version=model_version,
                tldr=summary.tldr,
                key_points=summary.key_points,
                consensus=summary.consensus,
                created_at=now,
                updated_at=now,
            )
            session.add(row)
            session.commit()
            session.refresh(row)
            return row, True, False

        row.model_name = model_name or row.model_name
        row.tldr = summary.tldr
        row.key_points = summary.key_points
        row.consensus = summary.consensus
        row.updated_at = now
        session.commit()
        session.refresh(row)
        return row, False, True

    def fetch_latest(self, session: Session, comment_hn_id: int, model_version: str) -> Optional[CommentSummary]:
        return (
            session.query(CommentSummary)
            .filter_by(comment_hn_id=comment_hn_id, model_version=model_version)
            .one_or_none()
        )
