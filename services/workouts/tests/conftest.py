"""Shared test fixtures for workouts service tests."""

from __future__ import annotations

import asyncio
import uuid
from collections.abc import AsyncGenerator
from datetime import UTC, datetime, timedelta

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from jose import jwt
from sqlalchemy import JSON
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.config import settings
from app.database import get_db
from app.main import app
from app.models import Base, Exercise

# Use SQLite for tests (in-memory) to avoid requiring PostgreSQL
TEST_DATABASE_URL = "sqlite+aiosqlite:///./test_workouts.db"


def create_test_token(user_id: str | None = None) -> str:
    """Create a valid JWT access token for testing.

    Args:
        user_id: Optional user UUID string. Generates a random one if not provided.

    Returns:
        Encoded JWT string.
    """
    if user_id is None:
        user_id = str(uuid.uuid4())
    payload = {
        "sub": user_id,
        "exp": datetime.now(UTC) + timedelta(minutes=15),
        "iat": datetime.now(UTC),
        "type": "access",
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


@pytest.fixture(scope="session")
def event_loop():
    """Create an event loop for the test session."""
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest.fixture
def test_user_id() -> str:
    """Generate a consistent test user UUID."""
    return "550e8400-e29b-41d4-a716-446655440000"


@pytest.fixture
def auth_headers(test_user_id: str) -> dict:
    """Create authorization headers with a valid JWT for the test user."""
    token = create_test_token(test_user_id)
    return {"Authorization": f"Bearer {token}"}


def _make_sqlite_compatible(base):
    """Patch SQLAlchemy models to be SQLite-compatible for testing.

    Replaces JSONB with JSON and removes schema prefixes, since SQLite
    does not support PostgreSQL-specific types or schemas.
    """
    from sqlalchemy.dialects.postgresql import JSONB

    for table in base.metadata.tables.values():
        # Remove schema for SQLite
        table.schema = None
        for column in table.columns:
            if isinstance(column.type, JSONB):
                column.type = JSON()


@pytest_asyncio.fixture
async def test_db() -> AsyncGenerator[AsyncSession, None]:
    """Create a test database session with tables created and dropped per test."""
    engine = create_async_engine(TEST_DATABASE_URL, echo=False)

    _make_sqlite_compatible(Base)

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    session_factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with session_factory() as session:
        yield session

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)

    await engine.dispose()


@pytest_asyncio.fixture
async def seeded_db(test_db: AsyncSession) -> AsyncSession:
    """Create a test database session with seed exercises pre-loaded."""
    exercises = [
        Exercise(
            name="Panca piana con bilanciere",
            name_en="Barbell Bench Press",
            muscle_groups=["chest", "triceps", "shoulders"],
            equipment="barbell",
            exercise_type="weighted",
        ),
        Exercise(
            name="Squat con bilanciere",
            name_en="Barbell Squat",
            muscle_groups=["legs", "glutes"],
            equipment="barbell",
            exercise_type="weighted",
        ),
        Exercise(
            name="Plank",
            name_en="Plank",
            muscle_groups=["abs", "core"],
            equipment=None,
            exercise_type="timed",
        ),
    ]
    test_db.add_all(exercises)
    await test_db.commit()
    return test_db


@pytest_asyncio.fixture
async def client(test_db: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    """Create a test HTTP client with database dependency override."""

    async def override_get_db():
        yield test_db

    app.dependency_overrides[get_db] = override_get_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac

    app.dependency_overrides.clear()


@pytest_asyncio.fixture
async def seeded_client(seeded_db: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    """Create a test HTTP client with seeded exercise data."""

    async def override_get_db():
        yield seeded_db

    app.dependency_overrides[get_db] = override_get_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac

    app.dependency_overrides.clear()
