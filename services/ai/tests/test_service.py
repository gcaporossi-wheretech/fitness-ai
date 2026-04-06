"""Unit tests for AI service business logic."""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import fakeredis.aioredis
import pytest

from app.service import (
    AIServiceError,
    InsufficientCreditsError,
    process_coach_generate,
    process_vision_scan,
)
from tests.conftest import TEST_USER_ID, create_test_token


@pytest.fixture
def fake_redis():
    """Create a fakeredis instance."""
    return fakeredis.aioredis.FakeRedis(decode_responses=True)


@pytest.fixture
def mock_db():
    """Create a mock database session."""
    db = AsyncMock()
    db.add = MagicMock()
    db.commit = AsyncMock()
    return db


@pytest.fixture
def auth_token():
    """Create a valid JWT token."""
    return create_test_token(TEST_USER_ID)


@pytest.fixture
def vision_result():
    """Standard vision scan result."""
    return {
        "equipment_name": "Bench Press",
        "brand": "Technogym",
        "confidence": 0.95,
        "exercises": [
            {
                "name": "Flat Bench Press",
                "name_it": "Panca Piana",
                "muscle_groups": ["chest"],
                "difficulty": "intermediate",
                "description": "Press barbell from chest.",
            }
        ],
    }


@pytest.mark.asyncio
async def test_process_vision_scan_success(fake_redis, mock_db, auth_token, vision_result):
    """Successful vision scan should call Claude API and persist result."""
    with (
        patch("app.redis_client.get_redis", return_value=fake_redis),
        patch("app.service.get_cached_vision_result", new_callable=AsyncMock, return_value=None),
        patch(
            "app.service.analyze_equipment_image",
            new_callable=AsyncMock,
            return_value=vision_result,
        ),
        patch("app.service._deduct_credits", new_callable=AsyncMock, return_value=True),
        patch("app.service.cache_vision_result", new_callable=AsyncMock),
    ):
        result = await process_vision_scan(
            image_data=b"fake image bytes",
            content_type="image/jpeg",
            user_id=TEST_USER_ID,
            token=auth_token,
            db=mock_db,
        )

        assert result["equipment_name"] == "Bench Press"
        assert result["cached"] is False
        assert "scan_id" in result
        mock_db.add.assert_called_once()
        mock_db.commit.assert_called_once()


@pytest.mark.asyncio
async def test_process_vision_scan_cached(fake_redis, mock_db, auth_token, vision_result):
    """Cached vision scan should skip Claude API and not deduct credits."""
    with (
        patch("app.redis_client.get_redis", return_value=fake_redis),
        patch(
            "app.service.get_cached_vision_result",
            new_callable=AsyncMock,
            return_value=vision_result,
        ),
        patch(
            "app.service.analyze_equipment_image", new_callable=AsyncMock
        ) as mock_analyze,
        patch("app.service._deduct_credits", new_callable=AsyncMock) as mock_deduct,
    ):
        result = await process_vision_scan(
            image_data=b"cached image",
            content_type="image/jpeg",
            user_id=TEST_USER_ID,
            token=auth_token,
            db=mock_db,
        )

        assert result["cached"] is True
        # Should NOT call Claude API or deduct credits
        mock_analyze.assert_not_called()
        mock_deduct.assert_not_called()


@pytest.mark.asyncio
async def test_process_vision_scan_insufficient_credits(fake_redis, mock_db, auth_token):
    """Vision scan should raise when user has no credits."""
    with (
        patch("app.redis_client.get_redis", return_value=fake_redis),
        patch("app.service.get_cached_vision_result", new_callable=AsyncMock, return_value=None),
        patch(
            "app.service._deduct_credits",
            new_callable=AsyncMock,
            side_effect=InsufficientCreditsError(),
        ),
    ):
        with pytest.raises(InsufficientCreditsError):
            await process_vision_scan(
                image_data=b"image",
                content_type="image/jpeg",
                user_id=TEST_USER_ID,
                token=auth_token,
                db=mock_db,
            )


@pytest.mark.asyncio
async def test_process_vision_scan_api_failure(fake_redis, mock_db, auth_token):
    """Claude API failure should save error to DB and raise."""
    from app.claude_client import ClaudeAPIError

    with (
        patch("app.redis_client.get_redis", return_value=fake_redis),
        patch("app.service.get_cached_vision_result", new_callable=AsyncMock, return_value=None),
        patch("app.service._deduct_credits", new_callable=AsyncMock, return_value=True),
        patch(
            "app.service.analyze_equipment_image",
            new_callable=AsyncMock,
            side_effect=ClaudeAPIError("API timeout"),
        ),
    ):
        with pytest.raises(AIServiceError, match="Vision scan failed"):
            await process_vision_scan(
                image_data=b"image",
                content_type="image/jpeg",
                user_id=TEST_USER_ID,
                token=auth_token,
                db=mock_db,
            )

        # Error should still be saved to DB
        mock_db.add.assert_called_once()
        mock_db.commit.assert_called_once()


# ============================================================
# Coach Generation Tests
# ============================================================


@pytest.fixture
def coach_result():
    """Standard coach generation result."""
    return {
        "plan_name": "Beginner Full Body",
        "description": "A 4-week beginner program",
        "duration_weeks": 4,
        "days_per_week": 3,
        "level": "beginner",
        "days": [{"day_name": "Day 1", "exercises": []}],
        "progression_notes": "Add weight weekly",
    }


@pytest.mark.asyncio
async def test_process_coach_generate_success(mock_db, auth_token, coach_result):
    """Successful coach generation should call Claude API and persist."""
    with (
        patch(
            "app.service.generate_workout_plan",
            new_callable=AsyncMock,
            return_value=coach_result,
        ),
        patch(
            "app.service._deduct_credits",
            new_callable=AsyncMock,
            return_value=True,
        ),
    ):
        result = await process_coach_generate(
            photos_data=[(b"photo1", "image/jpeg")],
            user_data={"age": 30, "goals": "muscle"},
            user_id=TEST_USER_ID,
            token=auth_token,
            db=mock_db,
        )

        assert result["plan_name"] == "Beginner Full Body"
        assert "generation_id" in result
        mock_db.add.assert_called_once()
        mock_db.commit.assert_called_once()


@pytest.mark.asyncio
async def test_process_coach_generate_insufficient_credits(mock_db, auth_token):
    """Coach generation should raise when user has no credits."""
    with patch(
        "app.service._deduct_credits",
        new_callable=AsyncMock,
        side_effect=InsufficientCreditsError(),
    ):
        with pytest.raises(InsufficientCreditsError):
            await process_coach_generate(
                photos_data=[(b"photo", "image/jpeg")],
                user_data={},
                user_id=TEST_USER_ID,
                token=auth_token,
                db=mock_db,
            )


@pytest.mark.asyncio
async def test_process_coach_generate_api_failure(mock_db, auth_token):
    """Claude API failure should save error to DB and raise."""
    from app.claude_client import ClaudeAPIError

    with (
        patch(
            "app.service._deduct_credits",
            new_callable=AsyncMock,
            return_value=True,
        ),
        patch(
            "app.service.generate_workout_plan",
            new_callable=AsyncMock,
            side_effect=ClaudeAPIError("API timeout"),
        ),
    ):
        with pytest.raises(AIServiceError, match="Coach generation failed"):
            await process_coach_generate(
                photos_data=[(b"photo", "image/jpeg")],
                user_data={},
                user_id=TEST_USER_ID,
                token=auth_token,
                db=mock_db,
            )

        # Error should still be saved to DB
        mock_db.add.assert_called_once()
        mock_db.commit.assert_called_once()
