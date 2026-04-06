"""Unit tests for prompt templates."""

from __future__ import annotations

from app.prompts.coach_generate import (
    COACH_GENERATE_SYSTEM_PROMPT,
    COACH_GENERATE_VERSION,
    build_coach_user_prompt,
)
from app.prompts.vision_scan import (
    VISION_SCAN_SYSTEM_PROMPT,
    VISION_SCAN_USER_PROMPT,
    VISION_SCAN_VERSION,
)


class TestVisionScanPrompt:
    """Tests for vision scan prompt template."""

    def test_system_prompt_has_json_schema(self):
        """System prompt should describe the expected JSON schema."""
        assert "equipment_name" in VISION_SCAN_SYSTEM_PROMPT
        assert "exercises" in VISION_SCAN_SYSTEM_PROMPT
        assert "confidence" in VISION_SCAN_SYSTEM_PROMPT
        assert "brand" in VISION_SCAN_SYSTEM_PROMPT

    def test_system_prompt_has_rules(self):
        """System prompt should include behavior rules."""
        assert "Unknown" in VISION_SCAN_SYSTEM_PROMPT
        assert "0.0" in VISION_SCAN_SYSTEM_PROMPT
        assert "JSON" in VISION_SCAN_SYSTEM_PROMPT

    def test_user_prompt_asks_for_json(self):
        """User prompt should request JSON output."""
        assert "JSON" in VISION_SCAN_USER_PROMPT

    def test_version_exists(self):
        """Version string should be defined."""
        assert VISION_SCAN_VERSION == "1.0"


class TestCoachGeneratePrompt:
    """Tests for coach generation prompt template."""

    def test_system_prompt_has_plan_schema(self):
        """System prompt should describe workout plan JSON schema."""
        assert "plan_name" in COACH_GENERATE_SYSTEM_PROMPT
        assert "days" in COACH_GENERATE_SYSTEM_PROMPT
        assert "exercises" in COACH_GENERATE_SYSTEM_PROMPT
        assert "sets" in COACH_GENERATE_SYSTEM_PROMPT
        assert "reps" in COACH_GENERATE_SYSTEM_PROMPT

    def test_version_exists(self):
        """Version string should be defined."""
        assert COACH_GENERATE_VERSION == "1.0"

    def test_build_user_prompt_minimal(self):
        """User prompt with minimal data should still be valid."""
        prompt = build_coach_user_prompt({})
        assert "Analyze" in prompt
        assert "JSON" in prompt

    def test_build_user_prompt_full(self):
        """User prompt with all fields should include them all."""
        prompt = build_coach_user_prompt(
            {
                "name": "Marco",
                "age": 35,
                "goals": {"primary": "muscle_gain", "secondary": "fat_loss"},
                "limitations": {"shoulder": "avoid overhead"},
                "experience": "intermediate",
                "available_days": 4,
                "available_equipment": "full gym",
            }
        )
        assert "Marco" in prompt
        assert "35" in prompt
        assert "muscle_gain" in prompt
        assert "shoulder" in prompt
        assert "intermediate" in prompt
        assert "4" in prompt
        assert "full gym" in prompt

    def test_build_user_prompt_goals_as_string(self):
        """Goals provided as string should be included."""
        prompt = build_coach_user_prompt({"goals": "lose weight"})
        assert "lose weight" in prompt

    def test_build_user_prompt_limitations_as_string(self):
        """Limitations provided as string should be included."""
        prompt = build_coach_user_prompt({"limitations": "bad knees"})
        assert "bad knees" in prompt
