"""Shared test fixtures for AI service tests."""

from __future__ import annotations

import asyncio
from collections.abc import AsyncGenerator
from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, patch

import fakeredis.aioredis
import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from jose import jwt

from app.config import settings
from app.main import app

TEST_USER_ID = "550e8400-e29b-41d4-a716-446655440000"


def create_test_token(user_id: str | None = None) -> str:
    """Create a valid JWT access token for testing."""
    if user_id is None:
        user_id = TEST_USER_ID
    payload = {
        "sub": user_id,
        "exp": datetime.now(UTC) + timedelta(minutes=15),
        "iat": datetime.now(UTC),
        "type": "access",
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


@pytest.fixture(scope="session")
def event_loop():
    """Create an event loop for the test session."""
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest.fixture
def test_user_id() -> str:
    """Return a consistent test user UUID."""
    return TEST_USER_ID


@pytest.fixture
def auth_headers(test_user_id: str) -> dict:
    """Create authorization headers with a valid JWT."""
    token = create_test_token(test_user_id)
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def fake_redis():
    """Create a fakeredis instance for testing."""
    return fakeredis.aioredis.FakeRedis(decode_responses=True)


@pytest_asyncio.fixture
async def client(fake_redis) -> AsyncGenerator[AsyncClient, None]:
    """Create a test HTTP client with Redis mocked."""
    with patch("app.redis_client.get_redis", return_value=fake_redis):
        with patch(
            "app.router.get_cached_vision_result", new_callable=AsyncMock, return_value=None
        ):
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as ac:
                yield ac
