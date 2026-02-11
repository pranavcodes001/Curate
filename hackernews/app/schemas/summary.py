from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel


class SummaryOut(BaseModel):
    hn_id: int
    model_version: str
    tldr: Optional[str] = None
    key_points: Optional[List[str]] = None
    consensus: Optional[str] = None
    model_name: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
