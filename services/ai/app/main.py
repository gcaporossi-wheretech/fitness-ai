"""AI service — Main application entry point."""

from __future__ import annotations

import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.router import router as ai_router

# Configure structured logging
logging.basicConfig(
    level=logging.DEBUG if settings.app_debug else logging.INFO,
    format='{"timestamp":"%(asctime)s","level":"%(levelname)s","service":"%(name)s","message":"%(message)s"}',
)

app = FastAPI(
    title="FitnessAI AI Service",
    description="Vision scan, Coach generation, and prompt engineering for FitnessAI",
    version=settings.app_version,
    docs_url="/ai/docs",
    openapi_url="/ai/openapi.json",
)

# Register router
app.include_router(ai_router)

# CORS middleware
origins = [o.strip() for o in settings.cors_origins.split(",")]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
async def health_check() -> dict:
    """Health check endpoint with Redis and API key connectivity check."""
    from app.redis_client import check_redis_health

    redis_ok = await check_redis_health()
    api_key_configured = bool(settings.anthropic_api_key)

    if redis_ok and api_key_configured:
        health_status = "ok"
    elif redis_ok:
        health_status = "degraded"
    else:
        health_status = "unhealthy"

    return {
        "status": health_status,
        "service": settings.service_name,
        "version": settings.app_version,
        "redis": "ok" if redis_ok else "unavailable",
        "claude_api": "configured" if api_key_configured else "not_configured",
    }
