"""Integration tests for workout plans API endpoints."""

from __future__ import annotations

import uuid

import pytest
from httpx import AsyncClient

SAMPLE_PLAN = {
    "name": "Push Pull Legs",
    "description": "Classic 3-day split",
    "days": [
        {
            "name": "Push Day",
            "exercises": [
                {"exercise_name": "Bench Press", "sets": 4, "reps": "8-10", "rest_seconds": 90},
                {"exercise_name": "Overhead Press", "sets": 3, "reps": "8-10", "rest_seconds": 90},
            ],
        },
        {
            "name": "Pull Day",
            "exercises": [
                {"exercise_name": "Barbell Row", "sets": 4, "reps": "8-10", "rest_seconds": 90},
            ],
        },
        {
            "name": "Legs Day",
            "exercises": [
                {"exercise_name": "Squat", "sets": 4, "reps": "6-8", "rest_seconds": 120},
            ],
        },
    ],
}


@pytest.mark.asyncio
async def test_create_plan_success(client: AsyncClient, auth_headers: dict):
    """Creating a plan with valid data should return 201 with plan data."""
    response = await client.post("/workouts/plans", json=SAMPLE_PLAN, headers=auth_headers)
    assert response.status_code == 201
    data = response.json()
    assert data["name"] == "Push Pull Legs"
    assert data["source"] == "manual"
    assert data["is_active"] is True
    assert len(data["days"]) == 3
    assert "id" in data


@pytest.mark.asyncio
async def test_create_plan_with_warmup(client: AsyncClient, auth_headers: dict):
    """A day's warm-up items should be persisted and returned."""
    payload = {
        "name": "Warmup Plan",
        "days": [
            {
                "name": "Day 1",
                "warmup": ["5 min cardio", "Mobilità spalle"],
                "exercises": [
                    {"exercise_name": "Bench Press", "sets": 3, "reps": "10"},
                ],
            },
        ],
    }
    response = await client.post("/workouts/plans", json=payload, headers=auth_headers)
    assert response.status_code == 201
    data = response.json()
    assert data["days"][0]["warmup"] == ["5 min cardio", "Mobilità spalle"]


@pytest.mark.asyncio
async def test_create_plan_no_auth(client: AsyncClient):
    """Creating a plan without authentication should return 403."""
    response = await client.post("/workouts/plans", json=SAMPLE_PLAN)
    assert response.status_code in (401, 403)


@pytest.mark.asyncio
async def test_create_plan_empty_days(client: AsyncClient, auth_headers: dict):
    """Creating a plan with empty days should return 422."""
    payload = {**SAMPLE_PLAN, "days": []}
    response = await client.post("/workouts/plans", json=payload, headers=auth_headers)
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_create_plan_no_name(client: AsyncClient, auth_headers: dict):
    """Creating a plan without a name should return 422."""
    payload = {**SAMPLE_PLAN}
    del payload["name"]
    response = await client.post("/workouts/plans", json=payload, headers=auth_headers)
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_list_plans_empty(client: AsyncClient, auth_headers: dict):
    """Listing plans when none exist should return empty paginated response."""
    response = await client.get("/workouts/plans", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert data["items"] == []
    assert data["total"] == 0
    assert data["page"] == 1


@pytest.mark.asyncio
async def test_list_plans_with_data(client: AsyncClient, auth_headers: dict):
    """Listing plans after creating one should return it."""
    await client.post("/workouts/plans", json=SAMPLE_PLAN, headers=auth_headers)
    response = await client.get("/workouts/plans", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert data["total"] == 1
    assert data["items"][0]["name"] == "Push Pull Legs"


@pytest.mark.asyncio
async def test_get_plan_by_id(client: AsyncClient, auth_headers: dict):
    """Getting a plan by ID should return full details."""
    create = await client.post("/workouts/plans", json=SAMPLE_PLAN, headers=auth_headers)
    plan_id = create.json()["id"]

    response = await client.get(f"/workouts/plans/{plan_id}", headers=auth_headers)
    assert response.status_code == 200
    assert response.json()["id"] == plan_id


@pytest.mark.asyncio
async def test_get_plan_not_found(client: AsyncClient, auth_headers: dict):
    """Getting a nonexistent plan should return 404."""
    fake_id = str(uuid.uuid4())
    response = await client.get(f"/workouts/plans/{fake_id}", headers=auth_headers)
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_get_plan_other_user(client: AsyncClient):
    """Getting another user's plan should return 404 (not visible)."""
    from tests.conftest import create_test_token

    # Create plan as user A
    user_a_id = str(uuid.uuid4())
    headers_a = {"Authorization": f"Bearer {create_test_token(user_a_id)}"}
    create = await client.post("/workouts/plans", json=SAMPLE_PLAN, headers=headers_a)
    plan_id = create.json()["id"]

    # Try to access as user B
    user_b_id = str(uuid.uuid4())
    headers_b = {"Authorization": f"Bearer {create_test_token(user_b_id)}"}
    response = await client.get(f"/workouts/plans/{plan_id}", headers=headers_b)
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_update_plan(client: AsyncClient, auth_headers: dict):
    """Updating a plan should modify only provided fields."""
    create = await client.post("/workouts/plans", json=SAMPLE_PLAN, headers=auth_headers)
    plan_id = create.json()["id"]

    response = await client.patch(
        f"/workouts/plans/{plan_id}",
        json={"name": "Updated Plan", "is_active": False},
        headers=auth_headers,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "Updated Plan"
    assert data["is_active"] is False
    # Description should remain unchanged
    assert data["description"] == "Classic 3-day split"


@pytest.mark.asyncio
async def test_delete_plan(client: AsyncClient, auth_headers: dict):
    """Deleting a plan should return 204 and make it inaccessible."""
    create = await client.post("/workouts/plans", json=SAMPLE_PLAN, headers=auth_headers)
    plan_id = create.json()["id"]

    delete = await client.delete(f"/workouts/plans/{plan_id}", headers=auth_headers)
    assert delete.status_code == 204

    get = await client.get(f"/workouts/plans/{plan_id}", headers=auth_headers)
    assert get.status_code == 404


@pytest.mark.asyncio
async def test_delete_plan_not_found(client: AsyncClient, auth_headers: dict):
    """Deleting a nonexistent plan should return 404."""
    fake_id = str(uuid.uuid4())
    response = await client.delete(f"/workouts/plans/{fake_id}", headers=auth_headers)
    assert response.status_code == 404
