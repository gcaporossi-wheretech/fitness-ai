"""Tests for credits management endpoints."""

from __future__ import annotations

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app
from app.service import AuthService, InsufficientCreditsError
from tests.conftest import register_and_get_token


@pytest.mark.asyncio
async def test_get_credits_unauthenticated():
    """GET /auth/credits without token returns 401."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/auth/credits")
        assert response.status_code == 401


@pytest.mark.asyncio
async def test_deduct_credits_unauthenticated():
    """POST /auth/credits/deduct without token returns 401."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post("/auth/credits/deduct")
        assert response.status_code == 401


@pytest.mark.asyncio
async def test_deduct_credits_success(client: AsyncClient):
    """Deducting credits should reduce balance by 1."""
    headers = await register_and_get_token(client)

    # Check initial credits (default = 10)
    resp = await client.get("/auth/credits", headers=headers)
    assert resp.status_code == 200
    initial = resp.json()["credits"]
    assert initial == 10

    # Deduct one credit
    deduct_resp = await client.post("/auth/credits/deduct", headers=headers)
    assert deduct_resp.status_code == 200
    assert deduct_resp.json()["credits"] == initial - 1


@pytest.mark.asyncio
async def test_deduct_credits_insufficient(client: AsyncClient):
    """Deducting more credits than available should return 402."""
    headers = await register_and_get_token(client)

    # Deduct all 10 credits
    for _ in range(10):
        resp = await client.post("/auth/credits/deduct", headers=headers)
        assert resp.status_code == 200

    # 11th deduction should fail
    resp = await client.post("/auth/credits/deduct", headers=headers)
    assert resp.status_code == 402
    assert "credits" in resp.json()["detail"].lower()


@pytest.mark.asyncio
async def test_add_and_deduct_credits_service_layer(test_db):
    """Service-level test for add_credits and deduct_credits."""
    service = AuthService(test_db)

    # Register a user
    user, _, _ = await service.register(
        email="credits-svc@example.com",
        password="TestPass123",
        name="Credits Test",
        language="en",
    )
    assert user.ai_credits == 10

    # Add credits
    new_balance = await service.add_credits(user.id, 5)
    assert new_balance == 15

    # Deduct credits
    remaining = await service.deduct_credits(user.id, 3)
    assert remaining == 12

    # Deduct all remaining
    remaining = await service.deduct_credits(user.id, 12)
    assert remaining == 0

    # Insufficient credits should raise
    with pytest.raises(InsufficientCreditsError):
        await service.deduct_credits(user.id, 1)
