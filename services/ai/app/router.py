"""AI API router: vision scan, coach generation, job status, history."""

from __future__ import annotations

import json
import logging
import uuid

from fastapi import (
    APIRouter,
    Depends,
    File,
    Form,
    HTTPException,
    Query,
    UploadFile,
    status,
)
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user_id
from app.rate_limiter import (
    RateLimitExceededError,
    check_coach_generate_rate,
    check_vision_scan_rate,
)
from app.redis_client import (
    get_job_status,
)
from app.schemas import (
    CoachGenerateSyncResponse,
    JobStatusResponse,
    PaginatedCoachHistory,
    PaginatedVisionHistory,
    VisionScanSyncResponse,
)
from app.service import (
    AIServiceError,
    InsufficientCreditsError,
    get_coach_history,
    get_vision_history,
    process_coach_generate,
    process_vision_scan,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ai", tags=["ai"])
security_scheme = HTTPBearer()

MAX_IMAGE_SIZE = 10 * 1024 * 1024  # 10 MB
DEFAULT_CONTENT_TYPE = "image/jpeg"
ALLOWED_CONTENT_TYPES = {DEFAULT_CONTENT_TYPE, "image/png"}
MAX_COACH_PHOTOS = 5


def _get_token(
    credentials: HTTPAuthorizationCredentials = Depends(security_scheme),
) -> str:
    """Extract raw JWT token string from authorization header.

    Args:
        credentials: Bearer token from Authorization header.

    Returns:
        Raw JWT token string.
    """
    return credentials.credentials


@router.post("/vision/scan", response_model=VisionScanSyncResponse)
async def vision_scan(
    image: UploadFile = File(...),
    user_id: uuid.UUID = Depends(get_current_user_id),
    token: str = Depends(_get_token),
    db: AsyncSession = Depends(get_db),
) -> VisionScanSyncResponse:
    """Submit an image for AI equipment recognition.

    The image is processed in memory and sent to Claude Vision API.
    Results are cached by image hash (SHA256) for dedup.
    Costs 1 AI credit per scan (free if cached).

    Rate limit: 10 scans per hour.

    Args:
        image: Uploaded image file (JPEG/PNG, max 10MB).
        user_id: Authenticated user UUID from JWT.
        token: Raw JWT token for inter-service calls.
        db: Database session.

    Returns:
        Equipment recognition result with exercises.
    """
    # Validate content type
    if image.content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid image type: {image.content_type}. Allowed: JPEG, PNG.",
        )

    # Read and validate size
    contents = await image.read()
    if len(contents) > MAX_IMAGE_SIZE:
        raise HTTPException(
            status_code=status.HTTP_413_CONTENT_TOO_LARGE,
            detail=f"Image exceeds maximum size of {MAX_IMAGE_SIZE // (1024 * 1024)}MB",
        )

    if len(contents) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Empty image file",
        )

    # Check rate limit
    try:
        await check_vision_scan_rate(str(user_id))
    except RateLimitExceededError as exc:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=str(exc),
        ) from exc

    # Process scan (credit check + Claude API + cache + DB)
    try:
        result = await process_vision_scan(
            image_data=contents,
            content_type=image.content_type or DEFAULT_CONTENT_TYPE,
            user_id=str(user_id),
            token=token,
            db=db,
        )
    except InsufficientCreditsError as exc:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail=exc.message,
        ) from exc
    except AIServiceError as exc:
        logger.error("Vision scan failed: %s", exc.message)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=exc.message,
        ) from exc

    return VisionScanSyncResponse(**result)


@router.get("/vision/history", response_model=PaginatedVisionHistory)
async def vision_history(
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
    page: int = Query(1, ge=1, description="Page number"),
    per_page: int = Query(20, ge=1, le=100, description="Items per page"),
) -> PaginatedVisionHistory:
    """Get vision scan history for the authenticated user.

    Args:
        user_id: Authenticated user UUID from JWT.
        db: Database session.
        page: Page number (1-based).
        per_page: Items per page (max 100).

    Returns:
        Paginated list of vision scan history.
    """
    result = await get_vision_history(str(user_id), db, page, per_page)
    return PaginatedVisionHistory(**result)


@router.post("/coach/generate", response_model=CoachGenerateSyncResponse)
async def coach_generate(
    photos: list[UploadFile] = File(...),
    data: str = Form("{}"),
    user_id: uuid.UUID = Depends(get_current_user_id),
    token: str = Depends(_get_token),
    db: AsyncSession = Depends(get_db),
) -> CoachGenerateSyncResponse:
    """Generate a personalized workout plan from body photos and user data.

    Accepts multiple body photos and a JSON string with user profile data.
    Photos are processed in memory only — never saved (ADR-003).
    Costs 5 AI credits per generation.

    Rate limit: 3 generations per day.

    Args:
        photos: Body photo files (JPEG/PNG, max 10MB each, max 5 photos).
        data: JSON string with user data (age, goals, limitations, etc.).
        user_id: Authenticated user UUID from JWT.
        token: Raw JWT token for inter-service calls.
        db: Database session.

    Returns:
        Generated workout plan with exercises.
    """
    # Validate photo count
    if len(photos) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one photo is required",
        )
    if len(photos) > MAX_COACH_PHOTOS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Maximum {MAX_COACH_PHOTOS} photos allowed",
        )

    # Parse user data JSON
    try:
        user_data = json.loads(data)
    except json.JSONDecodeError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid JSON in data field: {exc}",
        ) from exc

    # Read and validate all photos
    photos_data: list[tuple[bytes, str]] = []
    for photo in photos:
        if photo.content_type not in ALLOWED_CONTENT_TYPES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(f"Invalid photo type: {photo.content_type}. Allowed: JPEG, PNG."),
            )

        contents = await photo.read()
        if len(contents) > MAX_IMAGE_SIZE:
            raise HTTPException(
                status_code=status.HTTP_413_CONTENT_TOO_LARGE,
                detail=(
                    f"Photo {photo.filename} exceeds maximum "
                    f"size of {MAX_IMAGE_SIZE // (1024 * 1024)}MB"
                ),
            )
        if len(contents) == 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Empty photo file: {photo.filename}",
            )
        photos_data.append((contents, photo.content_type or DEFAULT_CONTENT_TYPE))

    # Check rate limit
    try:
        await check_coach_generate_rate(str(user_id))
    except RateLimitExceededError as exc:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=str(exc),
        ) from exc

    # Process (credit check + Claude API + DB)
    try:
        result = await process_coach_generate(
            photos_data=photos_data,
            user_data=user_data,
            user_id=str(user_id),
            token=token,
            db=db,
        )
    except InsufficientCreditsError as exc:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail=exc.message,
        ) from exc
    except AIServiceError as exc:
        logger.error("Coach generation failed: %s", exc.message)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=exc.message,
        ) from exc

    return CoachGenerateSyncResponse(**result)


@router.get("/coach/history", response_model=PaginatedCoachHistory)
async def coach_history(
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
    page: int = Query(1, ge=1, description="Page number"),
    per_page: int = Query(20, ge=1, le=100, description="Items per page"),
) -> PaginatedCoachHistory:
    """Get coach generation history for the authenticated user.

    Args:
        user_id: Authenticated user UUID from JWT.
        db: Database session.
        page: Page number (1-based).
        per_page: Items per page (max 100).

    Returns:
        Paginated list of coach generation history.
    """
    result = await get_coach_history(str(user_id), db, page, per_page)
    return PaginatedCoachHistory(**result)


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
