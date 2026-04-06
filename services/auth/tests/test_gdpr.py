"""Tests for GDPR data export and account deletion endpoints."""

from __future__ import annotations

import pytest
from httpx import AsyncClient

from tests.conftest import register_and_get_token


@pytest.mark.asyncio
async def test_export_user_data(client: AsyncClient):
    """Export should return structured JSON with user data."""
    headers = await register_and_get_token(client)

    response = await client.get("/auth/me/export", headers=headers)
    assert response.status_code == 200
    data = response.json()
    assert data["export_version"] == "1.0"
    assert "exported_at" in data
    assert "profile" in data
    assert data["profile"]["email"] is not None
    assert "webauthn_credentials" in data
    assert "workout_plans" in data
    assert "workout_sessions" in data
    assert "ai_vision_scans" in data
    assert "ai_coach_generations" in data


@pytest.mark.asyncio
async def test_export_unauthenticated(client: AsyncClient):
    """Export without auth should return 401/403."""
    response = await client.get("/auth/me/export")
    assert response.status_code in (401, 403)


@pytest.mark.asyncio
async def test_delete_account_success(client: AsyncClient):
    """Delete with correct password should return 204."""
    # Register user
    resp = await client.post(
        "/auth/register",
        json={
            "email": "delete-me@example.com",
            "password": "DeleteMe123",
            "name": "Delete User",
        },
    )
    assert resp.status_code == 201
    token = resp.json()["tokens"]["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # Verify profile exists
    profile_resp = await client.get("/auth/me", headers=headers)
    assert profile_resp.status_code == 200

    # Delete account
    delete_resp = await client.request(
        "DELETE",
        "/auth/me",
        headers=headers,
        json={"password": "DeleteMe123"},
    )
    assert delete_resp.status_code == 204

    # Verify account is gone (token should be invalid)
    check_resp = await client.get("/auth/me", headers=headers)
    assert check_resp.status_code == 401


@pytest.mark.asyncio
async def test_delete_account_wrong_password(client: AsyncClient):
    """Delete with wrong password should return 401."""
    headers = await register_and_get_token(client)

    response = await client.request(
        "DELETE",
        "/auth/me",
        headers=headers,
        json={"password": "WrongPassword999"},
    )
    assert response.status_code == 401
    assert "password" in response.json()["detail"].lower()


@pytest.mark.asyncio
async def test_delete_account_unauthenticated(client: AsyncClient):
    """Delete without auth should return 401/403."""
    response = await client.request(
        "DELETE",
        "/auth/me",
        json={"password": "anything"},
    )
    assert response.status_code in (401, 403)
