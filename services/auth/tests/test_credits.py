"""Tests for credits management endpoints."""

from __future__ import annotations

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app


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
