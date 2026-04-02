"""AI service — Main application entry point."""

from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.router import router as ai_router

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
    """Health check endpoint with Redis connectivity check."""
    from app.redis_client import check_redis_health

    redis_ok = await check_redis_health()
    status = "ok" if redis_ok else "degraded"
    return {
        "status": status,
        "service": settings.service_name,
        "version": settings.app_version,
        "redis": "ok" if redis_ok else "unavailable",
    }
