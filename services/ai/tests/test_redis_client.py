"""Unit tests for Redis client: jobs and cache."""

from __future__ import annotations

from unittest.mock import patch

import fakeredis.aioredis
import pytest

from app.redis_client import (
    cache_vision_result,
    compute_image_hash,
    get_cached_vision_result,
    get_job_status,
    publish_job,
    update_job_status,
)


@pytest.fixture
def fake_redis():
    """Create a fakeredis instance."""
    return fakeredis.aioredis.FakeRedis(decode_responses=True)


@pytest.mark.asyncio
async def test_publish_and_get_job(fake_redis):
    """Publishing a job should store it and make it retrievable."""
    with patch("app.redis_client.get_redis", return_value=fake_redis):
        job_id = await publish_job("vision_scan", "user-123", {"test": True})
        assert job_id is not None

        status = await get_job_status(job_id)
        assert status is not None
        assert status["job_type"] == "vision_scan"
        assert status["user_id"] == "user-123"
        assert status["status"] == "pending"


@pytest.mark.asyncio
async def test_update_job_status(fake_redis):
    """Updating job status should persist changes."""
    with patch("app.redis_client.get_redis", return_value=fake_redis):
        job_id = await publish_job("vision_scan", "user-123", {})

        await update_job_status(job_id, "processing")
        status = await get_job_status(job_id)
        assert status["status"] == "processing"

        result = {"equipment_name": "Bench Press", "confidence": 0.95}
        await update_job_status(job_id, "completed", result=result)
        status = await get_job_status(job_id)
        assert status["status"] == "completed"
        assert status["result"]["equipment_name"] == "Bench Press"


@pytest.mark.asyncio
async def test_update_job_with_error(fake_redis):
    """Failed job should store error message."""
    with patch("app.redis_client.get_redis", return_value=fake_redis):
        job_id = await publish_job("vision_scan", "user-123", {})
        await update_job_status(job_id, "failed", error="API timeout")
        status = await get_job_status(job_id)
        assert status["status"] == "failed"
        assert status["error"] == "API timeout"


@pytest.mark.asyncio
async def test_get_nonexistent_job(fake_redis):
    """Getting a nonexistent job should return None."""
    with patch("app.redis_client.get_redis", return_value=fake_redis):
        status = await get_job_status("nonexistent-id")
        assert status is None


def test_compute_image_hash():
    """Image hash should be consistent and deterministic."""
    data = b"test image data"
    hash1 = compute_image_hash(data)
    hash2 = compute_image_hash(data)
    assert hash1 == hash2
    assert len(hash1) == 64  # SHA256 hex

    different = compute_image_hash(b"different data")
    assert different != hash1


@pytest.mark.asyncio
async def test_vision_cache_roundtrip(fake_redis):
    """Caching and retrieving a vision result should work."""
    with patch("app.redis_client.get_redis", return_value=fake_redis):
        image_hash = compute_image_hash(b"test")
        result = {"equipment_name": "Leg Press", "confidence": 0.9}

        # Cache should be empty initially
        cached = await get_cached_vision_result(image_hash)
        assert cached is None

        # Cache the result
        await cache_vision_result(image_hash, result)

        # Should be retrievable
        cached = await get_cached_vision_result(image_hash)
        assert cached is not None
        assert cached["equipment_name"] == "Leg Press"
