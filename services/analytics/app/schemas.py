"""Pydantic v2 schemas for analytics service responses."""

from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel


class ProgressDataPoint(BaseModel):
    """A single data point for exercise weight progression."""

    date: datetime
    max_weight_kg: float
    total_volume_kg: float
    total_sets: int
    total_reps: int


class ProgressResponse(BaseModel):
    """Response for exercise progress over time."""

    exercise_id: uuid.UUID | None
    exercise_name: str
    data_points: list[ProgressDataPoint]


class VolumeDataPoint(BaseModel):
    """A single data point for volume analytics."""

    period: str
    total_volume_kg: float
    total_sets: int
    total_reps: int
    session_count: int


class VolumeResponse(BaseModel):
    """Response for training volume over time."""

    data_points: list[VolumeDataPoint]
    group_by: str


class AdherenceResponse(BaseModel):
    """Response for workout plan adherence."""

    planned_days: int
    completed_sessions: int
    adherence_rate: float
    from_date: datetime
    to_date: datetime


class SummaryResponse(BaseModel):
    """Response for overall training summary."""

    total_sessions: int
    total_duration_minutes: int
    total_volume_kg: float
    current_streak: int
    longest_streak: int
    favorite_exercise: str | None
    sessions_this_week: int
    sessions_this_month: int
