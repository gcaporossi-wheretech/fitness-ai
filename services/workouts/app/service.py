"""Workouts business logic: plans CRUD, sessions, exercises, sync."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Exercise, WorkoutPlan, WorkoutSession


class WorkoutServiceError(Exception):
    """Base exception for workouts service errors."""

    def __init__(self, message: str, code: str) -> None:
        self.message = message
        self.code = code
        super().__init__(message)


class PlanNotFoundError(WorkoutServiceError):
    """Raised when a workout plan is not found or not owned by user."""

    def __init__(self) -> None:
        super().__init__("Workout plan not found", "PLAN_NOT_FOUND")


class SessionNotFoundError(WorkoutServiceError):
    """Raised when a workout session is not found."""

    def __init__(self) -> None:
        super().__init__("Workout session not found", "SESSION_NOT_FOUND")


class DuplicateClientIdError(WorkoutServiceError):
    """Raised when a session with the same client_id already exists."""

    def __init__(self, client_id: uuid.UUID) -> None:
        super().__init__(
            f"Session with client_id {client_id} already exists",
            "DUPLICATE_CLIENT_ID",
        )


class WorkoutService:
    """Handles all workout plans, sessions, and exercise operations."""

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    # ============================================================
    # Workout Plans
    # ============================================================

    async def create_plan(
        self,
        user_id: uuid.UUID,
        name: str,
        days: list[dict],
        description: str | None = None,
        phases: list[dict] | None = None,
        source: str = "manual",
    ) -> WorkoutPlan:
        """Create a new workout plan.

        Args:
            user_id: Owner user UUID.
            name: Plan name.
            days: List of day objects with exercises.
            description: Optional plan description.
            phases: Optional periodization phases.
            source: Plan origin ('manual', 'ai_coach', 'imported').

        Returns:
            Created WorkoutPlan object.
        """
        plan = WorkoutPlan(
            user_id=user_id,
            name=name,
            description=description,
            phases=phases,
            days=days,
            source=source,
        )
        self.db.add(plan)
        await self.db.commit()
        await self.db.refresh(plan)
        return plan

    async def get_plan(self, plan_id: uuid.UUID, user_id: uuid.UUID) -> WorkoutPlan:
        """Get a single workout plan owned by the user.

        Args:
            plan_id: Plan UUID.
            user_id: Owner user UUID.

        Returns:
            WorkoutPlan object.

        Raises:
            PlanNotFoundError: If plan does not exist or is not owned by user.
        """
        result = await self.db.execute(
            select(WorkoutPlan).where(WorkoutPlan.id == plan_id, WorkoutPlan.user_id == user_id)
        )
        plan = result.scalar_one_or_none()
        if not plan:
            raise PlanNotFoundError()
        return plan

    async def list_plans(
        self, user_id: uuid.UUID, page: int = 1, per_page: int = 20
    ) -> tuple[list[WorkoutPlan], int]:
        """List workout plans for a user with pagination.

        Args:
            user_id: Owner user UUID.
            page: Page number (1-based).
            per_page: Items per page.

        Returns:
            Tuple of (plans list, total count).
        """
        count_result = await self.db.execute(
            select(func.count()).select_from(WorkoutPlan).where(WorkoutPlan.user_id == user_id)
        )
        total = count_result.scalar_one()

        result = await self.db.execute(
            select(WorkoutPlan)
            .where(WorkoutPlan.user_id == user_id)
            .order_by(WorkoutPlan.updated_at.desc())
            .offset((page - 1) * per_page)
            .limit(per_page)
        )
        plans = list(result.scalars().all())
        return plans, total

    async def update_plan(self, plan_id: uuid.UUID, user_id: uuid.UUID, **kwargs) -> WorkoutPlan:
        """Update a workout plan's fields.

        Args:
            plan_id: Plan UUID.
            user_id: Owner user UUID.
            **kwargs: Fields to update.

        Returns:
            Updated WorkoutPlan object.

        Raises:
            PlanNotFoundError: If plan does not exist or is not owned by user.
        """
        plan = await self.get_plan(plan_id, user_id)
        for key, value in kwargs.items():
            if value is not None and hasattr(plan, key):
                setattr(plan, key, value)
        plan.updated_at = datetime.now(UTC)
        await self.db.commit()
        await self.db.refresh(plan)
        return plan

    async def delete_plan(self, plan_id: uuid.UUID, user_id: uuid.UUID) -> None:
        """Delete a workout plan.

        Args:
            plan_id: Plan UUID.
            user_id: Owner user UUID.

        Raises:
            PlanNotFoundError: If plan does not exist or is not owned by user.
        """
        plan = await self.get_plan(plan_id, user_id)
        await self.db.delete(plan)
        await self.db.commit()

    # ============================================================
    # Workout Sessions
    # ============================================================

    async def create_session(
        self,
        user_id: uuid.UUID,
        client_id: uuid.UUID,
        started_at: datetime,
        exercises: list[dict],
        plan_id: uuid.UUID | None = None,
        day_name: str | None = None,
        completed_at: datetime | None = None,
        duration_seconds: int | None = None,
        notes: str | None = None,
        overall_rating: int | None = None,
        fatigue_rating: int | None = None,
        pump_rating: int | None = None,
    ) -> WorkoutSession:
        """Create a new workout session.

        Args:
            user_id: Owner user UUID.
            client_id: Dedup key from mobile client.
            started_at: Session start timestamp.
            exercises: List of exercise log dicts.
            plan_id: Optional linked workout plan.
            day_name: Optional day name from plan.
            completed_at: Optional completion timestamp.
            duration_seconds: Optional total duration.
            notes: Optional session notes.
            overall_rating: Optional overall workout rating (1-5).
            fatigue_rating: Optional perceived-fatigue rating (1-5).
            pump_rating: Optional pump-sensation rating (1-5).

        Returns:
            Created (or updated) WorkoutSession object.

        Raises:
            DuplicateClientIdError: If the client_id belongs to another user.
        """
        result = await self.db.execute(
            select(WorkoutSession).where(WorkoutSession.client_id == client_id)
        )
        existing = result.scalar_one_or_none()
        if existing is not None:
            # Same client_id from the same user = a re-uploaded session (e.g. a
            # finished workout reopened via "resume" and edited). Update it in
            # place (last-write-wins) instead of rejecting, so the edits persist
            # server-side. A collision across users is still an error.
            if existing.user_id != user_id:
                raise DuplicateClientIdError(client_id)
            existing.plan_id = plan_id
            existing.day_name = day_name
            existing.started_at = started_at
            existing.completed_at = completed_at
            existing.duration_seconds = duration_seconds
            existing.exercises = exercises
            existing.notes = notes
            existing.overall_rating = overall_rating
            existing.fatigue_rating = fatigue_rating
            existing.pump_rating = pump_rating
            existing.synced_at = datetime.now(UTC)
            await self.db.commit()
            await self.db.refresh(existing)
            return existing

        session = WorkoutSession(
            user_id=user_id,
            plan_id=plan_id,
            day_name=day_name,
            started_at=started_at,
            completed_at=completed_at,
            duration_seconds=duration_seconds,
            exercises=exercises,
            notes=notes,
            overall_rating=overall_rating,
            fatigue_rating=fatigue_rating,
            pump_rating=pump_rating,
            client_id=client_id,
            synced_at=datetime.now(UTC),
        )
        self.db.add(session)
        await self.db.commit()
        await self.db.refresh(session)
        return session

    async def list_sessions(
        self,
        user_id: uuid.UUID,
        page: int = 1,
        per_page: int = 20,
        from_date: datetime | None = None,
        to_date: datetime | None = None,
    ) -> tuple[list[WorkoutSession], int]:
        """List workout sessions for a user with optional date filtering.

        Args:
            user_id: Owner user UUID.
            page: Page number (1-based).
            per_page: Items per page.
            from_date: Optional start date filter.
            to_date: Optional end date filter.

        Returns:
            Tuple of (sessions list, total count).
        """
        base_query = select(WorkoutSession).where(WorkoutSession.user_id == user_id)
        count_query = (
            select(func.count())
            .select_from(WorkoutSession)
            .where(WorkoutSession.user_id == user_id)
        )

        if from_date:
            base_query = base_query.where(WorkoutSession.started_at >= from_date)
            count_query = count_query.where(WorkoutSession.started_at >= from_date)
        if to_date:
            base_query = base_query.where(WorkoutSession.started_at <= to_date)
            count_query = count_query.where(WorkoutSession.started_at <= to_date)

        count_result = await self.db.execute(count_query)
        total = count_result.scalar_one()

        result = await self.db.execute(
            base_query.order_by(WorkoutSession.started_at.desc())
            .offset((page - 1) * per_page)
            .limit(per_page)
        )
        sessions = list(result.scalars().all())
        return sessions, total

    async def delete_session(self, session_id: uuid.UUID, user_id: uuid.UUID) -> None:
        """Delete a workout session owned by the user.

        Args:
            session_id: Session UUID.
            user_id: Owner user UUID.

        Raises:
            SessionNotFoundError: If the session does not exist or is not owned.
        """
        result = await self.db.execute(
            select(WorkoutSession).where(
                WorkoutSession.id == session_id,
                WorkoutSession.user_id == user_id,
            )
        )
        session = result.scalar_one_or_none()
        if not session:
            raise SessionNotFoundError()
        await self.db.delete(session)
        await self.db.commit()

    # ============================================================
    # Sync
    # ============================================================

    async def sync_sessions(self, user_id: uuid.UUID, sessions_data: list[dict]) -> list[dict]:
        """Sync a batch of sessions from the mobile client.

        For each session: if client_id already exists, mark as duplicate.
        Otherwise, create it. Never fails the entire batch for one error.

        Args:
            user_id: Owner user UUID.
            sessions_data: List of session dicts from mobile.

        Returns:
            List of result dicts with client_id, status, server_id, error.
        """
        results = []
        for session_data in sessions_data:
            client_id = session_data["client_id"]
            try:
                existing = await self.db.execute(
                    select(WorkoutSession).where(WorkoutSession.client_id == client_id)
                )
                if existing.scalar_one_or_none():
                    results.append(
                        {
                            "client_id": client_id,
                            "status": "duplicate",
                            "server_id": None,
                            "error": None,
                        }
                    )
                    continue

                session = WorkoutSession(
                    user_id=user_id,
                    plan_id=session_data.get("plan_id"),
                    day_name=session_data.get("day_name"),
                    started_at=session_data["started_at"],
                    completed_at=session_data.get("completed_at"),
                    duration_seconds=session_data.get("duration_seconds"),
                    exercises=session_data["exercises"],
                    notes=session_data.get("notes"),
                    overall_rating=session_data.get("overall_rating"),
                    fatigue_rating=session_data.get("fatigue_rating"),
                    pump_rating=session_data.get("pump_rating"),
                    client_id=client_id,
                    synced_at=datetime.now(UTC),
                )
                self.db.add(session)
                await self.db.flush()

                results.append(
                    {
                        "client_id": client_id,
                        "status": "created",
                        "server_id": session.id,
                        "error": None,
                    }
                )
            except Exception as e:
                results.append(
                    {
                        "client_id": client_id,
                        "status": "error",
                        "server_id": None,
                        "error": str(e),
                    }
                )

        await self.db.commit()
        return results

    # ============================================================
    # Exercises
    # ============================================================

    async def list_exercises(
        self,
        user_id: uuid.UUID | None = None,
        muscle_group: str | None = None,
        equipment: str | None = None,
    ) -> list[Exercise]:
        """List exercises, optionally filtered by muscle group or equipment.

        Returns both predefined exercises and custom exercises owned by the user.

        Args:
            user_id: User UUID for including custom exercises.
            muscle_group: Optional filter by muscle group.
            equipment: Optional filter by equipment type.

        Returns:
            List of Exercise objects.
        """
        query = select(Exercise).where(
            (Exercise.is_custom == False) | (Exercise.user_id == user_id)  # noqa: E712
        )

        if muscle_group:
            query = query.where(Exercise.muscle_groups.contains([muscle_group]))
        if equipment:
            query = query.where(Exercise.equipment == equipment)

        query = query.order_by(Exercise.name)
        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def get_exercise(self, exercise_id: uuid.UUID) -> Exercise | None:
        """Get a single exercise by ID.

        Args:
            exercise_id: Exercise UUID.

        Returns:
            Exercise object or None.
        """
        result = await self.db.execute(select(Exercise).where(Exercise.id == exercise_id))
        return result.scalar_one_or_none()
