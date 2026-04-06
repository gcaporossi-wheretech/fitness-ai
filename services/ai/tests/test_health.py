"""Tests for AI service health check endpoint."""

from __future__ import annotations

from unittest.mock import AsyncMock, patch

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app


@pytest.mark.asyncio
async def test_health_check_all_ok():
    """Health check should return ok when Redis and API key are available."""
    with (
        patch("app.redis_client.check_redis_health", new_callable=AsyncMock, return_value=True),
        patch("app.main.settings") as mock_settings,
    ):
        mock_settings.anthropic_api_key = "sk-ant-test-key"
        mock_settings.service_name = "ai"
        mock_settings.app_version = "0.1.0"
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.get("/health")
            assert response.status_code == 200
            data = response.json()
            assert data["status"] == "ok"
            assert data["service"] == "ai"
            assert data["redis"] == "ok"
            assert data["claude_api"] == "configured"


@pytest.mark.asyncio
async def test_health_check_redis_ok_no_api_key():
    """Health check should return degraded when API key missing but Redis ok."""
    with (
        patch("app.redis_client.check_redis_health", new_callable=AsyncMock, return_value=True),
        patch("app.main.settings") as mock_settings,
    ):
        mock_settings.anthropic_api_key = ""
        mock_settings.service_name = "ai"
        mock_settings.app_version = "0.1.0"
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.get("/health")
            assert response.status_code == 200
            data = response.json()
            assert data["status"] == "degraded"
            assert data["redis"] == "ok"
            assert data["claude_api"] == "not_configured"


@pytest.mark.asyncio
async def test_health_check_redis_down():
    """Health check should return unhealthy when Redis is unreachable."""
    with (
        patch("app.redis_client.check_redis_health", new_callable=AsyncMock, return_value=False),
        patch("app.main.settings") as mock_settings,
    ):
        mock_settings.anthropic_api_key = "sk-ant-test-key"
        mock_settings.service_name = "ai"
        mock_settings.app_version = "0.1.0"
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.get("/health")
            assert response.status_code == 200
            data = response.json()
            assert data["status"] == "unhealthy"
            assert data["redis"] == "unavailable"
