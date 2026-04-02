"""Integration tests for auth API endpoints."""

from __future__ import annotations

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_register_success(client: AsyncClient):
    """Registration with valid data should return user and tokens."""
    response = await client.post(
        "/auth/register",
        json={
            "email": "test@example.com",
            "password": "TestPass123",
            "name": "Test User",
            "language": "en",
        },
    )
    assert response.status_code == 201
    data = response.json()
    assert data["user"]["email"] == "test@example.com"
    assert data["user"]["name"] == "Test User"
    assert data["user"]["ai_credits"] == 10
    assert "access_token" in data["tokens"]
    assert "refresh_token" in data["tokens"]


@pytest.mark.asyncio
async def test_register_duplicate_email(client: AsyncClient):
    """Registration with existing email should return 409."""
    await client.post(
        "/auth/register",
        json={
            "email": "dup@example.com",
            "password": "TestPass123",
        },
    )
    response = await client.post(
        "/auth/register",
        json={
            "email": "dup@example.com",
            "password": "TestPass456",
        },
    )
    assert response.status_code == 409


@pytest.mark.asyncio
async def test_register_weak_password(client: AsyncClient):
    """Registration with password missing digits should return 422."""
    response = await client.post(
        "/auth/register",
        json={
            "email": "weak@example.com",
            "password": "nodigits",
        },
    )
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_register_short_password(client: AsyncClient):
    """Registration with password under 8 chars should return 422."""
    response = await client.post(
        "/auth/register",
        json={
            "email": "short@example.com",
            "password": "Ab1",
        },
    )
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_login_success(client: AsyncClient):
    """Login with correct credentials should return tokens."""
    await client.post(
        "/auth/register",
        json={
            "email": "login@example.com",
            "password": "TestPass123",
        },
    )
    response = await client.post(
        "/auth/login",
        json={
            "email": "login@example.com",
            "password": "TestPass123",
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data["tokens"]


@pytest.mark.asyncio
async def test_login_wrong_password(client: AsyncClient):
    """Login with wrong password should return 401."""
    await client.post(
        "/auth/register",
        json={
            "email": "wrongpw@example.com",
            "password": "TestPass123",
        },
    )
    response = await client.post(
        "/auth/login",
        json={
            "email": "wrongpw@example.com",
            "password": "WrongPass456",
        },
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_login_nonexistent_email(client: AsyncClient):
    """Login with unregistered email should return 401."""
    response = await client.post(
        "/auth/login",
        json={
            "email": "nobody@example.com",
            "password": "TestPass123",
        },
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_get_profile_authenticated(client: AsyncClient):
    """GET /auth/me with valid token should return user profile."""
    reg = await client.post(
        "/auth/register",
        json={
            "email": "profile@example.com",
            "password": "TestPass123",
            "name": "Profile User",
        },
    )
    token = reg.json()["tokens"]["access_token"]
    response = await client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    assert response.json()["email"] == "profile@example.com"


@pytest.mark.asyncio
async def test_get_profile_no_auth(client: AsyncClient):
    """GET /auth/me without token should return 401 or 403."""
    response = await client.get("/auth/me")
    assert response.status_code in (401, 403)


@pytest.mark.asyncio
async def test_update_profile(client: AsyncClient):
    """PATCH /auth/me should update provided fields only."""
    reg = await client.post(
        "/auth/register",
        json={
            "email": "update@example.com",
            "password": "TestPass123",
        },
    )
    token = reg.json()["tokens"]["access_token"]
    response = await client.patch(
        "/auth/me",
        json={"name": "Updated Name", "age": 57},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "Updated Name"
    assert data["age"] == 57


@pytest.mark.asyncio
async def test_refresh_token_flow(client: AsyncClient):
    """Refresh token should return new token pair and invalidate old refresh token."""
    reg = await client.post(
        "/auth/register",
        json={
            "email": "refresh@example.com",
            "password": "TestPass123",
        },
    )
    refresh_token = reg.json()["tokens"]["refresh_token"]

    response = await client.post(
        "/auth/refresh",
        json={
            "refresh_token": refresh_token,
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["refresh_token"] != refresh_token  # Token rotation

    # Old refresh token should no longer work
    response2 = await client.post(
        "/auth/refresh",
        json={
            "refresh_token": refresh_token,
        },
    )
    assert response2.status_code == 401


@pytest.mark.asyncio
async def test_get_credits(client: AsyncClient):
    """GET /auth/credits should return initial credits balance."""
    reg = await client.post(
        "/auth/register",
        json={
            "email": "credits@example.com",
            "password": "TestPass123",
        },
    )
    token = reg.json()["tokens"]["access_token"]
    response = await client.get("/auth/credits", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    assert response.json()["credits"] == 10
