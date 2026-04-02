"""Analytics API router: progress, volume, adherence, summary."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user_id
from app.schemas import (
    AdherenceResponse,
    ProgressDataPoint,
    ProgressResponse,
    SummaryResponse,
    VolumeDataPoint,
    VolumeResponse,
)
from app.service import AnalyticsService

router = APIRouter(prefix="/analytics", tags=["analytics"])


@router.get("/progress", response_model=ProgressResponse)
async def get_progress(
    exercise_name: str = Query(..., min_length=1),
    from_date: datetime | None = Query(None, alias="from"),
    to_date: datetime | None = Query(None, alias="to"),
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> ProgressResponse:
    """Get weight progression for a specific exercise over time.

    Args:
        exercise_name: Name of the exercise to track.
        from_date: Optional start date filter.
        to_date: Optional end date filter.
        user_id: Authenticated user UUID from JWT.
        db: Database session.

    Returns:
        Progress data points for the exercise.
    """
    service = AnalyticsService(db)
    data_points = await service.get_progress(user_id, exercise_name, from_date, to_date)
    return ProgressResponse(
        exercise_id=None,
        exercise_name=exercise_name,
        data_points=[ProgressDataPoint(**dp) for dp in data_points],
    )


@router.get("/volume", response_model=VolumeResponse)
async def get_volume(
    from_date: datetime | None = Query(None, alias="from"),
    to_date: datetime | None = Query(None, alias="to"),
    group_by: str = Query("week", pattern="^(week|month)$"),
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> VolumeResponse:
    """Get training volume grouped by week or month.

    Args:
        from_date: Optional start date filter.
        to_date: Optional end date filter.
        group_by: Grouping period ('week' or 'month').
        user_id: Authenticated user UUID from JWT.
        db: Database session.

    Returns:
        Volume data points grouped by period.
    """
    service = AnalyticsService(db)
    data_points = await service.get_volume(user_id, from_date, to_date, group_by)
    return VolumeResponse(
        data_points=[VolumeDataPoint(**dp) for dp in data_points],
        group_by=group_by,
    )


@router.get("/adherence", response_model=AdherenceResponse)
async def get_adherence(
    from_date: datetime = Query(
        default_factory=lambda: datetime.now(UTC) - timedelta(days=30),
        alias="from",
    ),
    to_date: datetime = Query(
        default_factory=lambda: datetime.now(UTC),
        alias="to",
    ),
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> AdherenceResponse:
    """Get workout plan adherence rate for a date range.

    Args:
        from_date: Start of date range (default: 30 days ago).
        to_date: End of date range (default: now).
        user_id: Authenticated user UUID from JWT.
        db: Database session.

    Returns:
        Adherence statistics including planned vs completed.
    """
    service = AnalyticsService(db)
    data = await service.get_adherence(user_id, from_date, to_date)
    return AdherenceResponse(**data)


@router.get("/summary", response_model=SummaryResponse)
async def get_summary(
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> SummaryResponse:
    """Get overall training summary for the authenticated user.

    Args:
        user_id: Authenticated user UUID from JWT.
        db: Database session.

    Returns:
        Summary with totals, streaks, and favorites.
    """
    service = AnalyticsService(db)
    data = await service.get_summary(user_id)
    return SummaryResponse(**data)
