"""Integration tests for AI coach generation endpoint."""

from __future__ import annotations

import io
import json
import uuid
from unittest.mock import AsyncMock, MagicMock, patch

import fakeredis.aioredis
import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app
from tests.conftest import TEST_USER_ID, create_test_token


@pytest.fixture
def auth_headers() -> dict:
    """Authorization headers for test user."""
    token = create_test_token(TEST_USER_ID)
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def fake_redis():
    """Create a fakeredis instance."""
    return fakeredis.aioredis.FakeRedis(decode_responses=True)


@pytest.fixture
def mock_coach_result():
    """Mock result from process_coach_generate."""
    return {
        "plan_name": "Beginner Full Body",
        "description": "A 4-week beginner program",
        "duration_weeks": 4,
        "days_per_week": 3,
        "level": "beginner",
        "days": [
            {
                "day_name": "Day 1 - Upper Body",
                "focus": "chest, shoulders, triceps",
                "exercises": [
                    {
                        "name": "Bench Press",
                        "sets": 3,
                        "reps": "8-12",
                    }
                ],
            }
        ],
        "progression_notes": "Add weight weekly",
        "nutrition_tips": "Eat protein after workout",
        "generation_id": str(uuid.uuid4()),
    }


def _build_patches(fake_redis, coach_result=None):
    """Build common patches for coach tests."""
    mock_db_session = AsyncMock()
    mock_db_session.add = MagicMock()
    mock_db_session.commit = AsyncMock()

    async def mock_get_db():
        yield mock_db_session

    patches = [
        patch("app.redis_client.get_redis", return_value=fake_redis),
        patch("app.rate_limiter.get_redis", return_value=fake_redis),
        patch("app.router.get_db", mock_get_db),
    ]

    if coach_result is not None:
        patches.append(
            patch(
                "app.router.process_coach_generate",
                new_callable=AsyncMock,
                return_value=coach_result,
            )
        )

    return patches


def _make_photo(name: str = "photo.jpg", size: int = 100) -> tuple:
    """Create a fake photo file for multipart upload."""
    data = b"\xff\xd8\xff\xe0" + b"\x00" * size
    return (name, io.BytesIO(data), "image/jpeg")


@pytest.mark.asyncio
async def test_coach_generate_success(fake_redis, auth_headers, mock_coach_result):
    """Submitting valid photos should return a workout plan."""
    patches = _build_patches(fake_redis, coach_result=mock_coach_result)

    with patches[0], patches[1], patches[2], patches[3]:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.post(
                "/ai/coach/generate",
                files=[("photos", _make_photo("front.jpg"))],
                data={"data": json.dumps({"age": 30, "goals": "muscle"})},
                headers=auth_headers,
            )
            assert response.status_code == 200
            result = response.json()
            assert result["plan_name"] == "Beginner Full Body"
            assert result["duration_weeks"] == 4
            assert len(result["days"]) == 1


@pytest.mark.asyncio
async def test_coach_generate_multiple_photos(fake_redis, auth_headers, mock_coach_result):
    """Multiple photos should be accepted."""
    patches = _build_patches(fake_redis, coach_result=mock_coach_result)

    with patches[0], patches[1], patches[2], patches[3]:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.post(
                "/ai/coach/generate",
                files=[
                    ("photos", _make_photo("front.jpg")),
                    ("photos", _make_photo("side.jpg")),
                    ("photos", _make_photo("back.jpg")),
                ],
                data={"data": "{}"},
                headers=auth_headers,
            )
            assert response.status_code == 200


@pytest.mark.asyncio
async def test_coach_generate_no_auth(fake_redis):
    """Coach generation without auth should return 401/403."""
    patches = _build_patches(fake_redis)

    with patches[0], patches[1], patches[2]:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.post(
                "/ai/coach/generate",
                files=[("photos", _make_photo())],
                data={"data": "{}"},
            )
            assert response.status_code in (401, 403)


@pytest.mark.asyncio
async def test_coach_generate_invalid_photo_type(fake_redis, auth_headers):
    """Non-image file should return 400."""
    patches = _build_patches(fake_redis)

    with patches[0], patches[1], patches[2]:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.post(
                "/ai/coach/generate",
                files=[
                    (
                        "photos",
                        ("doc.pdf", io.BytesIO(b"data"), "application/pdf"),
                    )
                ],
                data={"data": "{}"},
                headers=auth_headers,
            )
            assert response.status_code == 400
            assert "Invalid photo type" in response.json()["detail"]


@pytest.mark.asyncio
async def test_coach_generate_too_many_photos(fake_redis, auth_headers):
    """More than 5 photos should return 400."""
    patches = _build_patches(fake_redis)

    with patches[0], patches[1], patches[2]:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.post(
                "/ai/coach/generate",
                files=[("photos", _make_photo(f"p{i}.jpg")) for i in range(6)],
                data={"data": "{}"},
                headers=auth_headers,
            )
            assert response.status_code == 400
            assert "Maximum" in response.json()["detail"]


@pytest.mark.asyncio
async def test_coach_generate_invalid_json_data(fake_redis, auth_headers):
    """Invalid JSON in data field should return 400."""
    patches = _build_patches(fake_redis)

    with patches[0], patches[1], patches[2]:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.post(
                "/ai/coach/generate",
                files=[("photos", _make_photo())],
                data={"data": "not valid json{"},
                headers=auth_headers,
            )
            assert response.status_code == 400
            assert "Invalid JSON" in response.json()["detail"]


@pytest.mark.asyncio
async def test_coach_generate_empty_photo(fake_redis, auth_headers):
    """Empty photo file should return 400."""
    patches = _build_patches(fake_redis)

    with patches[0], patches[1], patches[2]:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.post(
                "/ai/coach/generate",
                files=[("photos", ("empty.jpg", io.BytesIO(b""), "image/jpeg"))],
                data={"data": "{}"},
                headers=auth_headers,
            )
            assert response.status_code == 400
            assert "Empty" in response.json()["detail"]


@pytest.mark.asyncio
async def test_coach_generate_rate_limited(fake_redis, auth_headers):
    """Coach generation should return 429 when rate limit exceeded."""
    from app.rate_limiter import RateLimitExceededError

    patches = _build_patches(fake_redis)

    with patches[0], patches[1], patches[2]:
        with patch(
            "app.router.check_coach_generate_rate",
            new_callable=AsyncMock,
            side_effect=RateLimitExceededError("coach_generate", 3, 86400),
        ):
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as client:
                response = await client.post(
                    "/ai/coach/generate",
                    files=[("photos", _make_photo())],
                    data={"data": "{}"},
                    headers=auth_headers,
                )
                assert response.status_code == 429


@pytest.mark.asyncio
async def test_coach_generate_insufficient_credits(fake_redis, auth_headers):
    """Coach generation should return 402 when credits insufficient."""
    from app.service import InsufficientCreditsError

    patches = _build_patches(fake_redis)

    with patches[0], patches[1], patches[2]:
        with patch(
            "app.router.process_coach_generate",
            new_callable=AsyncMock,
            side_effect=InsufficientCreditsError(),
        ):
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as client:
                response = await client.post(
                    "/ai/coach/generate",
                    files=[("photos", _make_photo())],
                    data={"data": "{}"},
                    headers=auth_headers,
                )
                assert response.status_code == 402


@pytest.mark.asyncio
async def test_coach_history_empty(fake_redis, auth_headers):
    """Coach history for new user should return empty list."""
    history_result = {
        "items": [],
        "total": 0,
        "page": 1,
        "per_page": 20,
        "pages": 0,
    }

    mock_db_session = AsyncMock()

    async def mock_get_db():
        yield mock_db_session

    with (
        patch("app.redis_client.get_redis", return_value=fake_redis),
        patch("app.rate_limiter.get_redis", return_value=fake_redis),
        patch("app.router.get_db", mock_get_db),
        patch(
            "app.router.get_coach_history",
            new_callable=AsyncMock,
            return_value=history_result,
        ),
    ):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.get(
                "/ai/coach/history",
                headers=auth_headers,
            )
            assert response.status_code == 200
            data = response.json()
            assert data["total"] == 0
            assert data["items"] == []
