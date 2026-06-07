"""Pydantic v2 schemas for workouts service request/response validation."""

from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, Field

# ============================================================
# Workout Plans
# ============================================================


class ExerciseInDay(BaseModel):
    """A single exercise entry within a workout day."""

    exercise_id: uuid.UUID | None = None
    exercise_name: str
    sets: int = Field(ge=1, le=20)
    reps: str | None = None
    rest_seconds: int | None = Field(None, ge=0, le=600)
    notes: str | None = None
    exercise_type: str | None = None


class WorkoutDay(BaseModel):
    """A single day within a workout plan."""

    name: str = Field(max_length=100)
    exercises: list[ExerciseInDay]
    warmup: list[str] | None = Field(None, max_length=20)


class CreatePlanRequest(BaseModel):
    """Schema for creating a new workout plan."""

    name: str = Field(min_length=1, max_length=255)
    description: str | None = None
    days: list[WorkoutDay] = Field(min_length=1, max_length=7)
    phases: list[dict] | None = None
    source: str = Field("manual", pattern="^(manual|ai_coach|imported)$")


class UpdatePlanRequest(BaseModel):
    """Schema for partially updating a workout plan."""

    name: str | None = Field(None, min_length=1, max_length=255)
    description: str | None = None
    days: list[WorkoutDay] | None = None
    phases: list[dict] | None = None
    is_active: bool | None = None


class PlanResponse(BaseModel):
    """Schema for workout plan in responses."""

    id: uuid.UUID
    user_id: uuid.UUID
    name: str
    description: str | None
    phases: list[dict] | None
    days: list[dict]
    is_active: bool
    source: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# ============================================================
# Workout Sessions
# ============================================================


class ExerciseSetLog(BaseModel):
    """A single set logged during a workout session."""

    set_number: int = Field(ge=1)
    weight_kg: float | None = Field(None, ge=0)
    reps: int | None = Field(None, ge=0)
    duration_seconds: int | None = Field(None, ge=0)
    rpe: float | None = Field(None, ge=1, le=10)


class ExerciseLog(BaseModel):
    """A logged exercise within a workout session."""

    exercise_id: uuid.UUID | None = None
    exercise_name: str
    sets: list[ExerciseSetLog]
    notes: str | None = None


class CreateSessionRequest(BaseModel):
    """Schema for creating a workout session."""

    plan_id: uuid.UUID | None = None
    day_name: str | None = Field(None, max_length=100)
    started_at: datetime
    completed_at: datetime | None = None
    duration_seconds: int | None = Field(None, ge=0)
    exercises: list[ExerciseLog] = Field(min_length=1)
    notes: str | None = None
    overall_rating: int | None = Field(None, ge=1, le=5)
    fatigue_rating: int | None = Field(None, ge=1, le=5)
    pump_rating: int | None = Field(None, ge=1, le=5)
    client_id: uuid.UUID


class SessionResponse(BaseModel):
    """Schema for workout session in responses."""

    id: uuid.UUID
    user_id: uuid.UUID
    plan_id: uuid.UUID | None
    day_name: str | None
    started_at: datetime
    completed_at: datetime | None
    duration_seconds: int | None
    exercises: list[dict]
    notes: str | None
    overall_rating: int | None
    fatigue_rating: int | None
    pump_rating: int | None
    synced_at: datetime | None
    client_id: uuid.UUID
    created_at: datetime

    model_config = {"from_attributes": True}


# ============================================================
# Sync
# ============================================================


class SyncSessionItem(BaseModel):
    """A single session in a sync batch from the mobile client."""

    plan_id: uuid.UUID | None = None
    day_name: str | None = Field(None, max_length=100)
    started_at: datetime
    completed_at: datetime | None = None
    duration_seconds: int | None = Field(None, ge=0)
    exercises: list[ExerciseLog] = Field(min_length=1)
    notes: str | None = None
    overall_rating: int | None = Field(None, ge=1, le=5)
    fatigue_rating: int | None = Field(None, ge=1, le=5)
    pump_rating: int | None = Field(None, ge=1, le=5)
    client_id: uuid.UUID


class SyncRequest(BaseModel):
    """Schema for offline sync batch request."""

    sessions: list[SyncSessionItem] = Field(min_length=1, max_length=50)


class SyncResultItem(BaseModel):
    """Result for a single synced session."""

    client_id: uuid.UUID
    status: str  # "created", "duplicate", "error"
    server_id: uuid.UUID | None = None
    error: str | None = None


class SyncResponse(BaseModel):
    """Schema for sync batch response."""

    results: list[SyncResultItem]


# ============================================================
# Exercises
# ============================================================


class ExerciseResponse(BaseModel):
    """Schema for exercise reference data."""

    id: uuid.UUID
    name: str
    name_en: str | None
    muscle_groups: list[str] | None
    equipment: str | None
    exercise_type: str
    description: str | None
    description_en: str | None
    is_custom: bool

    model_config = {"from_attributes": True}


# ============================================================
# Pagination
# ============================================================


class PaginatedResponse(BaseModel):
    """Generic paginated response wrapper."""

    items: list
    total: int
    page: int
    per_page: int
    pages: int
