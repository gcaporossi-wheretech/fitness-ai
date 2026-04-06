"""E2E test: complete workout flow.

Tests: create plan -> start session -> log exercises -> complete -> sync ->
       view history -> check stats.
"""

from __future__ import annotations

import sys
import uuid
from pathlib import Path

import pytest

# Add workouts service to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "services" / "workouts"))

from tests.conftest import (  # noqa: E402
    TEST_DATABASE_URL,
    _make_sqlite_compatible,
    create_test_token,
)

from app.main import app  # noqa: E402
from app.models import Base  # noqa: E402
from app.database import get_db  # noqa: E402


@pytest.fixture
async def workout_client():
    """Create an E2E test client for workouts service."""
    from httpx import ASGITransport, AsyncClient
    from sqlalchemy.ext.asyncio import (
        AsyncSession,
        async_sessionmaker,
        create_async_engine,
    )

    engine = create_async_engine(TEST_DATABASE_URL, echo=False)
    _make_sqlite_compatible(Base)

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    session_factory = async_sessionmaker(
        engine, class_=AsyncSession, expire_on_commit=False
    )

    async def override_get_db():
        async with session_factory() as session:
            yield session

    app.dependency_overrides[get_db] = override_get_db
    transport = ASGITransport(app=app)

    async with AsyncClient(transport=transport, base_url="http://test") as client:
        yield client

    app.dependency_overrides.clear()

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await engine.dispose()


@pytest.mark.asyncio
async def test_full_workout_lifecycle(workout_client):
    """E2E: create plan -> create session -> list sessions -> list plans."""
    client = workout_client
    token = create_test_token()
    headers = {"Authorization": f"Bearer {token}"}

    # 1. Create a workout plan
    plan_resp = await client.post(
        "/workouts/plans",
        headers=headers,
        json={
            "name": "E2E Push Pull Legs",
            "description": "3-day split for testing",
            "days": [
                {
                    "name": "Push Day",
                    "exercises": [
                        {
                            "exercise_name": "Bench Press",
                            "sets": 4,
                            "reps": "8-12",
                        },
                        {
                            "exercise_name": "Shoulder Press",
                            "sets": 3,
                            "reps": "10",
                        },
                    ],
                },
                {
                    "name": "Pull Day",
                    "exercises": [
                        {
                            "exercise_name": "Barbell Row",
                            "sets": 4,
                            "reps": "8-12",
                        },
                    ],
                },
            ],
        },
    )
    assert plan_resp.status_code == 201
    plan_id = plan_resp.json()["id"]

    # 2. Get the plan
    get_plan_resp = await client.get(
        f"/workouts/plans/{plan_id}", headers=headers
    )
    assert get_plan_resp.status_code == 200
    assert get_plan_resp.json()["name"] == "E2E Push Pull Legs"

    # 3. Record a session
    session_resp = await client.post(
        "/workouts/sessions",
        headers=headers,
        json={
            "plan_id": plan_id,
            "day_name": "Push Day",
            "started_at": "2026-04-06T10:00:00Z",
            "completed_at": "2026-04-06T11:00:00Z",
            "duration_seconds": 3600,
            "exercises": [
                {
                    "exercise_name": "Bench Press",
                    "sets": [
                        {
                            "set_number": 1,
                            "reps": 10,
                            "weight_kg": 80,
                        },
                        {
                            "set_number": 2,
                            "reps": 8,
                            "weight_kg": 85,
                        },
                    ],
                },
            ],
            "notes": "E2E test session",
            "client_id": str(uuid.uuid4()),
        },
    )
    assert session_resp.status_code == 201

    # 4. List sessions
    list_resp = await client.get(
        "/workouts/sessions", headers=headers
    )
    assert list_resp.status_code == 200
    data = list_resp.json()
    assert data["total"] >= 1
    assert data["items"][0]["day_name"] == "Push Day"

    # 5. List plans
    plans_resp = await client.get("/workouts/plans", headers=headers)
    assert plans_resp.status_code == 200
    assert plans_resp.json()["total"] >= 1

    # 6. Update plan
    update_resp = await client.patch(
        f"/workouts/plans/{plan_id}",
        headers=headers,
        json={"name": "Updated PPL"},
    )
    assert update_resp.status_code == 200
    assert update_resp.json()["name"] == "Updated PPL"


@pytest.mark.asyncio
async def test_offline_sync_flow(workout_client):
    """E2E: batch sync multiple offline sessions."""
    client = workout_client
    token = create_test_token()
    headers = {"Authorization": f"Bearer {token}"}

    client_ids = [str(uuid.uuid4()) for _ in range(3)]

    # Sync 3 sessions at once
    sync_resp = await client.post(
        "/workouts/sync",
        headers=headers,
        json={
            "sessions": [
                {
                    "client_id": client_ids[0],
                    "started_at": "2026-04-01T10:00:00Z",
                    "completed_at": "2026-04-01T11:00:00Z",
                    "duration_seconds": 3600,
                    "day_name": "Sync Day 1",
                    "exercises": [
                        {
                            "exercise_name": "Squat",
                            "sets": [
                                {"set_number": 1, "reps": 5, "weight_kg": 100},
                            ],
                        },
                    ],
                },
                {
                    "client_id": client_ids[1],
                    "started_at": "2026-04-02T10:00:00Z",
                    "completed_at": "2026-04-02T10:45:00Z",
                    "duration_seconds": 2700,
                    "day_name": "Sync Day 2",
                    "exercises": [
                        {
                            "exercise_name": "Deadlift",
                            "sets": [
                                {"set_number": 1, "reps": 5, "weight_kg": 120},
                            ],
                        },
                    ],
                },
                {
                    "client_id": client_ids[2],
                    "started_at": "2026-04-03T10:00:00Z",
                    "completed_at": "2026-04-03T11:30:00Z",
                    "duration_seconds": 5400,
                    "day_name": "Sync Day 3",
                    "exercises": [
                        {
                            "exercise_name": "Bench Press",
                            "sets": [
                                {"set_number": 1, "reps": 8, "weight_kg": 80},
                            ],
                        },
                    ],
                },
            ]
        },
    )
    assert sync_resp.status_code == 200
    results = sync_resp.json()["results"]
    assert len(results) == 3
    assert all(r["status"] in ("created", "duplicate") for r in results)

    # Verify all sessions exist
    list_resp = await client.get(
        "/workouts/sessions?per_page=50", headers=headers
    )
    assert list_resp.json()["total"] >= 3
