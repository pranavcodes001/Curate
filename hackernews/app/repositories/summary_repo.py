"""Repository for AI summaries with idempotent upsert behavior."""
from datetime import datetime
import hashlib
import json
from typing import Optional

from sqlalchemy.orm import Session

from app.db.models.ai_summary import AiSummary
from app.services.ai.schemas import SummaryData


def _compute_content_hash(summary: SummaryData) -> str:
    s = json.dumps(summary.dict(), sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return hashlib.sha256(s.encode("utf-8")).hexdigest()


class SummaryRepository:
    def upsert_summary(self, session: Session, story_hn_id: int, summary: SummaryData, model_version: str, model_name: Optional[str] = None) -> tuple[AiSummary, bool, bool]:
        """Insert or update a summary for a story+model_version.

        Returns (summary_row, created, updated)
        """
        now = datetime.utcnow()
        content_hash = _compute_content_hash(summary)

        row = (
            session.query(AiSummary)
            .filter_by(story_hn_id=story_hn_id, model_version=model_version)
            .one_or_none()
        )

        if row is None:
            row = AiSummary(
                story_hn_id=story_hn_id,
                model_name=model_name,
                model_version=model_version,
                content_hash=content_hash,
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

        if (row.content_hash or None) != content_hash:
            row.model_name = model_name or row.model_name
            row.content_hash = content_hash
            row.tldr = summary.tldr
            row.key_points = summary.key_points
            row.consensus = summary.consensus
            row.updated_at = now
            session.commit()
            session.refresh(row)
            return row, False, True

        # identical content: no update
        return row, False, False

    def fetch_latest(self, session: Session, story_hn_id: int, model_version: str) -> Optional[AiSummary]:
        return (
            session.query(AiSummary)
            .filter_by(story_hn_id=story_hn_id, model_version=model_version)
            .one_or_none()
        )
