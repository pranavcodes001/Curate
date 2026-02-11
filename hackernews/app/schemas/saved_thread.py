from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel


class SavedThreadCreate(BaseModel):
    story_hn_id: int
    comment_hn_ids: List[int] = []


class SavedThreadQueueOut(BaseModel):
    status: str
    story_hn_id: int
    comment_count: int


class SavedThreadItemOut(BaseModel):
    item_type: str
    hn_id: int
    raw_text: Optional[str]
    ai_summary: Optional[dict]
    model_name: Optional[str]
    model_version: str
    created_at: datetime

    class Config:
        from_attributes = True


class SavedThreadOut(BaseModel):
    id: int
    story_hn_id: int
    title: Optional[str]
    url: Optional[str]
    created_at: datetime
    items: List[SavedThreadItemOut] = []

    class Config:
        from_attributes = True
