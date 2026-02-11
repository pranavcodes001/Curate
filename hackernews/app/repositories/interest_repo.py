from datetime import datetime
from typing import List, Dict

from sqlalchemy.orm import Session

from app.db.models.interest import Interest
from app.db.models.user_interest import UserInterest
from app.db.models.interest_story import InterestStory
from datetime import datetime


class InterestRepository:
    def upsert_interest(self, session: Session, group: str, name: str, keywords: List[str]) -> Interest:
        row = session.query(Interest).filter_by(group_name=group, name=name).one_or_none()
        if row is None:
            row = Interest(group_name=group, name=name, keywords=keywords)
            session.add(row)
            session.commit()
            session.refresh(row)
            return row
        row.keywords = keywords
        session.commit()
        session.refresh(row)
        return row

    def list_interests(self, session: Session) -> List[Interest]:
        return session.query(Interest).order_by(Interest.group_name.asc(), Interest.name.asc()).all()

    def get_by_id(self, session: Session, interest_id: int) -> Interest | None:
        return session.query(Interest).filter_by(id=interest_id).one_or_none()

    def set_user_interests(self, session: Session, user_id: int, interest_ids: List[int]) -> None:
        session.query(UserInterest).filter_by(user_id=user_id).delete()
        session.commit()
        for iid in interest_ids:
            session.add(UserInterest(user_id=user_id, interest_id=iid))
        session.commit()

    def get_user_interest_ids(self, session: Session, user_id: int) -> List[int]:
        rows = session.query(UserInterest.interest_id).filter_by(user_id=user_id).all()
        return [r[0] for r in rows]

    def upsert_interest_story(
        self,
        session: Session,
        interest_id: int,
        story_hn_id: int,
        points: int | None,
        time: int | None,
    ) -> InterestStory:
        row = session.query(InterestStory).filter_by(interest_id=interest_id, story_hn_id=story_hn_id).one_or_none()
        now = datetime.utcnow()
        if row is None:
            row = InterestStory(
                interest_id=interest_id,
                story_hn_id=story_hn_id,
                points=points,
                time=time,
                read_count=0,
                last_seen_at=now,
            )
            session.add(row)
            session.commit()
            session.refresh(row)
            return row
        row.points = points or row.points
        row.time = time or row.time
        row.last_seen_at = now
        session.commit()
        session.refresh(row)
        return row

    def list_interest_stories(self, session: Session, interest_id: int) -> List[InterestStory]:
        return session.query(InterestStory).filter_by(interest_id=interest_id).all()

    def delete_interest_story_not_in(self, session: Session, interest_id: int, keep_story_ids: List[int]) -> None:
        if not keep_story_ids:
            return
        session.query(InterestStory).filter(
            InterestStory.interest_id == interest_id,
            ~InterestStory.story_hn_id.in_(keep_story_ids),
        ).delete(synchronize_session=False)
        session.commit()

    def increment_story_reads(self, session: Session, story_hn_id: int) -> int:
        rows = session.query(InterestStory).filter_by(story_hn_id=story_hn_id).all()
        count = 0
        for row in rows:
            row.read_count = (row.read_count or 0) + 1
            count += 1
        session.commit()
        return count

    def increment_interest_reads_for_story(self, session: Session, story_hn_id: int) -> int:
        rows = session.query(InterestStory).filter_by(story_hn_id=story_hn_id).all()
        interest_ids = list({r.interest_id for r in rows})
        if not interest_ids:
            return 0
        now = datetime.utcnow()
        interests = session.query(Interest).filter(Interest.id.in_(interest_ids)).all()
        for interest in interests:
            interest.read_count = (interest.read_count or 0) + 1
            interest.last_read_at = now
        session.commit()
        return len(interests)

    def get_max_hn_id(self, session: Session, interest_id: int) -> int:
        """Get the highest HN ID currently in the library for this interest."""
        from sqlalchemy import func
        res = session.query(func.max(InterestStory.story_hn_id)).filter_by(interest_id=interest_id).scalar()
        return res or 0

    def rotate_shelf(self, session: Session, interest_id: int, max_size: int = 50) -> int:
        """Hard cap the interest shelf. Delete oldest/most-read stories if above max_size."""
        total = session.query(InterestStory).filter_by(interest_id=interest_id).count()
        if total <= max_size:
            return 0
        
        # Find IDs to keep (Top 50 by points/time/read_count)
        # Note: We prioritize UNREAD or HIGH POINTS stories.
        # But for strictly 1.0M scale readiness, we'll just keep the top 50 by HN ID (newest).
        keep_ids_query = (
            session.query(InterestStory.story_hn_id)
            .filter_by(interest_id=interest_id)
            .order_by(InterestStory.story_hn_id.desc())
            .limit(max_size)
        )
        keep_ids = [r[0] for r in keep_ids_query.all()]
        
        deleted = (
            session.query(InterestStory)
            .filter(InterestStory.interest_id == interest_id, ~InterestStory.story_hn_id.in_(keep_ids))
            .delete(synchronize_session=False)
        )
        session.commit()
        return deleted

    def get_unread_count_for_user(self, session: Session, user_id: int, interest_id: int) -> int:
        """Calculate how many stories in the shelf are unread by THIS user."""
        from app.db.models.user_story_state import UserStoryState
        from sqlalchemy import exists, and_
        
        # Stories in interest shelf
        shelf_query = session.query(InterestStory.story_hn_id).filter_by(interest_id=interest_id)
        
        # Count where those IDs do NOT exist in UserStoryState with read_count > 0
        unread = (
            session.query(InterestStory)
            .filter(InterestStory.interest_id == interest_id)
            .filter(~exists().where(and_(
                UserStoryState.user_id == user_id,
                UserStoryState.story_hn_id == InterestStory.story_hn_id,
                UserStoryState.read_count > 0
            )))
            .count()
        )
        return unread

    def get_global_read_ratio(self, session: Session, interest_id: int) -> float:
        """Calculate the ratio of stories in this shelf that have been read by ANYONE."""
        total = session.query(InterestStory).filter_by(interest_id=interest_id).count()
        if total == 0:
            return 0.0
        read_count = (
            session.query(InterestStory)
            .filter(InterestStory.interest_id == interest_id, InterestStory.read_count > 0)
            .count()
        )
        return read_count / total
