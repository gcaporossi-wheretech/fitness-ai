"""Integration tests for analytics API endpoints."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_progress_no_data(client: AsyncClient, auth_headers: dict):
    """Progress with no sessions should return empty data points."""
    response = await client.get(
        "/analytics/progress",
        params={"exercise_name": "Bench Press"},
        headers=auth_headers,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["exercise_name"] == "Bench Press"
    assert data["data_points"] == []


@pytest.mark.asyncio
async def test_progress_with_data(seeded_client: AsyncClient, auth_headers: dict):
    """Progress with seeded sessions should return data points."""
    response = await seeded_client.get(
        "/analytics/progress",
        params={"exercise_name": "Bench Press"},
        headers=auth_headers,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["exercise_name"] == "Bench Press"
    assert len(data["data_points"]) == 2
    # Second session should show progression
    assert data["data_points"][1]["max_weight_kg"] >= data["data_points"][0]["max_weight_kg"]


@pytest.mark.asyncio
async def test_progress_missing_exercise_name(client: AsyncClient, auth_headers: dict):
    """Progress without exercise_name should return 422."""
    response = await client.get("/analytics/progress", headers=auth_headers)
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_progress_no_auth(client: AsyncClient):
    """Progress without auth should return 401."""
    response = await client.get("/analytics/progress", params={"exercise_name": "Bench Press"})
    assert response.status_code in (401, 403)


@pytest.mark.asyncio
async def test_volume_no_data(client: AsyncClient, auth_headers: dict):
    """Volume with no sessions should return empty data points."""
    response = await client.get("/analytics/volume", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert data["data_points"] == []
    assert data["group_by"] == "week"


@pytest.mark.asyncio
async def test_volume_with_data(seeded_client: AsyncClient, auth_headers: dict):
    """Volume with seeded sessions should return grouped data."""
    response = await seeded_client.get("/analytics/volume", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert len(data["data_points"]) >= 1
    for dp in data["data_points"]:
        assert dp["total_volume_kg"] > 0
        assert dp["session_count"] > 0


@pytest.mark.asyncio
async def test_volume_group_by_month(seeded_client: AsyncClient, auth_headers: dict):
    """Volume grouped by month should use YYYY-MM format."""
    response = await seeded_client.get(
        "/analytics/volume",
        params={"group_by": "month"},
        headers=auth_headers,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["group_by"] == "month"
    for dp in data["data_points"]:
        assert len(dp["period"]) == 7  # YYYY-MM


@pytest.mark.asyncio
async def test_volume_invalid_group_by(client: AsyncClient, auth_headers: dict):
    """Volume with invalid group_by should return 422."""
    response = await client.get(
        "/analytics/volume",
        params={"group_by": "day"},
        headers=auth_headers,
    )
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_adherence_no_data(client: AsyncClient, auth_headers: dict):
    """Adherence with no plans/sessions should return 0 rate."""
    response = await client.get(
        "/analytics/adherence",
        params={
            "from": "2026-03-01T00:00:00Z",
            "to": "2026-03-31T23:59:59Z",
        },
        headers=auth_headers,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["planned_days"] == 0
    assert data["completed_sessions"] == 0
    assert data["adherence_rate"] == 0.0


@pytest.mark.asyncio
async def test_adherence_with_data(seeded_client: AsyncClient, auth_headers: dict):
    """Adherence with seeded data should calculate rate correctly."""
    # Use a window relative to now so it always covers the seeded sessions
    # (seeded at now-14/-13/-7 days). A hardcoded month window made this test
    # date-dependent and it broke once "now" moved past it.
    now = datetime.now(UTC)
    response = await seeded_client.get(
        "/analytics/adherence",
        params={
            "from": (now - timedelta(days=40)).isoformat(),
            "to": (now + timedelta(days=1)).isoformat(),
        },
        headers=auth_headers,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["completed_sessions"] == 3
    assert data["planned_days"] > 0
    assert 0 <= data["adherence_rate"] <= 1.0


@pytest.mark.asyncio
async def test_summary_no_data(client: AsyncClient, auth_headers: dict):
    """Summary with no sessions should return zeros."""
    response = await client.get("/analytics/summary", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert data["total_sessions"] == 0
    assert data["total_duration_minutes"] == 0
    assert data["total_volume_kg"] == 0
    assert data["current_streak"] == 0
    assert data["favorite_exercise"] is None


@pytest.mark.asyncio
async def test_summary_with_data(seeded_client: AsyncClient, auth_headers: dict):
    """Summary with seeded data should return correct stats."""
    response = await seeded_client.get("/analytics/summary", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert data["total_sessions"] == 3
    assert data["total_duration_minutes"] > 0
    assert data["total_volume_kg"] > 0
    assert data["favorite_exercise"] == "Bench Press"


@pytest.mark.asyncio
async def test_summary_no_auth(client: AsyncClient):
    """Summary without auth should return 401."""
    response = await client.get("/analytics/summary")
    assert response.status_code in (401, 403)
