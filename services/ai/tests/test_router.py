"""Integration tests for AI service API endpoints."""

from __future__ import annotations

import io
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
def mock_vision_result():
    """Mock result from process_vision_scan."""
    return {
        "equipment_name": "Bench Press",
        "brand": "Technogym",
        "confidence": 0.95,
        "exercises": [
            {
                "name": "Flat Bench Press",
                "name_it": "Panca Piana",
                "muscle_groups": ["chest", "triceps"],
                "difficulty": "intermediate",
                "description": "Press barbell from chest.",
            }
        ],
        "cached": False,
        "scan_id": str(uuid.uuid4()),
    }


def _build_patches(fake_redis, vision_result=None, history_result=None):
    """Build common patches for router tests."""
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

    if vision_result is not None:
        patches.append(
            patch(
                "app.router.process_vision_scan",
                new_callable=AsyncMock,
                return_value=vision_result,
            )
        )

    if history_result is not None:
        patches.append(
            patch(
                "app.router.get_vision_history",
                new_callable=AsyncMock,
                return_value=history_result,
            )
        )

    return patches


@pytest.mark.asyncio
async def test_vision_scan_success(fake_redis, auth_headers, mock_vision_result):
    """Submitting a valid vision scan should return equipment data."""
    patches = _build_patches(fake_redis, vision_result=mock_vision_result)

    with patches[0], patches[1], patches[2], patches[3]:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            image_data = b"\xff\xd8\xff\xe0" + b"\x00" * 100  # JPEG header
            response = await client.post(
                "/ai/vision/scan",
                files={"image": ("test.jpg", io.BytesIO(image_data), "image/jpeg")},
                headers=auth_headers,
            )
            assert response.status_code == 200
            data = response.json()
            assert data["equipment_name"] == "Bench Press"
            assert abs(data["confidence"] - 0.95) < 1e-9
            assert len(data["exercises"]) == 1


@pytest.mark.asyncio
async def test_vision_scan_invalid_content_type(fake_redis, auth_headers):
    """Submitting a non-image file should return 400."""
    patches = _build_patches(fake_redis)

    with patches[0], patches[1], patches[2]:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.post(
                "/ai/vision/scan",
                files={"image": ("test.pdf", io.BytesIO(b"data"), "application/pdf")},
                headers=auth_headers,
            )
            assert response.status_code == 400
            assert "Invalid image type" in response.json()["detail"]


@pytest.mark.asyncio
async def test_vision_scan_empty_file(fake_redis, auth_headers):
    """Submitting an empty image should return 400."""
    patches = _build_patches(fake_redis)

    with patches[0], patches[1], patches[2]:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.post(
                "/ai/vision/scan",
                files={"image": ("test.jpg", io.BytesIO(b""), "image/jpeg")},
                headers=auth_headers,
            )
            assert response.status_code == 400
            assert "Empty" in response.json()["detail"]


@pytest.mark.asyncio
async def test_vision_scan_too_large(fake_redis, auth_headers):
    """Submitting an oversized image should return 413."""
    patches = _build_patches(fake_redis)

    with patches[0], patches[1], patches[2]:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            # 11 MB file
            big_data = b"\x00" * (11 * 1024 * 1024)
            response = await client.post(
                "/ai/vision/scan",
                files={"image": ("big.jpg", io.BytesIO(big_data), "image/jpeg")},
                headers=auth_headers,
            )
            assert response.status_code == 413


@pytest.mark.asyncio
async def test_vision_scan_no_auth(fake_redis):
    """Vision scan without auth should return 401/403."""
    patches = _build_patches(fake_redis)

    with patches[0], patches[1], patches[2]:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.post(
                "/ai/vision/scan",
                files={"image": ("test.jpg", io.BytesIO(b"data"), "image/jpeg")},
            )
            assert response.status_code in (401, 403)


@pytest.mark.asyncio
async def test_vision_scan_rate_limited(fake_redis, auth_headers):
    """Vision scan should return 429 when rate limit exceeded."""
    from app.rate_limiter import RateLimitExceededError

    patches = _build_patches(fake_redis)

    with patches[0], patches[1], patches[2]:
        with patch(
            "app.router.check_vision_scan_rate",
            new_callable=AsyncMock,
            side_effect=RateLimitExceededError("vision_scan", 10, 3600),
        ):
            transport = ASGITransport(app=app)
            async with AsyncClient(
                transport=transport, base_url="http://test"
            ) as client:
                response = await client.post(
                    "/ai/vision/scan",
                    files={
                        "image": (
                            "test.jpg",
                            io.BytesIO(b"\xff\xd8" + b"\x00" * 10),
                            "image/jpeg",
                        )
                    },
                    headers=auth_headers,
                )
                assert response.status_code == 429


@pytest.mark.asyncio
async def test_vision_scan_insufficient_credits(fake_redis, auth_headers):
    """Vision scan should return 402 when credits are insufficient."""
    from app.service import InsufficientCreditsError

    patches = _build_patches(fake_redis)

    with patches[0], patches[1], patches[2]:
        with patch(
            "app.router.process_vision_scan",
            new_callable=AsyncMock,
            side_effect=InsufficientCreditsError(),
        ):
            transport = ASGITransport(app=app)
            async with AsyncClient(
                transport=transport, base_url="http://test"
            ) as client:
                response = await client.post(
                    "/ai/vision/scan",
                    files={
                        "image": (
                            "test.jpg",
                            io.BytesIO(b"\xff\xd8" + b"\x00" * 10),
                            "image/jpeg",
                        )
                    },
                    headers=auth_headers,
                )
                assert response.status_code == 402


@pytest.mark.asyncio
async def test_vision_history_empty(fake_redis, auth_headers):
    """Vision history for new user should return empty list."""
    history_result = {"items": [], "total": 0, "page": 1, "per_page": 20, "pages": 0}
    patches = _build_patches(fake_redis, history_result=history_result)

    with patches[0], patches[1], patches[2], patches[3]:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.get(
                "/ai/vision/history",
                headers=auth_headers,
            )
            assert response.status_code == 200
            data = response.json()
            assert data["total"] == 0
            assert data["items"] == []


@pytest.mark.asyncio
async def test_vision_history_with_items(fake_redis, auth_headers):
    """Vision history should return paginated items."""
    history_result = {
        "items": [
            {
                "id": str(uuid.uuid4()),
                "image_hash": "abc123",
                "equipment_name": "Leg Press",
                "equipment_brand": None,
                "exercises": [{"name": "Leg Press"}],
                "credits_used": 1,
                "error": None,
                "created_at": "2026-04-06T10:00:00+00:00",
            }
        ],
        "total": 1,
        "page": 1,
        "per_page": 20,
        "pages": 1,
    }
    patches = _build_patches(fake_redis, history_result=history_result)

    with patches[0], patches[1], patches[2], patches[3]:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.get(
                "/ai/vision/history",
                headers=auth_headers,
            )
            assert response.status_code == 200
            data = response.json()
            assert data["total"] == 1
            assert data["items"][0]["equipment_name"] == "Leg Press"


@pytest.mark.asyncio
async def test_get_job_status(fake_redis, auth_headers):
    """Getting a submitted job should return its status."""
    from app.redis_client import publish_job

    with (
        patch("app.redis_client.get_redis", return_value=fake_redis),
        patch("app.rate_limiter.get_redis", return_value=fake_redis),
    ):
        # Publish a test job
        job_id = await publish_job("vision_scan", TEST_USER_ID, {"test": True})

        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.get(f"/ai/jobs/{job_id}", headers=auth_headers)
            assert response.status_code == 200
            data = response.json()
            assert data["job_id"] == job_id
            assert data["status"] == "pending"


@pytest.mark.asyncio
async def test_get_job_not_found(fake_redis, auth_headers):
    """Getting a nonexistent job should return 404."""
    with (
        patch("app.redis_client.get_redis", return_value=fake_redis),
        patch("app.rate_limiter.get_redis", return_value=fake_redis),
    ):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.get(
                f"/ai/jobs/{uuid.uuid4()}", headers=auth_headers
            )
            assert response.status_code == 404


@pytest.mark.asyncio
async def test_get_job_other_user(fake_redis):
    """Getting another user's job should return 404."""
    from app.redis_client import publish_job

    with (
        patch("app.redis_client.get_redis", return_value=fake_redis),
        patch("app.rate_limiter.get_redis", return_value=fake_redis),
    ):
        # Submit as user A
        user_a = str(uuid.uuid4())
        job_id = await publish_job("vision_scan", user_a, {"test": True})

        # Try to access as user B
        user_b = str(uuid.uuid4())
        headers_b = {"Authorization": f"Bearer {create_test_token(user_b)}"}

        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.get(f"/ai/jobs/{job_id}", headers=headers_b)
            assert response.status_code == 404


@pytest.mark.asyncio
async def test_health_check(fake_redis):
    """Health check should return service status."""
    with patch("app.redis_client.get_redis", return_value=fake_redis):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.get("/health")
            assert response.status_code == 200
            data = response.json()
            assert data["service"] == "ai"
            assert "status" in data
