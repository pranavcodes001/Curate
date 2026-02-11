from pydantic import BaseModel
from typing import Optional


class StoryOut(BaseModel):
    hn_id: int
    title: Optional[str]
    url: Optional[str]
    score: Optional[int]
    time: Optional[int]

    class Config:
        from_attributes = True
