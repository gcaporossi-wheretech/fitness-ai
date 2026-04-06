"""Pydantic v2 schemas for AI service request/response validation."""

from __future__ import annotations

from pydantic import BaseModel, Field

# ============================================================
# Vision Scan
# ============================================================


class ExerciseInfo(BaseModel):
    """Exercise information from vision scan result."""

    name: str
    name_it: str | None = None
    muscle_groups: list[str] = Field(default_factory=list)
    difficulty: str | None = None
    description: str | None = None


class VisionScanResponse(BaseModel):
    """Response for an AI vision scan submission (async job)."""

    job_id: str
    status: str = "pending"
    message: str = "Vision scan job submitted. Poll GET /ai/jobs/{job_id} for results."


class VisionScanResult(BaseModel):
    """Full result of a completed vision scan."""

    scan_id: str | None = None
    equipment_name: str
    brand: str | None = None
    exercises: list[ExerciseInfo] = Field(default_factory=list)
    confidence: float = Field(ge=0.0, le=1.0)
    cached: bool = False


class VisionScanSyncResponse(BaseModel):
    """Synchronous response for a vision scan (used when result is immediate)."""

    equipment_name: str
    brand: str | None = None
    exercises: list[dict] = Field(default_factory=list)
    confidence: float = Field(ge=0.0, le=1.0)
    cached: bool = False
    scan_id: str | None = None


class VisionHistoryItem(BaseModel):
    """Single item in vision scan history."""

    id: str
    image_hash: str | None = None
    equipment_name: str | None = None
    equipment_brand: str | None = None
    exercises: list[dict] | dict | None = None
    credits_used: int = 0
    error: str | None = None
    created_at: str | None = None


# ============================================================
# Coach Generation
# ============================================================


class CoachGenerateSyncResponse(BaseModel):
    """Synchronous response for coach generation."""

    plan_name: str
    description: str
    duration_weeks: int | None = None
    days_per_week: int | None = None
    level: str | None = None
    days: list[dict] = Field(default_factory=list)
    progression_notes: str | None = None
    nutrition_tips: str | None = None
    generation_id: str | None = None


class CoachHistoryItem(BaseModel):
    """Single item in coach generation history."""

    id: str
    input_data: dict | None = None
    photo_count: int | None = None
    generated_plan: dict | None = None
    credits_used: int = 0
    error: str | None = None
    created_at: str | None = None


# ============================================================
# Job Status
# ============================================================


class JobStatusResponse(BaseModel):
    """Response for job status polling."""

    job_id: str
    job_type: str
    status: str
    created_at: str | None = None
    updated_at: str | None = None
    result: dict | None = None
    error: str | None = None


# ============================================================
# Paginated Responses
# ============================================================


class PaginatedVisionHistory(BaseModel):
    """Paginated list of vision scan history items."""

    items: list[VisionHistoryItem] = Field(default_factory=list)
    total: int = 0
    page: int = 1
    per_page: int = 20
    pages: int = 0


class PaginatedCoachHistory(BaseModel):
    """Paginated list of coach generation history items."""

    items: list[CoachHistoryItem] = Field(default_factory=list)
    total: int = 0
    page: int = 1
    per_page: int = 20
    pages: int = 0
