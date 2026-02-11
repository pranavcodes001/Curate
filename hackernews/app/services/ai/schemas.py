from pydantic import BaseModel
from typing import List


class SummaryData(BaseModel):
    tldr: str
    key_points: List[str]
    consensus: str  # one of: 'positive', 'mixed', 'unclear', 'negative'
