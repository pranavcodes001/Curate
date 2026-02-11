"""Story repository with idempotent upsert logic."""
from datetime import datetime
import hashlib
import json
from typing import Tuple, List

from sqlalchemy.orm import Session

from app.db.models.story import Story
from app.services.sources.hackernews.fetcher import StoryData


def _compute_content_hash(raw_payload: dict) -> str:
    # Stable JSON serialization for hashing
    s = json.dumps(raw_payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return hashlib.sha256(s.encode("utf-8")).hexdigest()


class StoryRepository:
    """Repository that encapsulates idempotent upsert behavior for stories."""

    def upsert(self, session: Session, data: StoryData) -> Tuple[Story, bool, bool]:
        """Upsert a story by hn_id.

        Returns (story, created, updated) where:
        - created: True when inserted
        - updated: True when content changed and row was updated
        """
        now = datetime.utcnow()
        content_hash = _compute_content_hash(data.raw_payload or {})

        story = session.query(Story).filter_by(hn_id=data.hn_id).one_or_none()
        if story is None:
            story = Story(
                hn_id=data.hn_id,
                title=data.title,
                url=data.url,
                raw_payload=data.raw_payload,
                content_hash=content_hash,
                last_fetched_at=now,
                created_at=now,
                updated_at=now,
            )
            session.add(story)
            session.commit()
            session.refresh(story)
            return story, True, False

        # existing row
        if (story.content_hash or None) != content_hash:
            # content changed -> update content fields and updated_at
            story.title = data.title
            story.url = data.url
            story.raw_payload = data.raw_payload
            story.content_hash = content_hash
            story.last_fetched_at = now
            story.updated_at = now
            session.commit()
            session.refresh(story)
            return story, False, True

        # content identical -> do NOT update content fields; only record fetch time
        story.last_fetched_at = now
        session.commit()
        session.refresh(story)
        return story, False, False

    def fetch_latest(self, session: Session, limit: int = 50) -> List[Story]:
        return (
            session.query(Story)
            .order_by(Story.last_fetched_at.desc().nullslast(), Story.created_at.desc())
            .limit(limit)
            .all()
        )

    def list_top_stories(self, session: Session, limit: int = 50) -> List[Story]:
        # Fallback for cache usage when top_stories table is not available.
        return self.fetch_latest(session, limit=limit)

    def get_by_hn_id(self, session: Session, hn_id: int) -> Story | None:
        return session.query(Story).filter_by(hn_id=hn_id).one_or_none()

    def fetch_latest_ids(self, session: Session, limit: int = 20) -> List[int]:
        rows = (
            session.query(Story.hn_id)
            .order_by(Story.last_fetched_at.desc().nullslast(), Story.created_at.desc())
            .limit(limit)
            .all()
        )
        return [r[0] for r in rows]
