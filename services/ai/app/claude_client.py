"""Claude API client for AI vision scan and coach generation.

Handles communication with the Anthropic Claude API for image analysis.
Photos are processed in memory only — never saved to disk (ADR-003).
"""

from __future__ import annotations

import base64
import json
import logging
from typing import Any

import anthropic

from app.config import settings
from app.prompts.coach_generate import (
    COACH_GENERATE_SYSTEM_PROMPT,
    build_coach_user_prompt,
)
from app.prompts.vision_scan import (
    VISION_SCAN_SYSTEM_PROMPT,
    VISION_SCAN_USER_PROMPT,
)

logger = logging.getLogger(__name__)

# Claude model for vision tasks
CLAUDE_MODEL = "claude-sonnet-4-20250514"
MAX_TOKENS = 4096

# Supported image MIME types for Claude Vision API
VALID_IMAGE_TYPES = ("image/jpeg", "image/png", "image/gif", "image/webp")
DEFAULT_IMAGE_TYPE = "image/jpeg"


class ClaudeAPIError(Exception):
    """Raised when Claude API call fails."""

    def __init__(self, message: str, original_error: Exception | None = None) -> None:
        self.message = message
        self.original_error = original_error
        super().__init__(message)


def _get_async_client() -> anthropic.AsyncAnthropic:
    """Create an async Anthropic client instance.

    Returns:
        Configured async Anthropic client.

    Raises:
        ClaudeAPIError: If API key is not configured.
    """
    if not settings.anthropic_api_key:
        raise ClaudeAPIError("ANTHROPIC_API_KEY not configured")
    return anthropic.AsyncAnthropic(api_key=settings.anthropic_api_key)


def _resolve_media_type(content_type: str) -> str:
    """Resolve a content type to a valid Claude Vision media type.

    Args:
        content_type: MIME type string from the uploaded file.

    Returns:
        A valid media type string for Claude Vision API.
    """
    return content_type if content_type in VALID_IMAGE_TYPES else DEFAULT_IMAGE_TYPE


def _parse_json_response(text: str) -> dict:
    """Parse JSON from Claude response, handling markdown code blocks.

    Args:
        text: Raw response text from Claude.

    Returns:
        Parsed JSON dictionary.

    Raises:
        ClaudeAPIError: If response cannot be parsed as JSON.
    """
    # Strip markdown code blocks if present
    cleaned = text.strip()
    if cleaned.startswith("```"):
        # Remove opening ```json or ```
        first_newline = cleaned.index("\n")
        cleaned = cleaned[first_newline + 1 :]
        if cleaned.endswith("```"):
            cleaned = cleaned[: -len("```")]
        cleaned = cleaned.strip()

    try:
        return json.loads(cleaned)
    except json.JSONDecodeError as exc:
        raise ClaudeAPIError(f"Failed to parse Claude response as JSON: {exc}") from exc


async def analyze_equipment_image(
    image_data: bytes,
    content_type: str = DEFAULT_IMAGE_TYPE,
) -> dict[str, Any]:
    """Send an equipment image to Claude Vision for analysis.

    The image is encoded to base64 and sent in-memory. No image data
    is persisted to disk at any point (ADR-003).

    Args:
        image_data: Raw image bytes.
        content_type: MIME type of the image (image/jpeg or image/png).

    Returns:
        Parsed equipment analysis result dict.

    Raises:
        ClaudeAPIError: If API call fails or response is invalid.
    """
    client = _get_async_client()
    image_b64 = base64.b64encode(image_data).decode("utf-8")
    media_type = _resolve_media_type(content_type)

    try:
        message = await client.messages.create(
            model=CLAUDE_MODEL,
            max_tokens=MAX_TOKENS,
            system=VISION_SCAN_SYSTEM_PROMPT,
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image",
                            "source": {
                                "type": "base64",
                                "media_type": media_type,
                                "data": image_b64,
                            },
                        },
                        {
                            "type": "text",
                            "text": VISION_SCAN_USER_PROMPT,
                        },
                    ],
                }
            ],
        )
    except anthropic.APIError as exc:
        logger.error("Claude API error during vision scan: %s", exc)
        raise ClaudeAPIError(f"Claude API error: {exc}") from exc

    # Extract text content from response
    response_text = ""
    for block in message.content:
        if block.type == "text":
            response_text += block.text

    if not response_text:
        raise ClaudeAPIError("Empty response from Claude API")

    result = _parse_json_response(response_text)
    logger.info(
        "Vision scan completed: equipment=%s confidence=%.2f",
        result.get("equipment_name", "unknown"),
        result.get("confidence", 0.0),
    )
    return result


async def generate_workout_plan(
    photos_data: list[tuple[bytes, str]],
    user_data: dict,
) -> dict[str, Any]:
    """Generate a personalized workout plan from body photos and user data.

    Photos are encoded to base64 and sent in-memory. No photo data
    is persisted to disk at any point (ADR-003).

    Args:
        photos_data: List of (image_bytes, content_type) tuples.
        user_data: User profile data (age, goals, limitations, etc.).

    Returns:
        Parsed workout plan result dict.

    Raises:
        ClaudeAPIError: If API call fails or response is invalid.
    """
    client = _get_async_client()

    # Build content blocks: photos first, then text prompt
    content: list[dict] = []
    for photo_bytes, photo_content_type in photos_data:
        photo_b64 = base64.b64encode(photo_bytes).decode("utf-8")
        media_type = _resolve_media_type(photo_content_type)
        content.append(
            {
                "type": "image",
                "source": {
                    "type": "base64",
                    "media_type": media_type,
                    "data": photo_b64,
                },
            }
        )

    content.append(
        {
            "type": "text",
            "text": build_coach_user_prompt(user_data),
        }
    )

    try:
        message = await client.messages.create(
            model=CLAUDE_MODEL,
            max_tokens=MAX_TOKENS,
            system=COACH_GENERATE_SYSTEM_PROMPT,
            messages=[{"role": "user", "content": content}],
        )
    except anthropic.APIError as exc:
        logger.error("Claude API error during coach generation: %s", exc)
        raise ClaudeAPIError(f"Claude API error: {exc}") from exc

    response_text = ""
    for block in message.content:
        if block.type == "text":
            response_text += block.text

    if not response_text:
        raise ClaudeAPIError("Empty response from Claude API")

    result = _parse_json_response(response_text)
    logger.info(
        "Coach plan generated: %s (%d days)",
        result.get("plan_name", "unnamed"),
        len(result.get("days", [])),
    )
    return result
