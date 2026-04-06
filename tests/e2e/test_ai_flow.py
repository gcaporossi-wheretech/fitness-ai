"""E2E test: AI service flows.

Tests: vision scan (mocked Claude) -> check history.
       coach generate (mocked Claude) -> check history.
"""

from __future__ import annotations

import io
import sys
from datetime import UTC, datetime, timedelta
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

import fakeredis.aioredis
import pytest
from jose import jwt

# Remove any workouts path entries to avoid conftest conflicts
sys.path = [p for p in sys.path if "workouts" not in p]

# Add AI service to path
AI_SERVICE_PATH = str(Path(__file__).parent.parent.parent / "services" / "ai")
if AI_SERVICE_PATH not in sys.path:
    sys.path.insert(0, AI_SERVICE_PATH)

from app.main import app  # noqa: E402
from app.config import settings as ai_settings  # noqa: E402

TEST_USER_ID = "550e8400-e29b-41d4-a716-446655440000"


def create_test_token(user_id: str = TEST_USER_ID) -> str:
    """Create a valid JWT token for testing."""
    payload = {
        "sub": user_id,
        "exp": datetime.now(UTC) + timedelta(minutes=15),
        "iat": datetime.now(UTC),
        "type": "access",
    }
    return jwt.encode(
        payload, ai_settings.jwt_secret, algorithm=ai_settings.jwt_algorithm
    )


@pytest.fixture
def fake_redis():
    """Create a fakeredis instance."""
    return fakeredis.aioredis.FakeRedis(decode_responses=True)


@pytest.fixture
def auth_headers():
    """Authorization headers."""
    token = create_test_token(TEST_USER_ID)
    return {"Authorization": f"Bearer {token}"}


@pytest.mark.asyncio
async def test_vision_scan_and_history(fake_redis, auth_headers):
    """E2E: scan equipment -> check result -> view history."""
    mock_vision_result = {
        "equipment_name": "Lat Pulldown",
        "brand": "Life Fitness",
        "confidence": 0.92,
        "exercises": [
            {
                "name": "Lat Pulldown",
                "muscle_groups": ["lats", "biceps"],
                "difficulty": "beginner",
            }
        ],
        "cached": False,
        "scan_id": "e2e-scan-001",
    }

    mock_db_session = AsyncMock()
    mock_db_session.add = MagicMock()
    mock_db_session.commit = AsyncMock()

    async def mock_get_db():
        yield mock_db_session

    from httpx import ASGITransport, AsyncClient

    with (
        patch("app.redis_client.get_redis", return_value=fake_redis),
        patch("app.rate_limiter.get_redis", return_value=fake_redis),
        patch("app.router.get_db", mock_get_db),
        patch(
            "app.router.process_vision_scan",
            new_callable=AsyncMock,
            return_value=mock_vision_result,
        ),
    ):
        transport = ASGITransport(app=app)
        async with AsyncClient(
            transport=transport, base_url="http://test"
        ) as client:
            # 1. Scan equipment
            image_data = b"\xff\xd8\xff\xe0" + b"\x00" * 100
            scan_resp = await client.post(
                "/ai/vision/scan",
                files={
                    "image": ("equip.jpg", io.BytesIO(image_data), "image/jpeg")
                },
                headers=auth_headers,
            )
            assert scan_resp.status_code == 200
            result = scan_resp.json()
            assert result["equipment_name"] == "Lat Pulldown"
            assert len(result["exercises"]) == 1


@pytest.mark.asyncio
async def test_coach_generate_and_history(fake_redis, auth_headers):
    """E2E: submit photos + data -> generate plan -> check result."""
    mock_coach_result = {
        "plan_name": "E2E Beginner Plan",
        "description": "4-week plan for testing",
        "duration_weeks": 4,
        "days_per_week": 3,
        "level": "beginner",
        "days": [
            {
                "day_name": "Day 1 - Full Body",
                "exercises": [{"name": "Squat", "sets": 3, "reps": "10"}],
            }
        ],
        "progression_notes": "Increase weight weekly",
        "generation_id": "e2e-gen-001",
    }

    mock_db_session = AsyncMock()
    mock_db_session.add = MagicMock()
    mock_db_session.commit = AsyncMock()

    async def mock_get_db():
        yield mock_db_session

    from httpx import ASGITransport, AsyncClient

    with (
        patch("app.redis_client.get_redis", return_value=fake_redis),
        patch("app.rate_limiter.get_redis", return_value=fake_redis),
        patch("app.router.get_db", mock_get_db),
        patch(
            "app.router.process_coach_generate",
            new_callable=AsyncMock,
            return_value=mock_coach_result,
        ),
    ):
        transport = ASGITransport(app=app)
        async with AsyncClient(
            transport=transport, base_url="http://test"
        ) as client:
            # 1. Generate plan
            photo_data = b"\xff\xd8\xff\xe0" + b"\x00" * 50
            gen_resp = await client.post(
                "/ai/coach/generate",
                files=[
                    ("photos", ("front.jpg", io.BytesIO(photo_data), "image/jpeg")),
                ],
                data={"data": '{"age": 30, "goals": "muscle_gain"}'},
                headers=auth_headers,
            )
            assert gen_resp.status_code == 200
            plan = gen_resp.json()
            assert plan["plan_name"] == "E2E Beginner Plan"
            assert plan["duration_weeks"] == 4
            assert len(plan["days"]) == 1
