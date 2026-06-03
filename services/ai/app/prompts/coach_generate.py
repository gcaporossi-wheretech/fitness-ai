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
- Always respond with valid JSON matching the exact schema below.
- ALL user-facing text (plan_name, description, assessment, exercise_name, \
progression_notes, nutrition_tips, notes) MUST be written in ITALIAN.
- Analyze the body photos and fill "assessment" (in Italian, 2-4 sentences): \
describe the user's current physique situation and how this plan addresses \
their objective. Be honest, concrete and encouraging.
- Fill "photo_review_weeks": after how many weeks the user should re-take \
progress photos to reassess (typically 4-8).
- Create a realistic, progressive plan appropriate for the user's level/goals.
- Consider any physical limitations mentioned in the user data.
- Each workout day should have 5-8 exercises with specific sets, reps, rest.
- Plans should be 4-6 weeks in duration with progressive overload.
- EXERCISE NAMES: if the user message includes a list of existing exercise \
names, REUSE the exact same name VERBATIM whenever the exercise matches one of \
them (same spelling/case). Only invent a new name (clear, standard Italian) \
when none of the existing names fits. This keeps names consistent over time.

Response JSON schema:
{
  "plan_name": "string - nome scheda (italiano)",
  "description": "string - panoramica della scheda e dell'obiettivo (italiano)",
  "assessment": "string - ITALIANO: situazione dalle foto + obiettivo (2-4 frasi)",
  "photo_review_weeks": "integer - tra quante settimane rifare le foto",
  "duration_weeks": "integer",
  "days_per_week": "integer",
  "level": "string - beginner|intermediate|advanced",
  "days": [
    {
      "day_name": "string - es. 'Giorno 1 - Spinta'",
      "focus": "string - gruppi muscolari principali",
      "exercises": [
        {
          "exercise_name": "string - nome IT (riusa un nome esistente se combacia)",
          "muscle_groups": ["string"],
          "sets": "integer",
          "reps": "string - es. '8-12'",
          "rest_seconds": "integer",
          "notes": "string or null - note tecniche (italiano)"
        }
      ]
    }
  ],
  "progression_notes": "string - come progredire settimana dopo settimana (italiano)",
  "nutrition_tips": "string or null - consigli nutrizionali (italiano)"
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

    known = user_data.get("known_exercises")
    if isinstance(known, list) and known:
        parts.append("")
        parts.append(
            "Existing exercise names — REUSE the exact name verbatim whenever an "
            "exercise matches one of these; only use a new Italian name if none fits:"
        )
        for n in known[:150]:
            parts.append(f"- {n}")

    parts.append("")
    parts.append(
        "Respond ONLY with valid JSON matching the schema described. "
        "All user-facing text must be in Italian."
    )

    return "\n".join(parts)
