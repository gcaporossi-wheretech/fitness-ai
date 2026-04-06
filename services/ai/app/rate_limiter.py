"""Application-level rate limiting for AI endpoints using Redis.

Traefik handles global rate limiting; this adds per-user, per-endpoint limits
for expensive AI operations.
"""

from __future__ import annotations

import logging

from app.redis_client import get_redis

logger = logging.getLogger(__name__)

# Rate limit windows
VISION_SCAN_LIMIT = 10  # max scans per window
VISION_SCAN_WINDOW = 3600  # 1 hour in seconds

COACH_GENERATE_LIMIT = 3  # max generations per window
COACH_GENERATE_WINDOW = 86400  # 24 hours in seconds


class RateLimitExceededError(Exception):
    """Raised when a user exceeds the rate limit for an AI operation."""

    def __init__(self, operation: str, limit: int, window_seconds: int) -> None:
        self.operation = operation
        self.limit = limit
        self.window_seconds = window_seconds
        if window_seconds >= 3600:
            window_human = f"{window_seconds // 3600}h"
        else:
            window_human = f"{window_seconds // 60}m"
        super().__init__(
            f"Rate limit exceeded for {operation}: max {limit} per {window_human}"
        )


async def check_rate_limit(
    user_id: str,
    operation: str,
    limit: int,
    window_seconds: int,
) -> int:
    """Check and increment the rate limit counter for a user operation.

    Uses a Redis key with TTL for sliding window rate limiting.

    Args:
        user_id: User UUID string.
        operation: Operation name (e.g., 'vision_scan', 'coach_generate').
        limit: Maximum number of operations allowed in the window.
        window_seconds: Window duration in seconds.

    Returns:
        Current count after increment.

    Raises:
        RateLimitExceededError: If the user has exceeded the limit.
    """
    client = await get_redis()
    key = f"ai:ratelimit:{operation}:{user_id}"

    current = await client.get(key)
    if current is not None and int(current) >= limit:
        logger.warning(
            "Rate limit exceeded: user=%s operation=%s count=%s limit=%d",
            user_id,
            operation,
            current,
            limit,
        )
        raise RateLimitExceededError(operation, limit, window_seconds)

    pipe = client.pipeline()
    pipe.incr(key)
    pipe.expire(key, window_seconds)
    results = await pipe.execute()
    count = results[0]

    if count > limit:
        # Race condition: another request incremented between check and incr
        raise RateLimitExceededError(operation, limit, window_seconds)

    return count


async def check_vision_scan_rate(user_id: str) -> int:
    """Check rate limit for vision scan (10 per hour).

    Args:
        user_id: User UUID string.

    Returns:
        Current usage count.

    Raises:
        RateLimitExceededError: If limit exceeded.
    """
    return await check_rate_limit(
        user_id, "vision_scan", VISION_SCAN_LIMIT, VISION_SCAN_WINDOW
    )


async def check_coach_generate_rate(user_id: str) -> int:
    """Check rate limit for coach generation (3 per day).

    Args:
        user_id: User UUID string.

    Returns:
        Current usage count.

    Raises:
        RateLimitExceededError: If limit exceeded.
    """
    return await check_rate_limit(
        user_id, "coach_generate", COACH_GENERATE_LIMIT, COACH_GENERATE_WINDOW
    )
