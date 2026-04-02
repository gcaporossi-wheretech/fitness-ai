"""Auth service — Main application entry point."""

from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.router import router as auth_router

app = FastAPI(
    title="FitnessAI Auth Service",
    description="Authentication, user management, and credits for FitnessAI",
    version=settings.app_version,
    docs_url="/auth/docs",
    openapi_url="/auth/openapi.json",
)

# CORS middleware
origins = [o.strip() for o in settings.cors_origins.split(",")]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register router
app.include_router(auth_router)


@app.get("/health")
async def health_check() -> dict:
    """Health check endpoint for monitoring and Docker healthcheck."""
    return {"status": "ok", "service": settings.service_name, "version": settings.app_version}
