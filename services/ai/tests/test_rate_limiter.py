"""Unit tests for rate limiter."""

from __future__ import annotations

from unittest.mock import patch

import fakeredis.aioredis
import pytest

from app.rate_limiter import (
    RateLimitExceededError,
    check_coach_generate_rate,
    check_rate_limit,
    check_vision_scan_rate,
)


@pytest.fixture
def fake_redis():
    """Create a fakeredis instance."""
    return fakeredis.aioredis.FakeRedis(decode_responses=True)


@pytest.mark.asyncio
async def test_rate_limit_first_request(fake_redis):
    """First request should be allowed and return count 1."""
    with patch("app.rate_limiter.get_redis", return_value=fake_redis):
        count = await check_rate_limit("user-1", "test_op", 10, 3600)
        assert count == 1


@pytest.mark.asyncio
async def test_rate_limit_under_threshold(fake_redis):
    """Multiple requests under the limit should all succeed."""
    with patch("app.rate_limiter.get_redis", return_value=fake_redis):
        for i in range(5):
            count = await check_rate_limit("user-1", "test_op", 10, 3600)
            assert count == i + 1


@pytest.mark.asyncio
async def test_rate_limit_at_threshold(fake_redis):
    """Request at exactly the limit should succeed."""
    with patch("app.rate_limiter.get_redis", return_value=fake_redis):
        for _ in range(10):
            await check_rate_limit("user-1", "test_op", 10, 3600)

        # 11th should fail
        with pytest.raises(RateLimitExceededError):
            await check_rate_limit("user-1", "test_op", 10, 3600)


@pytest.mark.asyncio
async def test_rate_limit_different_users(fake_redis):
    """Rate limits should be per-user."""
    with patch("app.rate_limiter.get_redis", return_value=fake_redis):
        for _ in range(10):
            await check_rate_limit("user-1", "test_op", 10, 3600)

        # User 2 should still be allowed
        count = await check_rate_limit("user-2", "test_op", 10, 3600)
        assert count == 1


@pytest.mark.asyncio
async def test_rate_limit_different_operations(fake_redis):
    """Rate limits should be per-operation."""
    with patch("app.rate_limiter.get_redis", return_value=fake_redis):
        for _ in range(10):
            await check_rate_limit("user-1", "op_a", 10, 3600)

        # Same user, different operation should be allowed
        count = await check_rate_limit("user-1", "op_b", 10, 3600)
        assert count == 1


@pytest.mark.asyncio
async def test_vision_scan_rate_limit(fake_redis):
    """Vision scan rate limit should allow 10 per hour."""
    with patch("app.rate_limiter.get_redis", return_value=fake_redis):
        for _ in range(10):
            await check_vision_scan_rate("user-1")

        with pytest.raises(RateLimitExceededError):
            await check_vision_scan_rate("user-1")


@pytest.mark.asyncio
async def test_coach_generate_rate_limit(fake_redis):
    """Coach generate rate limit should allow 3 per day."""
    with patch("app.rate_limiter.get_redis", return_value=fake_redis):
        for _ in range(3):
            await check_coach_generate_rate("user-1")

        with pytest.raises(RateLimitExceededError):
            await check_coach_generate_rate("user-1")


def test_rate_limit_error_message():
    """Rate limit error should include operation and limit info."""
    exc = RateLimitExceededError("vision_scan", 10, 3600)
    assert "vision_scan" in str(exc)
    assert "10" in str(exc)
    assert exc.operation == "vision_scan"
    assert exc.limit == 10
