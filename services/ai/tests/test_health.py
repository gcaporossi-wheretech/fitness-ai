"""Tests for AI service health check endpoint."""

from __future__ import annotations

from unittest.mock import AsyncMock, patch

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app


@pytest.mark.asyncio
async def test_health_check_redis_ok():
    """Health check should return ok when Redis is reachable."""
    with patch("app.redis_client.check_redis_health", new_callable=AsyncMock, return_value=True):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.get("/health")
            assert response.status_code == 200
            data = response.json()
            assert data["status"] == "ok"
            assert data["service"] == "ai"
            assert data["redis"] == "ok"


@pytest.mark.asyncio
async def test_health_check_redis_down():
    """Health check should return degraded when Redis is unreachable."""
    with patch("app.redis_client.check_redis_health", new_callable=AsyncMock, return_value=False):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.get("/health")
            assert response.status_code == 200
            data = response.json()
            assert data["status"] == "degraded"
            assert data["redis"] == "unavailable"
