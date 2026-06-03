"""Workouts API router: plans CRUD, sessions, exercises, sync."""

from __future__ import annotations

import math
import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user_id
from app.schemas import (
    CreatePlanRequest,
    CreateSessionRequest,
    ExerciseResponse,
    PaginatedResponse,
    PlanResponse,
    SessionResponse,
    SyncRequest,
    SyncResponse,
    SyncResultItem,
    UpdatePlanRequest,
)
from app.service import (
    DuplicateClientIdError,
    PlanNotFoundError,
    WorkoutService,
)

router = APIRouter(prefix="/workouts", tags=["workouts"])


# ============================================================
# Workout Plans
# ============================================================


@router.get("/plans", response_model=PaginatedResponse)
async def list_plans(
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> PaginatedResponse:
    """List all workout plans for the authenticated user.

    Args:
        page: Page number (1-based).
        per_page: Items per page (max 100).
        user_id: Authenticated user UUID from JWT.
        db: Database session.

    Returns:
        Paginated list of workout plans.
    """
    service = WorkoutService(db)
    plans, total = await service.list_plans(user_id, page, per_page)
    return PaginatedResponse(
        items=[PlanResponse.model_validate(p) for p in plans],
        total=total,
        page=page,
        per_page=per_page,
        pages=max(1, math.ceil(total / per_page)),
    )


@router.post("/plans", response_model=PlanResponse, status_code=status.HTTP_201_CREATED)
async def create_plan(
    request: CreatePlanRequest,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> PlanResponse:
    """Create a new workout plan.

    Args:
        request: Plan data.
        user_id: Authenticated user UUID from JWT.
        db: Database session.

    Returns:
        Created workout plan.
    """
    service = WorkoutService(db)
    plan = await service.create_plan(
        user_id=user_id,
        name=request.name,
        days=[day.model_dump() for day in request.days],
        description=request.description,
        phases=request.phases,
        source=request.source,
    )
    return PlanResponse.model_validate(plan)


@router.get("/plans/{plan_id}", response_model=PlanResponse)
async def get_plan(
    plan_id: uuid.UUID,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> PlanResponse:
    """Get a specific workout plan by ID.

    Args:
        plan_id: Plan UUID.
        user_id: Authenticated user UUID from JWT.
        db: Database session.

    Returns:
        Workout plan details.
    """
    service = WorkoutService(db)
    try:
        plan = await service.get_plan(plan_id, user_id)
    except PlanNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=exc.message) from exc
    return PlanResponse.model_validate(plan)


@router.patch("/plans/{plan_id}", response_model=PlanResponse)
async def update_plan(
    plan_id: uuid.UUID,
    request: UpdatePlanRequest,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> PlanResponse:
    """Update a workout plan's fields.

    Args:
        plan_id: Plan UUID.
        request: Fields to update.
        user_id: Authenticated user UUID from JWT.
        db: Database session.

    Returns:
        Updated workout plan.
    """
    service = WorkoutService(db)
    update_data = request.model_dump(exclude_unset=True)
    if "days" in update_data and update_data["days"] is not None:
        update_data["days"] = [
            day.model_dump() if hasattr(day, "model_dump") else day for day in update_data["days"]
        ]
    try:
        plan = await service.update_plan(plan_id, user_id, **update_data)
    except PlanNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=exc.message) from exc
    return PlanResponse.model_validate(plan)


@router.delete("/plans/{plan_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_plan(
    plan_id: uuid.UUID,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> None:
    """Delete a workout plan.

    Args:
        plan_id: Plan UUID.
        user_id: Authenticated user UUID from JWT.
        db: Database session.
    """
    service = WorkoutService(db)
    try:
        await service.delete_plan(plan_id, user_id)
    except PlanNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=exc.message) from exc


# ============================================================
# Workout Sessions
# ============================================================


@router.get("/sessions", response_model=PaginatedResponse)
async def list_sessions(
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    from_date: datetime | None = Query(None, alias="from"),
    to_date: datetime | None = Query(None, alias="to"),
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> PaginatedResponse:
    """List workout sessions with optional date filtering.

    Args:
        page: Page number.
        per_page: Items per page.
        from_date: Optional start date filter.
        to_date: Optional end date filter.
        user_id: Authenticated user UUID from JWT.
        db: Database session.

    Returns:
        Paginated list of workout sessions.
    """
    service = WorkoutService(db)
    sessions, total = await service.list_sessions(user_id, page, per_page, from_date, to_date)
    return PaginatedResponse(
        items=[SessionResponse.model_validate(s) for s in sessions],
        total=total,
        page=page,
        per_page=per_page,
        pages=max(1, math.ceil(total / per_page)),
    )


@router.post("/sessions", response_model=SessionResponse, status_code=status.HTTP_201_CREATED)
async def create_session(
    request: CreateSessionRequest,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> SessionResponse:
    """Record a new workout session.

    Args:
        request: Session data with exercises logged.
        user_id: Authenticated user UUID from JWT.
        db: Database session.

    Returns:
        Created workout session.
    """
    service = WorkoutService(db)
    try:
        session = await service.create_session(
            user_id=user_id,
            client_id=request.client_id,
            started_at=request.started_at,
            exercises=[ex.model_dump() for ex in request.exercises],
            plan_id=request.plan_id,
            day_name=request.day_name,
            completed_at=request.completed_at,
            duration_seconds=request.duration_seconds,
            notes=request.notes,
            overall_rating=request.overall_rating,
            fatigue_rating=request.fatigue_rating,
            pump_rating=request.pump_rating,
        )
    except DuplicateClientIdError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=exc.message) from exc
    return SessionResponse.model_validate(session)


# ============================================================
# Sync
# ============================================================


@router.post("/sync", response_model=SyncResponse)
async def sync_sessions(
    request: SyncRequest,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> SyncResponse:
    """Sync a batch of offline sessions from the mobile client.

    Each session is processed independently: duplicates are reported,
    errors do not fail the entire batch.

    Args:
        request: Batch of sessions to sync.
        user_id: Authenticated user UUID from JWT.
        db: Database session.

    Returns:
        Sync results for each session.
    """
    service = WorkoutService(db)
    sessions_data = [
        {
            "plan_id": s.plan_id,
            "day_name": s.day_name,
            "started_at": s.started_at,
            "completed_at": s.completed_at,
            "duration_seconds": s.duration_seconds,
            "exercises": [ex.model_dump() for ex in s.exercises],
            "notes": s.notes,
            "overall_rating": s.overall_rating,
            "fatigue_rating": s.fatigue_rating,
            "pump_rating": s.pump_rating,
            "client_id": s.client_id,
        }
        for s in request.sessions
    ]
    results = await service.sync_sessions(user_id, sessions_data)
    return SyncResponse(results=[SyncResultItem(**r) for r in results])


# ============================================================
# Exercises
# ============================================================


@router.get("/exercises", response_model=list[ExerciseResponse])
async def list_exercises(
    muscle_group: str | None = Query(None),
    equipment: str | None = Query(None),
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> list[ExerciseResponse]:
    """List available exercises with optional filters.

    Returns both predefined exercises and custom exercises created
    by the authenticated user.

    Args:
        muscle_group: Optional filter by muscle group name.
        equipment: Optional filter by equipment type.
        user_id: Authenticated user UUID from JWT.
        db: Database session.

    Returns:
        List of exercises.
    """
    service = WorkoutService(db)
    exercises = await service.list_exercises(user_id, muscle_group, equipment)
    return [ExerciseResponse.model_validate(e) for e in exercises]
