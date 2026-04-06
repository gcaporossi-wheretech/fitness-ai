"""Coach generation prompt template: personalized workout plan from body photos.

Version: 1.0
Expected input: base64 body photos + user profile JSON
Expected output: structured JSON workout plan
"""

from __future__ import annotations

COACH_GENERATE_VERSION = "1.0"

COACH_GENERATE_SYSTEM_PROMPT = """\
You are an expert personal trainer and exercise physiologist. \
Your task is to analyze body photos and user data to create a \
personalized, structured workout plan.

Rules:
- Always respond with valid JSON matching the exact schema below
- Create a realistic, progressive plan appropriate for the user's level and goals
- Consider any physical limitations mentioned in the user data
- Each workout day should have 5-8 exercises with specific sets, reps, and rest periods
- Include warm-up and cool-down notes
- Suggest starting weights based on typical ranges for the user's apparent fitness level
- Plans should be 4-6 weeks in duration with progressive overload

Response JSON schema:
{
  "plan_name": "string - descriptive plan name",
  "description": "string - brief overview of the plan and its goals",
  "duration_weeks": "integer - plan duration in weeks",
  "days_per_week": "integer - training days per week",
  "level": "string - beginner|intermediate|advanced",
  "days": [
    {
      "day_name": "string - e.g. 'Day 1 - Upper Body Push'",
      "focus": "string - primary muscle groups for this day",
      "warm_up": "string - warm-up instructions",
      "exercises": [
        {
          "name": "string - exercise name",
          "name_it": "string - exercise name in Italian",
          "muscle_groups": ["string - target muscles"],
          "sets": "integer",
          "reps": "string - e.g. '8-12' or '30 seconds'",
          "rest_seconds": "integer - rest between sets",
          "weight_suggestion_kg": "float or null - suggested starting weight",
          "notes": "string or null - form cues or modifications"
        }
      ],
      "cool_down": "string - cool-down instructions"
    }
  ],
  "progression_notes": "string - how to progress week over week",
  "nutrition_tips": "string or null - basic nutrition advice if relevant"
}"""


def build_coach_user_prompt(user_data: dict) -> str:
    """Build the user prompt for coach generation with user-specific data.

    Args:
        user_data: Dictionary with user profile information.

    Returns:
        Formatted user prompt string.
    """
    parts = [
        "Analyze the provided body photos and create a personalized workout plan.",
        "",
    ]

    if user_data.get("name"):
        parts.append(f"User: {user_data['name']}")
    if user_data.get("age"):
        parts.append(f"Age: {user_data['age']}")
    if user_data.get("goals"):
        goals = user_data["goals"]
        if isinstance(goals, dict):
            goals_str = ", ".join(f"{k}: {v}" for k, v in goals.items())
        else:
            goals_str = str(goals)
        parts.append(f"Goals: {goals_str}")
    if user_data.get("limitations"):
        limitations = user_data["limitations"]
        if isinstance(limitations, dict):
            lim_str = ", ".join(f"{k}: {v}" for k, v in limitations.items())
        else:
            lim_str = str(limitations)
        parts.append(f"Physical limitations: {lim_str}")
    if user_data.get("experience"):
        parts.append(f"Training experience: {user_data['experience']}")
    if user_data.get("available_days"):
        parts.append(f"Available training days per week: {user_data['available_days']}")
    if user_data.get("available_equipment"):
        parts.append(f"Available equipment: {user_data['available_equipment']}")

    parts.append("")
    parts.append("Respond ONLY with valid JSON matching the schema described.")

    return "\n".join(parts)
