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
async def test_create_session_with_ratings(client: AsyncClient, auth_headers: dict):
    """Overall/fatigue/pump ratings should be stored and returned."""
    payload = make_session_data()
    payload["overall_rating"] = 5
    payload["fatigue_rating"] = 3
    payload["pump_rating"] = 4
    response = await client.post("/workouts/sessions", json=payload, headers=auth_headers)
    assert response.status_code == 201
    data = response.json()
    assert data["overall_rating"] == 5
    assert data["fatigue_rating"] == 3
    assert data["pump_rating"] == 4


@pytest.mark.asyncio
async def test_create_session_rating_out_of_range(client: AsyncClient, auth_headers: dict):
    """A rating outside 1-5 should be rejected with 422."""
    payload = make_session_data()
    payload["overall_rating"] = 9
    response = await client.post("/workouts/sessions", json=payload, headers=auth_headers)
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_create_session_no_ratings_defaults_null(client: AsyncClient, auth_headers: dict):
    """Sessions created without ratings should return null for each rating."""
    response = await client.post(
        "/workouts/sessions", json=make_session_data(), headers=auth_headers
    )
    assert response.status_code == 201
    data = response.json()
    assert data["overall_rating"] is None
    assert data["fatigue_rating"] is None
    assert data["pump_rating"] is None


@pytest.mark.asyncio
async def test_create_session_no_auth(client: AsyncClient):
    """Creating a session without auth should return 403."""
    response = await client.post("/workouts/sessions", json=make_session_data())
    assert response.status_code in (401, 403)


@pytest.mark.asyncio
async def test_create_session_same_client_id_upserts(client: AsyncClient, auth_headers: dict):
    """Re-posting the same client_id should update the session (resume/edit), not duplicate."""
    client_id = str(uuid.uuid4())
    payload = make_session_data(client_id)

    first = await client.post("/workouts/sessions", json=payload, headers=auth_headers)
    assert first.status_code == 201
    first_id = first.json()["id"]

    # Resume + edit: same client_id, changed notes/duration.
    payload["notes"] = "Added treadmill"
    payload["duration_seconds"] = 4200
    second = await client.post("/workouts/sessions", json=payload, headers=auth_headers)
    assert second.status_code == 201
    body = second.json()
    # Same server row, updated fields.
    assert body["id"] == first_id
    assert body["notes"] == "Added treadmill"
    assert body["duration_seconds"] == 4200

    # And the history still contains exactly one session for this client_id.
    listing = await client.get("/workouts/sessions", headers=auth_headers)
    matches = [s for s in listing.json()["items"] if s["client_id"] == client_id]
    assert len(matches) == 1


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


@pytest.mark.asyncio
async def test_delete_session_success(client: AsyncClient, auth_headers: dict):
    """Deleting an owned session returns 204 and removes it from the list."""
    created = await client.post(
        "/workouts/sessions", json=make_session_data(), headers=auth_headers
    )
    session_id = created.json()["id"]

    resp = await client.delete(f"/workouts/sessions/{session_id}", headers=auth_headers)
    assert resp.status_code == 204

    listed = await client.get("/workouts/sessions", headers=auth_headers)
    assert listed.json()["total"] == 0


@pytest.mark.asyncio
async def test_delete_session_not_found(client: AsyncClient, auth_headers: dict):
    """Deleting a non-existent session returns 404."""
    resp = await client.delete(f"/workouts/sessions/{uuid.uuid4()}", headers=auth_headers)
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_delete_session_other_user(client: AsyncClient, auth_headers: dict):
    """A user cannot delete another user's session."""
    from tests.conftest import create_test_token

    created = await client.post(
        "/workouts/sessions", json=make_session_data(), headers=auth_headers
    )
    session_id = created.json()["id"]

    other = {"Authorization": f"Bearer {create_test_token(str(uuid.uuid4()))}"}
    resp = await client.delete(f"/workouts/sessions/{session_id}", headers=other)
    assert resp.status_code == 404
