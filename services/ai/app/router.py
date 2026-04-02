"""AI API router: vision scan, coach generation, job status."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status

from app.dependencies import get_current_user_id
from app.redis_client import (
    compute_image_hash,
    get_cached_vision_result,
    get_job_status,
    publish_job,
)
from app.schemas import (
    CoachGenerateResponse,
    JobStatusResponse,
    VisionScanResponse,
)

router = APIRouter(prefix="/ai", tags=["ai"])

MAX_IMAGE_SIZE = 10 * 1024 * 1024  # 10 MB


@router.post("/vision/scan", response_model=VisionScanResponse)
async def vision_scan(
    image: UploadFile = File(...),
    user_id: uuid.UUID = Depends(get_current_user_id),
) -> VisionScanResponse:
    """Submit an image for AI equipment recognition.

    The image is hashed for dedup caching. If a cached result exists,
    it is returned immediately. Otherwise, a job is published to Redis
    Streams for async processing.

    Args:
        image: Uploaded image file (max 10MB).
        user_id: Authenticated user UUID from JWT.

    Returns:
        Job submission response with job_id for polling.
    """
    # Validate file size
    contents = await image.read()
    if len(contents) > MAX_IMAGE_SIZE:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"Image exceeds maximum size of {MAX_IMAGE_SIZE // (1024 * 1024)}MB",
        )

    # Check cache
    image_hash = compute_image_hash(contents)
    cached = await get_cached_vision_result(image_hash)
    if cached:
        # Return cached result as a completed job
        job_id = await publish_job(
            job_type="vision_scan",
            user_id=str(user_id),
            payload={"image_hash": image_hash, "cached": True},
        )
        from app.redis_client import update_job_status

        await update_job_status(job_id, "completed", result=cached)
        return VisionScanResponse(
            job_id=job_id,
            status="completed",
            message="Result found in cache. Check GET /ai/jobs/{job_id}.",
        )

    # Publish async job
    job_id = await publish_job(
        job_type="vision_scan",
        user_id=str(user_id),
        payload={
            "image_hash": image_hash,
            "content_type": image.content_type or "image/jpeg",
            "filename": image.filename or "scan.jpg",
        },
    )

    return VisionScanResponse(job_id=job_id)


@router.post("/coach/generate", response_model=CoachGenerateResponse)
async def coach_generate(
    user_id: uuid.UUID = Depends(get_current_user_id),
) -> CoachGenerateResponse:
    """Submit a request for AI-generated personalized workout plan.

    Args:
        user_id: Authenticated user UUID from JWT.

    Returns:
        Job submission response with job_id for polling.
    """
    job_id = await publish_job(
        job_type="coach_generate",
        user_id=str(user_id),
        payload={"user_id": str(user_id)},
    )

    return CoachGenerateResponse(job_id=job_id)


@router.get("/jobs/{job_id}", response_model=JobStatusResponse)
async def get_job(
    job_id: str,
    user_id: uuid.UUID = Depends(get_current_user_id),
) -> JobStatusResponse:
    """Poll the status of an AI job.

    Args:
        job_id: Job UUID string.
        user_id: Authenticated user UUID from JWT.

    Returns:
        Current job status with result if completed.
    """
    data = await get_job_status(job_id)
    if not data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Job not found or expired",
        )

    # Verify job belongs to this user
    if data.get("user_id") != str(user_id):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Job not found",
        )

    return JobStatusResponse(
        job_id=data.get("job_id", job_id),
        job_type=data.get("job_type", "unknown"),
        status=data.get("status", "unknown"),
        created_at=data.get("created_at"),
        updated_at=data.get("updated_at"),
        result=data.get("result") if isinstance(data.get("result"), dict) else None,
        error=data.get("error"),
    )
