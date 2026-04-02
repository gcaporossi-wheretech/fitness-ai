"""AI service configuration loaded from environment variables."""

from __future__ import annotations

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """AI service settings."""

    # Database
    database_url: str = "postgresql+asyncpg://fitnessai:changeme@db:5432/fitness_ai"

    # JWT (for token validation — shared secret with auth service)
    jwt_secret: str = "change-me-to-a-random-string-at-least-32-characters"
    jwt_algorithm: str = "HS256"

    # Anthropic
    anthropic_api_key: str = ""

    # Redis (cache + job queue)
    redis_url: str = "redis://redis:6379/0"

    # App
    app_env: str = "development"
    app_debug: bool = True
    app_version: str = "0.1.0"
    cors_origins: str = "http://localhost:3000,http://localhost:8080"

    # Service
    service_name: str = "ai"
    service_port: int = 8003

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


settings = Settings()
