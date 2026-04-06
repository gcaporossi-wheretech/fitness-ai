"""Unit tests for AnalyticsService — direct method calls with mocked database."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.service import AnalyticsService


def _make_session(
    user_id: uuid.UUID,
    started_at: datetime,
    exercises: list,
    duration_seconds: int = 3600,
) -> MagicMock:
    """Create a mock WorkoutSession."""
    session = MagicMock()
    session.user_id = user_id
    session.started_at = started_at
    session.completed_at = started_at + timedelta(seconds=duration_seconds)
    session.duration_seconds = duration_seconds
    session.exercises = exercises
    return session


def _make_plan(
    user_id: uuid.UUID,
    days: list,
    is_active: bool = True,
) -> MagicMock:
    """Create a mock WorkoutPlan."""
    plan = MagicMock()
    plan.user_id = user_id
    plan.days = days
    plan.is_active = is_active
    return plan


def _mock_db_with_results(*results):
    """Create a mock AsyncSession that returns results in sequence."""
    db = AsyncMock()
    execute_results = []
    for result_data in results:
        mock_result = MagicMock()
        mock_result.scalars.return_value.all.return_value = result_data
        mock_result.scalar_one.return_value = (
            len(result_data) if isinstance(result_data, list) else result_data
        )
        execute_results.append(mock_result)
    db.execute = AsyncMock(side_effect=execute_results)
    return db


@pytest.mark.asyncio
async def test_get_progress_returns_data_points():
    """get_progress should extract exercise data from sessions."""
    user_id = uuid.uuid4()
    now = datetime.now(UTC)

    sessions = [
        _make_session(
            user_id,
            now - timedelta(days=7),
            [
                {
                    "exercise_name": "Bench Press",
                    "sets": [
                        {"weight_kg": 80, "reps": 10},
                        {"weight_kg": 85, "reps": 8},
                    ],
                }
            ],
        ),
        _make_session(
            user_id,
            now - timedelta(days=3),
            [
                {
                    "exercise_name": "Bench Press",
                    "sets": [
                        {"weight_kg": 90, "reps": 8},
                        {"weight_kg": 95, "reps": 6},
                    ],
                }
            ],
        ),
    ]

    db = _mock_db_with_results(sessions)
    service = AnalyticsService(db)

    result = await service.get_progress(user_id, "Bench Press")

    assert len(result) == 2
    assert result[0]["max_weight_kg"] == 85
    assert result[0]["total_volume_kg"] == 80 * 10 + 85 * 8
    assert result[0]["total_sets"] == 2
    assert result[0]["total_reps"] == 18
    assert result[1]["max_weight_kg"] == 95


@pytest.mark.asyncio
async def test_get_progress_case_insensitive():
    """get_progress should match exercise names case-insensitively."""
    user_id = uuid.uuid4()
    now = datetime.now(UTC)

    sessions = [
        _make_session(
            user_id,
            now,
            [
                {
                    "exercise_name": "bench press",
                    "sets": [{"weight_kg": 80, "reps": 10}],
                }
            ],
        ),
    ]

    db = _mock_db_with_results(sessions)
    service = AnalyticsService(db)
    result = await service.get_progress(user_id, "Bench Press")

    assert len(result) == 1
    assert result[0]["max_weight_kg"] == 80


@pytest.mark.asyncio
async def test_get_progress_empty_sets():
    """get_progress should skip exercises with no sets."""
    user_id = uuid.uuid4()
    now = datetime.now(UTC)

    sessions = [
        _make_session(
            user_id,
            now,
            [{"exercise_name": "Bench Press", "sets": []}],
        ),
    ]

    db = _mock_db_with_results(sessions)
    service = AnalyticsService(db)
    result = await service.get_progress(user_id, "Bench Press")

    assert len(result) == 0


@pytest.mark.asyncio
async def test_get_progress_non_list_exercises():
    """get_progress should handle exercises that are not a list (e.g. None/dict)."""
    user_id = uuid.uuid4()
    now = datetime.now(UTC)

    sessions = [
        _make_session(user_id, now, None),  # exercises is None
    ]
    # Override exercises to be non-list
    sessions[0].exercises = "not a list"

    db = _mock_db_with_results(sessions)
    service = AnalyticsService(db)
    result = await service.get_progress(user_id, "Bench Press")

    assert len(result) == 0


@pytest.mark.asyncio
async def test_get_progress_with_date_filters():
    """get_progress should accept from_date and to_date."""
    user_id = uuid.uuid4()
    now = datetime.now(UTC)

    sessions = [
        _make_session(
            user_id,
            now - timedelta(days=5),
            [
                {
                    "exercise_name": "Squat",
                    "sets": [{"weight_kg": 100, "reps": 5}],
                }
            ],
        ),
    ]

    db = _mock_db_with_results(sessions)
    service = AnalyticsService(db)
    result = await service.get_progress(
        user_id,
        "Squat",
        from_date=now - timedelta(days=7),
        to_date=now,
    )

    assert len(result) == 1


@pytest.mark.asyncio
async def test_get_progress_null_weight_and_reps():
    """get_progress should handle None weight and reps in sets."""
    user_id = uuid.uuid4()
    now = datetime.now(UTC)

    sessions = [
        _make_session(
            user_id,
            now,
            [
                {
                    "exercise_name": "Bench Press",
                    "sets": [
                        {"weight_kg": None, "reps": None},
                        {"weight_kg": 80, "reps": 10},
                    ],
                }
            ],
        ),
    ]

    db = _mock_db_with_results(sessions)
    service = AnalyticsService(db)
    result = await service.get_progress(user_id, "Bench Press")

    assert len(result) == 1
    assert result[0]["max_weight_kg"] == 80
    assert result[0]["total_volume_kg"] == 800
    assert result[0]["total_reps"] == 10


@pytest.mark.asyncio
async def test_get_volume_weekly():
    """get_volume with group_by='week' should group sessions by ISO week."""
    user_id = uuid.uuid4()
    now = datetime.now(UTC)

    sessions = [
        _make_session(
            user_id,
            now - timedelta(days=3),
            [
                {
                    "exercise_name": "Bench Press",
                    "sets": [{"weight_kg": 80, "reps": 10}],
                }
            ],
        ),
        _make_session(
            user_id,
            now - timedelta(days=2),
            [
                {
                    "exercise_name": "Squat",
                    "sets": [{"weight_kg": 100, "reps": 8}],
                }
            ],
        ),
    ]

    db = _mock_db_with_results(sessions)
    service = AnalyticsService(db)
    result = await service.get_volume(user_id, group_by="week")

    assert len(result) >= 1
    for dp in result:
        assert "W" in dp["period"]
        assert dp["total_volume_kg"] > 0
        assert dp["total_sets"] > 0
        assert dp["session_count"] > 0


@pytest.mark.asyncio
async def test_get_volume_monthly():
    """get_volume with group_by='month' should group sessions by YYYY-MM."""
    user_id = uuid.uuid4()
    now = datetime.now(UTC)

    sessions = [
        _make_session(
            user_id,
            now - timedelta(days=5),
            [
                {
                    "exercise_name": "Deadlift",
                    "sets": [
                        {"weight_kg": 120, "reps": 5},
                        {"weight_kg": 130, "reps": 3},
                    ],
                }
            ],
        ),
    ]

    db = _mock_db_with_results(sessions)
    service = AnalyticsService(db)
    result = await service.get_volume(user_id, group_by="month")

    assert len(result) == 1
    assert len(result[0]["period"]) == 7  # YYYY-MM
    assert result[0]["total_volume_kg"] == 120 * 5 + 130 * 3
    assert result[0]["total_sets"] == 2
    assert result[0]["total_reps"] == 8
    assert result[0]["session_count"] == 1


@pytest.mark.asyncio
async def test_get_volume_with_date_filters():
    """get_volume should accept from_date and to_date parameters."""
    user_id = uuid.uuid4()
    now = datetime.now(UTC)

    sessions = [
        _make_session(
            user_id,
            now - timedelta(days=3),
            [
                {
                    "exercise_name": "Bench Press",
                    "sets": [{"weight_kg": 80, "reps": 10}],
                }
            ],
        ),
    ]

    db = _mock_db_with_results(sessions)
    service = AnalyticsService(db)
    result = await service.get_volume(
        user_id,
        from_date=now - timedelta(days=7),
        to_date=now,
        group_by="week",
    )

    assert len(result) == 1


@pytest.mark.asyncio
async def test_get_volume_empty_exercises():
    """get_volume should handle sessions with non-list exercises."""
    user_id = uuid.uuid4()
    now = datetime.now(UTC)

    sessions = [
        _make_session(user_id, now, []),
    ]
    sessions[0].exercises = "not a list"

    db = _mock_db_with_results(sessions)
    service = AnalyticsService(db)
    result = await service.get_volume(user_id)

    assert len(result) == 1
    assert result[0]["total_volume_kg"] == 0


@pytest.mark.asyncio
async def test_get_volume_null_weight_reps():
    """get_volume should handle None weights and reps gracefully."""
    user_id = uuid.uuid4()
    now = datetime.now(UTC)

    sessions = [
        _make_session(
            user_id,
            now,
            [
                {
                    "exercise_name": "OHP",
                    "sets": [{"weight_kg": None, "reps": None}],
                }
            ],
        ),
    ]

    db = _mock_db_with_results(sessions)
    service = AnalyticsService(db)
    result = await service.get_volume(user_id)

    assert len(result) == 1
    assert result[0]["total_volume_kg"] == 0


@pytest.mark.asyncio
async def test_get_adherence_with_plans():
    """get_adherence should calculate adherence from plans and sessions."""
    user_id = uuid.uuid4()
    now = datetime.now(UTC)

    plans = [
        _make_plan(user_id, [{"name": "Push"}, {"name": "Pull"}, {"name": "Legs"}]),
    ]

    # Mock: first call returns plans, second call returns session count
    db = AsyncMock()
    plans_result = MagicMock()
    plans_result.scalars.return_value.all.return_value = plans

    count_result = MagicMock()
    count_result.scalar_one.return_value = 6

    db.execute = AsyncMock(side_effect=[plans_result, count_result])

    service = AnalyticsService(db)
    result = await service.get_adherence(
        user_id,
        from_date=now - timedelta(days=14),
        to_date=now,
    )

    assert result["planned_days"] == 6  # 3 days/week * 2 weeks
    assert result["completed_sessions"] == 6
    assert result["adherence_rate"] == 1.0
    assert "from_date" in result
    assert "to_date" in result


@pytest.mark.asyncio
async def test_get_adherence_no_plans():
    """get_adherence with no active plans should return 0 adherence."""
    user_id = uuid.uuid4()
    now = datetime.now(UTC)

    db = AsyncMock()
    plans_result = MagicMock()
    plans_result.scalars.return_value.all.return_value = []

    count_result = MagicMock()
    count_result.scalar_one.return_value = 0

    db.execute = AsyncMock(side_effect=[plans_result, count_result])

    service = AnalyticsService(db)
    result = await service.get_adherence(
        user_id,
        from_date=now - timedelta(days=30),
        to_date=now,
    )

    assert result["planned_days"] == 0
    assert result["completed_sessions"] == 0
    assert result["adherence_rate"] == 0.0


@pytest.mark.asyncio
async def test_get_adherence_plan_with_non_list_days():
    """get_adherence should handle plans with non-list days."""
    user_id = uuid.uuid4()
    now = datetime.now(UTC)

    plan = _make_plan(user_id, "not a list")

    db = AsyncMock()
    plans_result = MagicMock()
    plans_result.scalars.return_value.all.return_value = [plan]

    count_result = MagicMock()
    count_result.scalar_one.return_value = 0

    db.execute = AsyncMock(side_effect=[plans_result, count_result])

    service = AnalyticsService(db)
    result = await service.get_adherence(
        user_id,
        from_date=now - timedelta(days=7),
        to_date=now,
    )

    assert result["planned_days"] == 0


@pytest.mark.asyncio
async def test_get_adherence_over_100_percent():
    """get_adherence should cap adherence at 1.0."""
    user_id = uuid.uuid4()
    now = datetime.now(UTC)

    plans = [_make_plan(user_id, [{"name": "Push"}])]

    db = AsyncMock()
    plans_result = MagicMock()
    plans_result.scalars.return_value.all.return_value = plans

    count_result = MagicMock()
    count_result.scalar_one.return_value = 10  # More sessions than planned

    db.execute = AsyncMock(side_effect=[plans_result, count_result])

    service = AnalyticsService(db)
    result = await service.get_adherence(
        user_id,
        from_date=now - timedelta(days=7),
        to_date=now,
    )

    assert result["adherence_rate"] <= 1.0


@pytest.mark.asyncio
async def test_get_summary_with_sessions():
    """get_summary should compute all summary statistics."""
    user_id = uuid.uuid4()
    now = datetime.now(UTC)

    sessions = [
        _make_session(
            user_id,
            now - timedelta(days=1),  # yesterday
            [
                {
                    "exercise_name": "Bench Press",
                    "sets": [
                        {"weight_kg": 80, "reps": 10},
                        {"weight_kg": 85, "reps": 8},
                    ],
                },
                {
                    "exercise_name": "Overhead Press",
                    "sets": [{"weight_kg": 40, "reps": 12}],
                },
            ],
            duration_seconds=3600,
        ),
        _make_session(
            user_id,
            now,  # today
            [
                {
                    "exercise_name": "Bench Press",
                    "sets": [{"weight_kg": 90, "reps": 8}],
                },
            ],
            duration_seconds=2700,
        ),
    ]

    db = _mock_db_with_results(sessions)
    service = AnalyticsService(db)
    result = await service.get_summary(user_id)

    assert result["total_sessions"] == 2
    assert result["total_duration_minutes"] == (3600 + 2700) // 60
    assert result["total_volume_kg"] > 0
    assert result["favorite_exercise"] == "Bench Press"
    assert result["sessions_this_week"] >= 0
    assert result["sessions_this_month"] >= 0
    assert result["current_streak"] >= 1
    assert result["longest_streak"] >= 1


@pytest.mark.asyncio
async def test_get_summary_no_sessions():
    """get_summary with no sessions should return zero values."""
    user_id = uuid.uuid4()

    db = _mock_db_with_results([])
    service = AnalyticsService(db)
    result = await service.get_summary(user_id)

    assert result["total_sessions"] == 0
    assert result["total_duration_minutes"] == 0
    assert result["total_volume_kg"] == 0.0
    assert result["current_streak"] == 0
    assert result["longest_streak"] == 0
    assert result["favorite_exercise"] is None
    assert result["sessions_this_week"] == 0
    assert result["sessions_this_month"] == 0


@pytest.mark.asyncio
async def test_get_summary_non_list_exercises():
    """get_summary should handle non-list exercises in sessions."""
    user_id = uuid.uuid4()
    now = datetime.now(UTC)

    sessions = [
        _make_session(user_id, now, []),
    ]
    sessions[0].exercises = {"not": "a list"}
    sessions[0].duration_seconds = None  # Also test None duration

    db = _mock_db_with_results(sessions)
    service = AnalyticsService(db)
    result = await service.get_summary(user_id)

    assert result["total_sessions"] == 1
    assert result["total_duration_minutes"] == 0


@pytest.mark.asyncio
async def test_get_summary_streak_calculation():
    """get_summary should calculate current and longest streaks correctly."""
    user_id = uuid.uuid4()
    now = datetime.now(UTC)

    # Create sessions on 5 consecutive days, then gap, then 2 consecutive days
    sessions = [
        _make_session(user_id, now - timedelta(days=i), [])
        for i in range(5)  # today, yesterday, ..., 4 days ago
    ]
    # Add sessions from 10 and 11 days ago (a separate streak of 2)
    sessions.append(_make_session(user_id, now - timedelta(days=10), []))
    sessions.append(_make_session(user_id, now - timedelta(days=11), []))

    db = _mock_db_with_results(sessions)
    service = AnalyticsService(db)
    result = await service.get_summary(user_id)

    assert result["current_streak"] == 5
    assert result["longest_streak"] == 5


@pytest.mark.asyncio
async def test_get_summary_null_weight_reps():
    """get_summary should handle None weights and reps."""
    user_id = uuid.uuid4()
    now = datetime.now(UTC)

    sessions = [
        _make_session(
            user_id,
            now,
            [
                {
                    "exercise_name": "Curl",
                    "sets": [
                        {"weight_kg": None, "reps": None},
                        {"weight_kg": 10, "reps": 12},
                    ],
                }
            ],
        ),
    ]

    db = _mock_db_with_results(sessions)
    service = AnalyticsService(db)
    result = await service.get_summary(user_id)

    assert result["total_volume_kg"] == 120.0
    assert result["favorite_exercise"] == "Curl"
