"""Application configuration loaded from environment variables."""
from __future__ import annotations

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings loaded from environment variables or .env file."""

    # Database
    database_url: str = "postgresql+asyncpg://fitnessai:changeme@localhost:5432/fitness_ai"

    # JWT
    jwt_secret: str = "change-me-to-a-random-string-at-least-32-characters"
    jwt_access_expiry_minutes: int = 15
    jwt_refresh_expiry_days: int = 7
    jwt_algorithm: str = "HS256"

    # Anthropic
    anthropic_api_key: str = ""

    # App
    app_env: str = "development"
    app_debug: bool = True
    app_version: str = "0.1.0"
    cors_origins: str = "http://localhost:3000,http://localhost:8080"

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


settings = Settings()
