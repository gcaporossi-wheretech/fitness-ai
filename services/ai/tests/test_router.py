"""Integration tests for AI service API endpoints."""

from __future__ import annotations

import io
import uuid
from unittest.mock import AsyncMock, patch

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


@pytest.mark.asyncio
async def test_vision_scan_submit(fake_redis, auth_headers):
    """Submitting a vision scan should return a job_id."""
    with patch("app.redis_client.get_redis", return_value=fake_redis):
        with patch(
            "app.router.get_cached_vision_result", new_callable=AsyncMock, return_value=None
        ):
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as client:
                image_data = b"fake image data for testing"
                response = await client.post(
                    "/ai/vision/scan",
                    files={"image": ("test.jpg", io.BytesIO(image_data), "image/jpeg")},
                    headers=auth_headers,
                )
                assert response.status_code == 200
                data = response.json()
                assert "job_id" in data
                assert data["status"] == "pending"


@pytest.mark.asyncio
async def test_vision_scan_cached(fake_redis, auth_headers):
    """Vision scan with cached result should return completed immediately."""
    cached_result = {"equipment_name": "Bench Press", "confidence": 0.95}
    with patch("app.redis_client.get_redis", return_value=fake_redis):
        with patch(
            "app.router.get_cached_vision_result",
            new_callable=AsyncMock,
            return_value=cached_result,
        ):
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as client:
                response = await client.post(
                    "/ai/vision/scan",
                    files={"image": ("test.jpg", io.BytesIO(b"cached image"), "image/jpeg")},
                    headers=auth_headers,
                )
                assert response.status_code == 200
                data = response.json()
                assert data["status"] == "completed"


@pytest.mark.asyncio
async def test_vision_scan_no_auth(fake_redis):
    """Vision scan without auth should return 401."""
    with patch("app.redis_client.get_redis", return_value=fake_redis):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.post(
                "/ai/vision/scan",
                files={"image": ("test.jpg", io.BytesIO(b"data"), "image/jpeg")},
            )
            assert response.status_code in (401, 403)


@pytest.mark.asyncio
async def test_coach_generate_submit(fake_redis, auth_headers):
    """Submitting a coach generation should return a job_id."""
    with patch("app.redis_client.get_redis", return_value=fake_redis):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.post("/ai/coach/generate", headers=auth_headers)
            assert response.status_code == 200
            data = response.json()
            assert "job_id" in data
            assert data["status"] == "pending"


@pytest.mark.asyncio
async def test_get_job_status(fake_redis, auth_headers):
    """Getting a submitted job should return its status."""
    with patch("app.redis_client.get_redis", return_value=fake_redis):
        with patch(
            "app.router.get_cached_vision_result", new_callable=AsyncMock, return_value=None
        ):
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as client:
                # Submit a job
                submit = await client.post("/ai/coach/generate", headers=auth_headers)
                job_id = submit.json()["job_id"]

                # Check status
                response = await client.get(f"/ai/jobs/{job_id}", headers=auth_headers)
                assert response.status_code == 200
                data = response.json()
                assert data["job_id"] == job_id
                assert data["status"] == "pending"
                assert data["job_type"] == "coach_generate"


@pytest.mark.asyncio
async def test_get_job_not_found(fake_redis, auth_headers):
    """Getting a nonexistent job should return 404."""
    with patch("app.redis_client.get_redis", return_value=fake_redis):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.get(f"/ai/jobs/{uuid.uuid4()}", headers=auth_headers)
            assert response.status_code == 404


@pytest.mark.asyncio
async def test_get_job_other_user(fake_redis):
    """Getting another user's job should return 404."""
    with patch("app.redis_client.get_redis", return_value=fake_redis):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            # Submit as user A
            user_a = str(uuid.uuid4())
            headers_a = {"Authorization": f"Bearer {create_test_token(user_a)}"}
            submit = await client.post("/ai/coach/generate", headers=headers_a)
            job_id = submit.json()["job_id"]

            # Try to access as user B
            user_b = str(uuid.uuid4())
            headers_b = {"Authorization": f"Bearer {create_test_token(user_b)}"}
            response = await client.get(f"/ai/jobs/{job_id}", headers=headers_b)
            assert response.status_code == 404
