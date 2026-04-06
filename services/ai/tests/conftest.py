"""Shared test fixtures for AI service tests."""

from __future__ import annotations

import asyncio
from collections.abc import AsyncGenerator
from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, MagicMock, patch

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
def auth_token(test_user_id: str) -> str:
    """Return a valid JWT token for testing."""
    return create_test_token(test_user_id)


@pytest.fixture
def fake_redis():
    """Create a fakeredis instance for testing."""
    return fakeredis.aioredis.FakeRedis(decode_responses=True)


@pytest.fixture
def mock_db():
    """Create a mock database session."""
    db = AsyncMock()
    db.add = MagicMock()
    db.commit = AsyncMock()
    db.refresh = AsyncMock()
    db.execute = AsyncMock()
    return db


@pytest.fixture
def mock_claude_vision_response():
    """Standard mock response for vision scan."""
    return {
        "equipment_name": "Bench Press",
        "brand": "Technogym",
        "confidence": 0.95,
        "exercises": [
            {
                "name": "Flat Bench Press",
                "name_it": "Panca Piana",
                "muscle_groups": ["chest", "triceps", "anterior deltoid"],
                "difficulty": "intermediate",
                "description": "Press the barbell upward from chest level.",
            },
            {
                "name": "Close-Grip Bench Press",
                "name_it": "Panca Presa Stretta",
                "muscle_groups": ["triceps", "chest"],
                "difficulty": "intermediate",
                "description": "Narrow grip bench press targeting triceps.",
            },
        ],
    }


@pytest_asyncio.fixture
async def client(fake_redis) -> AsyncGenerator[AsyncClient, None]:
    """Create a test HTTP client with Redis and DB mocked."""
    mock_db_session = AsyncMock()
    mock_db_session.add = MagicMock()
    mock_db_session.commit = AsyncMock()

    async def mock_get_db():
        yield mock_db_session

    with (
        patch("app.redis_client.get_redis", return_value=fake_redis),
        patch("app.rate_limiter.get_redis", return_value=fake_redis),
        patch("app.database.get_db", mock_get_db),
        patch("app.router.get_db", mock_get_db),
    ):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            yield ac
