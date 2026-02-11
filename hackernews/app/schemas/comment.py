from typing import Optional
from pydantic import BaseModel


class CommentOut(BaseModel):
    comment_hn_id: int
    story_hn_id: int
    parent_hn_id: Optional[int]
    author: Optional[str]
    time: Optional[int]
    text: Optional[str]

    class Config:
        from_attributes = True
