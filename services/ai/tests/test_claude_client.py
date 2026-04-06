"""Unit tests for Claude API client: vision scan and coach generation."""

from __future__ import annotations

import json
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.claude_client import (
    ClaudeAPIError,
    _parse_json_response,
    _resolve_media_type,
    analyze_equipment_image,
    generate_workout_plan,
)


class TestResolveMediaType:
    """Tests for media type resolution."""

    def test_jpeg_passthrough(self):
        """Valid JPEG type should pass through unchanged."""
        assert _resolve_media_type("image/jpeg") == "image/jpeg"

    def test_png_passthrough(self):
        """Valid PNG type should pass through unchanged."""
        assert _resolve_media_type("image/png") == "image/png"

    def test_gif_passthrough(self):
        """Valid GIF type should pass through unchanged."""
        assert _resolve_media_type("image/gif") == "image/gif"

    def test_webp_passthrough(self):
        """Valid WebP type should pass through unchanged."""
        assert _resolve_media_type("image/webp") == "image/webp"

    def test_invalid_type_defaults_to_jpeg(self):
        """Invalid type should default to image/jpeg."""
        assert _resolve_media_type("application/pdf") == "image/jpeg"

    def test_empty_string_defaults_to_jpeg(self):
        """Empty string should default to image/jpeg."""
        assert _resolve_media_type("") == "image/jpeg"


class TestParseJsonResponse:
    """Tests for JSON response parsing from Claude."""

    def test_parse_plain_json(self):
        """Plain JSON string should parse correctly."""
        text = '{"equipment_name": "Bench Press", "confidence": 0.9}'
        result = _parse_json_response(text)
        assert result["equipment_name"] == "Bench Press"

    def test_parse_json_in_code_block(self):
        """JSON inside markdown code block should parse correctly."""
        text = '```json\n{"equipment_name": "Leg Press"}\n```'
        result = _parse_json_response(text)
        assert result["equipment_name"] == "Leg Press"

    def test_parse_json_in_plain_code_block(self):
        """JSON inside plain code block (no language tag) should parse correctly."""
        text = '```\n{"equipment_name": "Cable Machine"}\n```'
        result = _parse_json_response(text)
        assert result["equipment_name"] == "Cable Machine"

    def test_parse_json_with_whitespace(self):
        """JSON with extra whitespace should parse correctly."""
        text = '  \n  {"equipment_name": "Squat Rack"}  \n  '
        result = _parse_json_response(text)
        assert result["equipment_name"] == "Squat Rack"

    def test_parse_invalid_json_raises(self):
        """Non-JSON text should raise ClaudeAPIError."""
        with pytest.raises(ClaudeAPIError, match="Failed to parse"):
            _parse_json_response("This is not JSON at all")

    def test_parse_empty_string_raises(self):
        """Empty string should raise ClaudeAPIError."""
        with pytest.raises(ClaudeAPIError, match="Failed to parse"):
            _parse_json_response("")


class TestAnalyzeEquipmentImage:
    """Tests for Claude Vision API calls (mocked)."""

    @pytest.mark.asyncio
    async def test_analyze_success(self):
        """Successful API call should return parsed result."""
        mock_response = MagicMock()
        mock_block = MagicMock()
        mock_block.type = "text"
        mock_block.text = json.dumps(
            {
                "equipment_name": "Bench Press",
                "brand": "Technogym",
                "confidence": 0.95,
                "exercises": [],
            }
        )
        mock_response.content = [mock_block]

        mock_client = MagicMock()
        mock_client.messages.create = AsyncMock(return_value=mock_response)

        with patch(
            "app.claude_client._get_async_client", return_value=mock_client
        ):
            result = await analyze_equipment_image(
                b"fake image data", "image/jpeg"
            )
            assert result["equipment_name"] == "Bench Press"
            assert result["brand"] == "Technogym"

    @pytest.mark.asyncio
    async def test_analyze_empty_response_raises(self):
        """Empty response from Claude should raise ClaudeAPIError."""
        mock_response = MagicMock()
        mock_response.content = []

        mock_client = MagicMock()
        mock_client.messages.create = AsyncMock(return_value=mock_response)

        with patch(
            "app.claude_client._get_async_client", return_value=mock_client
        ):
            with pytest.raises(ClaudeAPIError, match="Empty response"):
                await analyze_equipment_image(b"fake image", "image/jpeg")

    @pytest.mark.asyncio
    async def test_analyze_api_error_raises(self):
        """API error should be wrapped in ClaudeAPIError."""
        import anthropic

        mock_client = MagicMock()
        mock_client.messages.create = AsyncMock(
            side_effect=anthropic.APIError(
                message="Rate limited",
                request=MagicMock(),
                body=None,
            )
        )

        with patch(
            "app.claude_client._get_async_client", return_value=mock_client
        ):
            with pytest.raises(ClaudeAPIError, match="Claude API error"):
                await analyze_equipment_image(b"fake image", "image/jpeg")

    @pytest.mark.asyncio
    async def test_analyze_no_api_key_raises(self):
        """Missing API key should raise ClaudeAPIError."""
        with patch("app.claude_client.settings") as mock_settings:
            mock_settings.anthropic_api_key = ""
            with pytest.raises(ClaudeAPIError, match="not configured"):
                await analyze_equipment_image(b"fake image", "image/jpeg")


class TestGenerateWorkoutPlan:
    """Tests for coach plan generation (mocked)."""

    @pytest.mark.asyncio
    async def test_generate_success(self):
        """Successful plan generation should return parsed result."""
        mock_response = MagicMock()
        mock_block = MagicMock()
        mock_block.type = "text"
        mock_block.text = json.dumps(
            {
                "plan_name": "Beginner Full Body",
                "description": "A 4-week beginner program",
                "duration_weeks": 4,
                "days_per_week": 3,
                "level": "beginner",
                "days": [{"day_name": "Day 1", "exercises": []}],
                "progression_notes": "Add weight weekly",
            }
        )
        mock_response.content = [mock_block]

        mock_client = MagicMock()
        mock_client.messages.create = AsyncMock(return_value=mock_response)

        with patch(
            "app.claude_client._get_async_client", return_value=mock_client
        ):
            result = await generate_workout_plan(
                photos_data=[(b"photo1", "image/jpeg")],
                user_data={
                    "name": "Test",
                    "age": 30,
                    "goals": {"primary": "muscle_gain"},
                },
            )
            assert result["plan_name"] == "Beginner Full Body"
            assert result["duration_weeks"] == 4
            assert len(result["days"]) == 1

    @pytest.mark.asyncio
    async def test_generate_multiple_photos(self):
        """Generation with multiple photos should include all in request."""
        mock_response = MagicMock()
        mock_block = MagicMock()
        mock_block.type = "text"
        mock_block.text = json.dumps(
            {"plan_name": "Test Plan", "description": "test", "days": []}
        )
        mock_response.content = [mock_block]

        mock_client = MagicMock()
        mock_client.messages.create = AsyncMock(return_value=mock_response)

        with patch(
            "app.claude_client._get_async_client", return_value=mock_client
        ):
            result = await generate_workout_plan(
                photos_data=[
                    (b"front_photo", "image/jpeg"),
                    (b"side_photo", "image/png"),
                    (b"back_photo", "image/jpeg"),
                ],
                user_data={"name": "Test"},
            )
            assert result["plan_name"] == "Test Plan"

            # Verify all 3 photos + 1 text block were sent
            call_args = mock_client.messages.create.call_args
            content_blocks = call_args.kwargs["messages"][0]["content"]
            image_blocks = [
                b for b in content_blocks if b["type"] == "image"
            ]
            assert len(image_blocks) == 3
