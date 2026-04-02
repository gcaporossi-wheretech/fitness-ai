"""Workouts service — Main application entry point."""

from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.router import router as workouts_router

app = FastAPI(
    title="FitnessAI Workouts Service",
    description="Workout plans, sessions, exercises, and offline sync for FitnessAI",
    version=settings.app_version,
    docs_url="/workouts/docs",
    openapi_url="/workouts/openapi.json",
)

# Register router
app.include_router(workouts_router)

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
    """Health check endpoint for monitoring and Docker healthcheck."""
    return {"status": "ok", "service": settings.service_name, "version": settings.app_version}
