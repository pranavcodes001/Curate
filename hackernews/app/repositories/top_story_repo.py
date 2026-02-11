from datetime import datetime
from typing import List

from sqlalchemy.orm import Session

from app.db.models.top_story import TopStory
from app.db.models.story import Story


class TopStoryRepository:
    def replace_top_stories(self, session: Session, hn_ids: List[int]) -> None:
        session.query(TopStory).delete()
        now = datetime.utcnow()
        for rank, hn_id in enumerate(hn_ids):
            session.add(TopStory(hn_id=int(hn_id), rank=rank, fetched_at=now))
        session.commit()

    def list_top_stories(self, session: Session, limit: int = 50) -> List[Story]:
        return (
            session.query(Story)
            .join(TopStory, Story.hn_id == TopStory.hn_id)
            .order_by(TopStory.rank.asc())
            .limit(limit)
            .all()
        )

    def list_top_story_ids(self, session: Session, limit: int = 50) -> List[int]:
        rows = (
            session.query(TopStory.hn_id)
            .order_by(TopStory.rank.asc())
            .limit(limit)
            .all()
        )
        return [r[0] for r in rows]
