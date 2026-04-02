"""Integration tests for workout sessions API endpoints."""

from __future__ import annotations

import uuid

import pytest
from httpx import AsyncClient


def make_session_data(client_id: str | None = None) -> dict:
    """Create sample session data for testing.

    Args:
        client_id: Optional client UUID string. Generates random if not provided.

    Returns:
        Session request body dict.
    """
    return {
        "started_at": "2026-03-15T10:00:00Z",
        "completed_at": "2026-03-15T11:00:00Z",
        "duration_seconds": 3600,
        "day_name": "Push Day",
        "exercises": [
            {
                "exercise_name": "Bench Press",
                "sets": [
                    {"set_number": 1, "weight_kg": 80, "reps": 10},
                    {"set_number": 2, "weight_kg": 80, "reps": 8},
                    {"set_number": 3, "weight_kg": 80, "reps": 7},
                ],
            },
        ],
        "notes": "Good session",
        "client_id": client_id or str(uuid.uuid4()),
    }


@pytest.mark.asyncio
async def test_create_session_success(client: AsyncClient, auth_headers: dict):
    """Creating a session should return 201 with session data."""
    payload = make_session_data()
    response = await client.post("/workouts/sessions", json=payload, headers=auth_headers)
    assert response.status_code == 201
    data = response.json()
    assert data["day_name"] == "Push Day"
    assert data["duration_seconds"] == 3600
    assert len(data["exercises"]) == 1
    assert data["synced_at"] is not None


@pytest.mark.asyncio
async def test_create_session_no_auth(client: AsyncClient):
    """Creating a session without auth should return 403."""
    response = await client.post("/workouts/sessions", json=make_session_data())
    assert response.status_code in (401, 403)


@pytest.mark.asyncio
async def test_create_session_duplicate_client_id(client: AsyncClient, auth_headers: dict):
    """Creating two sessions with the same client_id should return 409."""
    client_id = str(uuid.uuid4())
    payload = make_session_data(client_id)

    first = await client.post("/workouts/sessions", json=payload, headers=auth_headers)
    assert first.status_code == 201

    second = await client.post("/workouts/sessions", json=payload, headers=auth_headers)
    assert second.status_code == 409


@pytest.mark.asyncio
async def test_create_session_empty_exercises(client: AsyncClient, auth_headers: dict):
    """Creating a session with no exercises should return 422."""
    payload = make_session_data()
    payload["exercises"] = []
    response = await client.post("/workouts/sessions", json=payload, headers=auth_headers)
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_list_sessions_empty(client: AsyncClient, auth_headers: dict):
    """Listing sessions when none exist should return empty paginated response."""
    response = await client.get("/workouts/sessions", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert data["items"] == []
    assert data["total"] == 0


@pytest.mark.asyncio
async def test_list_sessions_with_data(client: AsyncClient, auth_headers: dict):
    """Listing sessions after creating one should return it."""
    await client.post("/workouts/sessions", json=make_session_data(), headers=auth_headers)
    response = await client.get("/workouts/sessions", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert data["total"] == 1


@pytest.mark.asyncio
async def test_list_sessions_other_user_isolation(client: AsyncClient):
    """Sessions created by one user should not be visible to another."""
    from tests.conftest import create_test_token

    user_a_id = str(uuid.uuid4())
    headers_a = {"Authorization": f"Bearer {create_test_token(user_a_id)}"}
    await client.post("/workouts/sessions", json=make_session_data(), headers=headers_a)

    user_b_id = str(uuid.uuid4())
    headers_b = {"Authorization": f"Bearer {create_test_token(user_b_id)}"}
    response = await client.get("/workouts/sessions", headers=headers_b)
    assert response.json()["total"] == 0


@pytest.mark.asyncio
async def test_sync_sessions_success(client: AsyncClient, auth_headers: dict):
    """Syncing a batch of sessions should create them all."""
    payload = {
        "sessions": [
            {
                "started_at": "2026-03-15T10:00:00Z",
                "exercises": [
                    {
                        "exercise_name": "Bench Press",
                        "sets": [{"set_number": 1, "weight_kg": 80, "reps": 10}],
                    },
                ],
                "client_id": str(uuid.uuid4()),
            },
            {
                "started_at": "2026-03-16T10:00:00Z",
                "exercises": [
                    {
                        "exercise_name": "Squat",
                        "sets": [{"set_number": 1, "weight_kg": 100, "reps": 8}],
                    },
                ],
                "client_id": str(uuid.uuid4()),
            },
        ],
    }
    response = await client.post("/workouts/sync", json=payload, headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert len(data["results"]) == 2
    assert all(r["status"] == "created" for r in data["results"])
    assert all(r["server_id"] is not None for r in data["results"])


@pytest.mark.asyncio
async def test_sync_sessions_duplicate(client: AsyncClient, auth_headers: dict):
    """Syncing a session with existing client_id should report duplicate."""
    client_id = str(uuid.uuid4())
    session_data = make_session_data(client_id)
    await client.post("/workouts/sessions", json=session_data, headers=auth_headers)

    payload = {
        "sessions": [
            {
                "started_at": "2026-03-15T10:00:00Z",
                "exercises": [
                    {
                        "exercise_name": "Bench Press",
                        "sets": [{"set_number": 1, "weight_kg": 80, "reps": 10}],
                    },
                ],
                "client_id": client_id,
            },
        ],
    }
    response = await client.post("/workouts/sync", json=payload, headers=auth_headers)
    assert response.status_code == 200
    assert response.json()["results"][0]["status"] == "duplicate"
