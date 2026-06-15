"""Pydantic request/response models for the StudyGuard agents API."""

from typing import List, Optional
from pydantic import BaseModel


class SessionPayload(BaseModel):
    subject: str
    duration_minutes: int
    posture_score: float
    focus_score: float
    dominant_issue: Optional[str] = None   # "TUP" | "TLF" | "TLB" | "TLR" | "TLL"
    posture_alert_count: int = 0
    distraction_count: int = 0
    focus_timeline: List[int] = []          # per-minute focus score
    break_minutes: int = 5


class Exercise(BaseModel):
    name: str
    duration: int                           # seconds
    target_area: str                        # "neck" | "back" | "eyes" | "full_body"
    instructions: str


class PostureAnalysis(BaseModel):
    score: float
    dominant_issue: Optional[str]
    patterns: str


class FocusAnalysis(BaseModel):
    score: float
    deep_focus_minutes: int
    drop_minutes: List[int]


class AnalysisResponse(BaseModel):
    posture: PostureAnalysis
    focus: FocusAnalysis
    exercises: List[Exercise]
    narrative: str
