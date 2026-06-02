"""Redis client for AI service: cache and job queue via Redis Streams."""

from __future__ import annotations

import hashlib
import json
import uuid
from datetime import UTC, datetime

import redis.asyncio as redis

from app.config import settings

# Singleton Redis connection pool
_pool: redis.ConnectionPool | None = None


async def get_redis() -> redis.Redis:
    """Get a Redis client instance using a shared connection pool.

    Returns:
        Redis client connected to the configured Redis URL.
    """
    global _pool  # noqa: PLW0603
    if _pool is None:
        _pool = redis.ConnectionPool.from_url(settings.redis_url, decode_responses=True)
    return redis.Redis(connection_pool=_pool)


async def check_redis_health() -> bool:
    """Check if Redis is reachable.

    Returns:
        True if Redis responds to PING, False otherwise.
    """
    try:
        client = await get_redis()
        return await client.ping()
    except Exception:
        return False


# ============================================================
# Job Queue (Redis Streams)
# ============================================================

STREAM_KEY = "ai:jobs"
RESULTS_PREFIX = "ai:results:"
JOB_TTL_SECONDS = 3600  # Results expire after 1 hour


async def publish_job(
    job_type: str,
    user_id: str,
    payload: dict,
) -> str:
    """Publish an AI job to the Redis Streams queue.

    Args:
        job_type: Type of job ('vision_scan' or 'coach_generate').
        user_id: User UUID string.
        payload: Job-specific data to process.

    Returns:
        Job ID (UUID string) for status polling.
    """
    client = await get_redis()
    job_id = str(uuid.uuid4())

    job_data = {
        "job_id": job_id,
        "job_type": job_type,
        "user_id": user_id,
        "payload": json.dumps(payload),
        "status": "pending",
        "created_at": datetime.now(UTC).isoformat(),
    }

    # Store initial job status
    await client.hset(f"{RESULTS_PREFIX}{job_id}", mapping=job_data)
    await client.expire(f"{RESULTS_PREFIX}{job_id}", JOB_TTL_SECONDS)

    # Publish to stream
    await client.xadd(STREAM_KEY, {"job_id": job_id, "job_type": job_type})

    return job_id


async def get_job_status(job_id: str) -> dict | None:
    """Get the current status and result of an AI job.

    Args:
        job_id: Job UUID string.

    Returns:
        Job status dict or None if not found.
    """
    client = await get_redis()
    data = await client.hgetall(f"{RESULTS_PREFIX}{job_id}")
    if not data:
        return None

    # Real Redis with decode_responses=True returns str keys/values, but some
    # fakeredis versions return bytes from hgetall regardless. Normalize so the
    # logic below (and callers) can rely on str keys.
    data = {
        (k.decode() if isinstance(k, bytes) else k): (v.decode() if isinstance(v, bytes) else v)
        for k, v in data.items()
    }

    # Parse result JSON if present
    if "result" in data and data["result"]:
        try:
            data["result"] = json.loads(data["result"])
        except (json.JSONDecodeError, TypeError):
            pass

    return data


async def update_job_status(
    job_id: str,
    status: str,
    result: dict | None = None,
    error: str | None = None,
) -> None:
    """Update the status of an AI job.

    Args:
        job_id: Job UUID string.
        status: New status ('processing', 'completed', 'failed').
        result: Optional result data (for completed jobs).
        error: Optional error message (for failed jobs).
    """
    client = await get_redis()
    updates: dict = {"status": status, "updated_at": datetime.now(UTC).isoformat()}

    if result is not None:
        updates["result"] = json.dumps(result)
    if error is not None:
        updates["error"] = error

    await client.hset(f"{RESULTS_PREFIX}{job_id}", mapping=updates)


# ============================================================
# Cache (hash-based dedup for vision scans)
# ============================================================

VISION_CACHE_PREFIX = "ai:vision:"
VISION_CACHE_TTL = 86400  # 24 hours


def compute_image_hash(image_data: bytes) -> str:
    """Compute SHA256 hash of image data for cache dedup.

    Args:
        image_data: Raw image bytes.

    Returns:
        Hex-encoded SHA256 hash string.
    """
    return hashlib.sha256(image_data).hexdigest()


async def get_cached_vision_result(image_hash: str) -> dict | None:
    """Check if a vision scan result is cached.

    Args:
        image_hash: SHA256 hash of the image.

    Returns:
        Cached result dict or None.
    """
    client = await get_redis()
    cached = await client.get(f"{VISION_CACHE_PREFIX}{image_hash}")
    if cached:
        try:
            return json.loads(cached)
        except (json.JSONDecodeError, TypeError):
            return None
    return None


async def cache_vision_result(image_hash: str, result: dict) -> None:
    """Cache a vision scan result.

    Args:
        image_hash: SHA256 hash of the image.
        result: Vision scan result to cache.
    """
    client = await get_redis()
    await client.set(
        f"{VISION_CACHE_PREFIX}{image_hash}",
        json.dumps(result),
        ex=VISION_CACHE_TTL,
    )
