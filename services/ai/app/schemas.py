"""Pydantic v2 schemas for AI service request/response validation."""

from __future__ import annotations

from pydantic import BaseModel, Field


class VisionScanResponse(BaseModel):
    """Response for an AI vision scan job submission."""

    job_id: str
    status: str = "pending"
    message: str = "Vision scan job submitted. Poll GET /ai/jobs/{job_id} for results."


class CoachGenerateResponse(BaseModel):
    """Response for an AI coach generation job submission."""

    job_id: str
    status: str = "pending"
    message: str = "Coach generation job submitted. Poll GET /ai/jobs/{job_id} for results."


class JobStatusResponse(BaseModel):
    """Response for job status polling."""

    job_id: str
    job_type: str
    status: str
    created_at: str | None = None
    updated_at: str | None = None
    result: dict | None = None
    error: str | None = None


class VisionResult(BaseModel):
    """Result of a vision scan: equipment identified and suggested exercises."""

    equipment_name: str
    brand: str | None = None
    exercises: list[dict] = Field(default_factory=list)
    confidence: float = Field(ge=0.0, le=1.0)
    cached: bool = False


class CoachResult(BaseModel):
    """Result of a coach generation: personalized workout plan."""

    plan_name: str
    description: str
    days: list[dict] = Field(default_factory=list)
    notes: str | None = None
