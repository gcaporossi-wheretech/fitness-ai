"""FitnessAI API — Main application entry point."""
from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from core.config import settings
from modules.auth.router import router as auth_router

app = FastAPI(
    title="FitnessAI API",
    description="Backend API for FitnessAI - AI-powered fitness coach",
    version=settings.app_version,
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

# Register module routers
app.include_router(auth_router)


@app.get("/health")
async def health_check() -> dict:
    """Health check endpoint for monitoring and Docker healthcheck."""
    return {"status": "ok", "version": settings.app_version}
