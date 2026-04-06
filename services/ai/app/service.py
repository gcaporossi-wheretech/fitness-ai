"""AI service business logic: vision scan processing and persistence.

Orchestrates Claude API calls, caching, credit deduction, rate limiting,
and database persistence. Photos are never saved to disk (ADR-003).
"""

from __future__ import annotations

import logging
import uuid
from typing import Any

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.claude_client import (
    ClaudeAPIError,
    analyze_equipment_image,
    generate_workout_plan,
)
from app.models import AICoachGeneration, AIVisionScan
from app.redis_client import (
    cache_vision_result,
    compute_image_hash,
    get_cached_vision_result,
)

logger = logging.getLogger(__name__)

# Credit costs
VISION_SCAN_CREDITS = 1
COACH_GENERATE_CREDITS = 5

# Auth service URL for credit deduction
AUTH_SERVICE_URL = "http://auth:8001"


class AIServiceError(Exception):
    """Base exception for AI service errors."""

    def __init__(self, message: str, code: str = "AI_ERROR") -> None:
        self.message = message
        self.code = code
        super().__init__(message)


class InsufficientCreditsError(AIServiceError):
    """Raised when user does not have enough credits."""

    def __init__(self) -> None:
        super().__init__("Insufficient AI credits", "INSUFFICIENT_CREDITS")


async def _deduct_credits(user_id: str, amount: int, token: str) -> bool:
    """Deduct AI credits by calling the auth service.

    Args:
        user_id: User UUID string.
        amount: Number of credits to deduct.
        token: JWT token for authentication.

    Returns:
        True if credits were successfully deducted.

    Raises:
        InsufficientCreditsError: If user doesn't have enough credits.
        AIServiceError: If auth service call fails.
    """
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            # First check balance
            check_resp = await client.get(
                f"{AUTH_SERVICE_URL}/auth/credits",
                headers={"Authorization": f"Bearer {token}"},
            )
            if check_resp.status_code != 200:
                raise AIServiceError(
                    "Failed to check credits balance",
                    "CREDITS_CHECK_FAILED",
                )

            balance = check_resp.json().get("credits", 0)
            if balance < amount:
                raise InsufficientCreditsError()

            # Deduct credits (one at a time since the endpoint deducts 1)
            for _ in range(amount):
                resp = await client.post(
                    f"{AUTH_SERVICE_URL}/auth/credits/deduct",
                    headers={"Authorization": f"Bearer {token}"},
                )
                if resp.status_code == 402:
                    raise InsufficientCreditsError()
                if resp.status_code != 200:
                    raise AIServiceError(
                        f"Failed to deduct credit: {resp.status_code}",
                        "CREDIT_DEDUCTION_FAILED",
                    )

    except httpx.HTTPError as exc:
        logger.error("Auth service communication error: %s", exc)
        raise AIServiceError(
            "Cannot reach auth service for credit check",
            "AUTH_SERVICE_UNAVAILABLE",
        ) from exc

    return True


async def process_vision_scan(
    image_data: bytes,
    content_type: str,
    user_id: str,
    token: str,
    db: AsyncSession,
) -> dict[str, Any]:
    """Process a vision scan: call Claude API, cache result, save to DB.

    Args:
        image_data: Raw image bytes (processed in memory only).
        content_type: Image MIME type.
        user_id: User UUID string.
        token: JWT token for credit deduction.
        db: Database session.

    Returns:
        Vision scan result dict.

    Raises:
        InsufficientCreditsError: If user lacks credits.
        AIServiceError: If processing fails.
    """
    image_hash = compute_image_hash(image_data)

    # Check cache first (no credit cost for cached results)
    cached = await get_cached_vision_result(image_hash)
    if cached:
        logger.info("Vision scan cache hit: hash=%s user=%s", image_hash[:16], user_id)
        # Save to DB even for cached results (for history)
        scan = AIVisionScan(
            user_id=uuid.UUID(user_id),
            image_hash=image_hash,
            equipment_name=cached.get("equipment_name"),
            equipment_brand=cached.get("brand"),
            exercises=cached.get("exercises"),
            raw_response=cached,
            credits_used=0,  # No credit cost for cached
        )
        db.add(scan)
        await db.commit()
        cached["cached"] = True
        cached["scan_id"] = str(scan.id)
        return cached

    # Deduct credits before calling API
    await _deduct_credits(user_id, VISION_SCAN_CREDITS, token)

    # Call Claude API
    try:
        result = await analyze_equipment_image(image_data, content_type)
    except ClaudeAPIError as exc:
        # Save failed scan to DB
        scan = AIVisionScan(
            user_id=uuid.UUID(user_id),
            image_hash=image_hash,
            credits_used=VISION_SCAN_CREDITS,
            error=str(exc),
        )
        db.add(scan)
        await db.commit()
        raise AIServiceError(f"Vision scan failed: {exc.message}") from exc

    # Cache the result
    await cache_vision_result(image_hash, result)

    # Save to DB
    scan = AIVisionScan(
        user_id=uuid.UUID(user_id),
        image_hash=image_hash,
        equipment_name=result.get("equipment_name"),
        equipment_brand=result.get("brand"),
        exercises=result.get("exercises"),
        raw_response=result,
        credits_used=VISION_SCAN_CREDITS,
    )
    db.add(scan)
    await db.commit()

    result["cached"] = False
    result["scan_id"] = str(scan.id)
    return result


async def process_coach_generate(
    photos_data: list[tuple[bytes, str]],
    user_data: dict,
    user_id: str,
    token: str,
    db: AsyncSession,
) -> dict[str, Any]:
    """Process a coach generation: call Claude API, save to DB.

    Args:
        photos_data: List of (image_bytes, content_type) tuples.
        user_data: User profile data (age, goals, limitations, etc.).
        user_id: User UUID string.
        token: JWT token for credit deduction.
        db: Database session.

    Returns:
        Generated workout plan result dict.

    Raises:
        InsufficientCreditsError: If user lacks credits.
        AIServiceError: If processing fails.
    """
    # Deduct credits before calling API
    await _deduct_credits(user_id, COACH_GENERATE_CREDITS, token)

    # Call Claude API
    try:
        result = await generate_workout_plan(photos_data, user_data)
    except ClaudeAPIError as exc:
        # Save failed generation to DB
        generation = AICoachGeneration(
            user_id=uuid.UUID(user_id),
            input_data=user_data,
            photo_count=len(photos_data),
            credits_used=COACH_GENERATE_CREDITS,
            error=str(exc),
        )
        db.add(generation)
        await db.commit()
        raise AIServiceError(f"Coach generation failed: {exc.message}") from exc

    # Save to DB
    generation = AICoachGeneration(
        user_id=uuid.UUID(user_id),
        input_data=user_data,
        photo_count=len(photos_data),
        generated_plan=result,
        raw_response=result,
        credits_used=COACH_GENERATE_CREDITS,
    )
    db.add(generation)
    await db.commit()

    result["generation_id"] = str(generation.id)
    return result


async def get_vision_history(
    user_id: str,
    db: AsyncSession,
    page: int = 1,
    per_page: int = 20,
) -> dict[str, Any]:
    """Get vision scan history for a user.

    Args:
        user_id: User UUID string.
        db: Database session.
        page: Page number (1-based).
        per_page: Items per page.

    Returns:
        Paginated list of vision scan results.
    """
    uid = uuid.UUID(user_id)

    # Count total
    from sqlalchemy import func

    count_q = select(func.count()).select_from(AIVisionScan).where(AIVisionScan.user_id == uid)
    total_result = await db.execute(count_q)
    total = total_result.scalar() or 0

    # Fetch page
    offset = (page - 1) * per_page
    query = (
        select(AIVisionScan)
        .where(AIVisionScan.user_id == uid)
        .order_by(AIVisionScan.created_at.desc())
        .offset(offset)
        .limit(per_page)
    )
    result = await db.execute(query)
    scans = result.scalars().all()

    items = []
    for scan in scans:
        items.append(
            {
                "id": str(scan.id),
                "image_hash": scan.image_hash,
                "equipment_name": scan.equipment_name,
                "equipment_brand": scan.equipment_brand,
                "exercises": scan.exercises,
                "credits_used": scan.credits_used,
                "error": scan.error,
                "created_at": scan.created_at.isoformat() if scan.created_at else None,
            }
        )

    pages = (total + per_page - 1) // per_page if per_page > 0 else 0
    return {
        "items": items,
        "total": total,
        "page": page,
        "per_page": per_page,
        "pages": pages,
    }


async def get_coach_history(
    user_id: str,
    db: AsyncSession,
    page: int = 1,
    per_page: int = 20,
) -> dict[str, Any]:
    """Get coach generation history for a user.

    Args:
        user_id: User UUID string.
        db: Database session.
        page: Page number (1-based).
        per_page: Items per page.

    Returns:
        Paginated list of coach generation results.
    """
    uid = uuid.UUID(user_id)

    from sqlalchemy import func

    count_q = (
        select(func.count()).select_from(AICoachGeneration).where(AICoachGeneration.user_id == uid)
    )
    total_result = await db.execute(count_q)
    total = total_result.scalar() or 0

    offset = (page - 1) * per_page
    query = (
        select(AICoachGeneration)
        .where(AICoachGeneration.user_id == uid)
        .order_by(AICoachGeneration.created_at.desc())
        .offset(offset)
        .limit(per_page)
    )
    result = await db.execute(query)
    generations = result.scalars().all()

    items = []
    for gen in generations:
        items.append(
            {
                "id": str(gen.id),
                "input_data": gen.input_data,
                "photo_count": gen.photo_count,
                "generated_plan": gen.generated_plan,
                "credits_used": gen.credits_used,
                "error": gen.error,
                "created_at": gen.created_at.isoformat() if gen.created_at else None,
            }
        )

    pages = (total + per_page - 1) // per_page if per_page > 0 else 0
    return {
        "items": items,
        "total": total,
        "page": page,
        "per_page": per_page,
        "pages": pages,
    }
