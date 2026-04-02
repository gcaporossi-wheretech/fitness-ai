"""Analytics business logic: progress, volume, adherence, summary."""

from __future__ import annotations

import uuid
from collections import Counter
from datetime import UTC, datetime, timedelta

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import WorkoutPlan, WorkoutSession


class AnalyticsService:
    """Computes analytics by reading workout sessions and plans."""

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_progress(
        self,
        user_id: uuid.UUID,
        exercise_name: str,
        from_date: datetime | None = None,
        to_date: datetime | None = None,
    ) -> list[dict]:
        """Get weight progression for a specific exercise.

        Scans JSONB exercises field in all sessions and extracts data
        for the given exercise name.

        Args:
            user_id: Owner user UUID.
            exercise_name: Exercise name to track.
            from_date: Optional start date.
            to_date: Optional end date.

        Returns:
            List of data point dicts with date and aggregated metrics.
        """
        query = select(WorkoutSession).where(WorkoutSession.user_id == user_id)
        if from_date:
            query = query.where(WorkoutSession.started_at >= from_date)
        if to_date:
            query = query.where(WorkoutSession.started_at <= to_date)
        query = query.order_by(WorkoutSession.started_at)

        result = await self.db.execute(query)
        sessions = result.scalars().all()

        data_points = []
        for session in sessions:
            exercises = session.exercises if isinstance(session.exercises, list) else []
            for ex in exercises:
                ex_name = ex.get("exercise_name", "")
                if ex_name.lower() == exercise_name.lower():
                    sets = ex.get("sets", [])
                    if not sets:
                        continue
                    max_weight = max((s.get("weight_kg", 0) or 0 for s in sets), default=0)
                    total_volume = sum(
                        (s.get("weight_kg", 0) or 0) * (s.get("reps", 0) or 0) for s in sets
                    )
                    total_sets = len(sets)
                    total_reps = sum(s.get("reps", 0) or 0 for s in sets)

                    data_points.append(
                        {
                            "date": session.started_at,
                            "max_weight_kg": max_weight,
                            "total_volume_kg": total_volume,
                            "total_sets": total_sets,
                            "total_reps": total_reps,
                        }
                    )
        return data_points

    async def get_volume(
        self,
        user_id: uuid.UUID,
        from_date: datetime | None = None,
        to_date: datetime | None = None,
        group_by: str = "week",
    ) -> list[dict]:
        """Get training volume grouped by time period.

        Args:
            user_id: Owner user UUID.
            from_date: Optional start date.
            to_date: Optional end date.
            group_by: Grouping period ('week' or 'month').

        Returns:
            List of volume data point dicts grouped by period.
        """
        query = select(WorkoutSession).where(WorkoutSession.user_id == user_id)
        if from_date:
            query = query.where(WorkoutSession.started_at >= from_date)
        if to_date:
            query = query.where(WorkoutSession.started_at <= to_date)
        query = query.order_by(WorkoutSession.started_at)

        result = await self.db.execute(query)
        sessions = result.scalars().all()

        period_data: dict[str, dict] = {}
        for session in sessions:
            dt = session.started_at
            if group_by == "month":
                period_key = dt.strftime("%Y-%m")
            else:
                # ISO week
                period_key = f"{dt.isocalendar()[0]}-W{dt.isocalendar()[1]:02d}"

            if period_key not in period_data:
                period_data[period_key] = {
                    "period": period_key,
                    "total_volume_kg": 0.0,
                    "total_sets": 0,
                    "total_reps": 0,
                    "session_count": 0,
                }

            period_data[period_key]["session_count"] += 1
            exercises = session.exercises if isinstance(session.exercises, list) else []
            for ex in exercises:
                for s in ex.get("sets", []):
                    weight = s.get("weight_kg", 0) or 0
                    reps = s.get("reps", 0) or 0
                    period_data[period_key]["total_volume_kg"] += weight * reps
                    period_data[period_key]["total_sets"] += 1
                    period_data[period_key]["total_reps"] += reps

        return list(period_data.values())

    async def get_adherence(
        self,
        user_id: uuid.UUID,
        from_date: datetime,
        to_date: datetime,
    ) -> dict:
        """Calculate workout plan adherence rate.

        Compares actual sessions to planned days in active plans.

        Args:
            user_id: Owner user UUID.
            from_date: Start date for calculation.
            to_date: End date for calculation.

        Returns:
            Dict with planned_days, completed_sessions, adherence_rate.
        """
        # Count active plan days
        plans_result = await self.db.execute(
            select(WorkoutPlan).where(
                WorkoutPlan.user_id == user_id,
                WorkoutPlan.is_active == True,  # noqa: E712
            )
        )
        plans = plans_result.scalars().all()

        days_per_week = 0
        for plan in plans:
            plan_days = plan.days if isinstance(plan.days, list) else []
            days_per_week += len(plan_days)

        # Calculate expected sessions in date range
        total_weeks = max(1, (to_date - from_date).days / 7)
        planned_days = int(days_per_week * total_weeks)

        # Count actual sessions
        count_result = await self.db.execute(
            select(func.count())
            .select_from(WorkoutSession)
            .where(
                WorkoutSession.user_id == user_id,
                WorkoutSession.started_at >= from_date,
                WorkoutSession.started_at <= to_date,
            )
        )
        completed = count_result.scalar_one()

        adherence = (completed / planned_days) if planned_days > 0 else 0.0

        return {
            "planned_days": planned_days,
            "completed_sessions": completed,
            "adherence_rate": min(1.0, round(adherence, 2)),
            "from_date": from_date,
            "to_date": to_date,
        }

    async def get_summary(self, user_id: uuid.UUID) -> dict:
        """Get overall training summary statistics.

        Args:
            user_id: Owner user UUID.

        Returns:
            Summary dict with aggregated statistics.
        """
        result = await self.db.execute(
            select(WorkoutSession)
            .where(WorkoutSession.user_id == user_id)
            .order_by(WorkoutSession.started_at.desc())
        )
        sessions = list(result.scalars().all())

        total_sessions = len(sessions)
        total_duration = sum(s.duration_seconds or 0 for s in sessions)
        total_volume = 0.0
        exercise_counter: Counter = Counter()

        now = datetime.now(UTC)
        week_start = now - timedelta(days=now.weekday())
        month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        sessions_this_week = 0
        sessions_this_month = 0

        for session in sessions:
            if session.started_at.replace(tzinfo=None) >= week_start.replace(tzinfo=None):
                sessions_this_week += 1
            if session.started_at.replace(tzinfo=None) >= month_start.replace(tzinfo=None):
                sessions_this_month += 1

            exercises = session.exercises if isinstance(session.exercises, list) else []
            for ex in exercises:
                ex_name = ex.get("exercise_name", "Unknown")
                exercise_counter[ex_name] += 1
                for s in ex.get("sets", []):
                    weight = s.get("weight_kg", 0) or 0
                    reps = s.get("reps", 0) or 0
                    total_volume += weight * reps

        # Calculate streaks (consecutive days with sessions)
        current_streak = 0
        longest_streak = 0
        if sessions:
            session_dates = sorted({s.started_at.date() for s in sessions}, reverse=True)
            streak = 1
            for i in range(1, len(session_dates)):
                if (session_dates[i - 1] - session_dates[i]).days == 1:
                    streak += 1
                else:
                    break
            current_streak = streak

            streak = 1
            max_streak = 1
            for i in range(1, len(session_dates)):
                if (session_dates[i - 1] - session_dates[i]).days == 1:
                    streak += 1
                    max_streak = max(max_streak, streak)
                else:
                    streak = 1
            longest_streak = max_streak

        favorite = exercise_counter.most_common(1)
        favorite_exercise = favorite[0][0] if favorite else None

        return {
            "total_sessions": total_sessions,
            "total_duration_minutes": total_duration // 60,
            "total_volume_kg": round(total_volume, 1),
            "current_streak": current_streak,
            "longest_streak": longest_streak,
            "favorite_exercise": favorite_exercise,
            "sessions_this_week": sessions_this_week,
            "sessions_this_month": sessions_this_month,
        }
