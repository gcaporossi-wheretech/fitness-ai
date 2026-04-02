"""Shared test fixtures for analytics service tests."""

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
from app.models import Base, WorkoutPlan, WorkoutSession

TEST_DATABASE_URL = "sqlite+aiosqlite:///./test_analytics.db"


def create_test_token(user_id: str | None = None) -> str:
    """Create a valid JWT access token for testing."""
    if user_id is None:
        user_id = str(uuid.uuid4())
    payload = {
        "sub": user_id,
        "exp": datetime.now(UTC) + timedelta(minutes=15),
        "iat": datetime.now(UTC),
        "type": "access",
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def _make_sqlite_compatible(base):
    """Patch SQLAlchemy models for SQLite compatibility."""
    from sqlalchemy.dialects.postgresql import JSONB

    for table in base.metadata.tables.values():
        table.schema = None
        for column in table.columns:
            if isinstance(column.type, JSONB):
                column.type = JSON()


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
    """Create authorization headers with a valid JWT."""
    token = create_test_token(test_user_id)
    return {"Authorization": f"Bearer {token}"}


@pytest_asyncio.fixture
async def test_db() -> AsyncGenerator[AsyncSession, None]:
    """Create a test database with tables."""
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
async def seeded_db(test_db: AsyncSession, test_user_id: str) -> AsyncSession:
    """Create a test database with sample workout data for analytics."""
    user_uuid = uuid.UUID(test_user_id)
    now = datetime.now(UTC)

    # Create an active plan with 3 days
    plan = WorkoutPlan(
        id=uuid.uuid4(),
        user_id=user_uuid,
        name="Push Pull Legs",
        days=[
            {"name": "Push", "exercises": []},
            {"name": "Pull", "exercises": []},
            {"name": "Legs", "exercises": []},
        ],
        is_active=True,
        created_at=now - timedelta(days=30),
    )
    test_db.add(plan)

    # Create sessions over the past 2 weeks
    sessions = [
        WorkoutSession(
            id=uuid.uuid4(),
            user_id=user_uuid,
            plan_id=plan.id,
            day_name="Push",
            started_at=now - timedelta(days=14),
            completed_at=now - timedelta(days=14) + timedelta(hours=1),
            duration_seconds=3600,
            exercises=[
                {
                    "exercise_name": "Bench Press",
                    "sets": [
                        {"set_number": 1, "weight_kg": 80, "reps": 10},
                        {"set_number": 2, "weight_kg": 85, "reps": 8},
                        {"set_number": 3, "weight_kg": 85, "reps": 7},
                    ],
                },
                {
                    "exercise_name": "Overhead Press",
                    "sets": [
                        {"set_number": 1, "weight_kg": 50, "reps": 10},
                    ],
                },
            ],
            client_id=uuid.uuid4(),
            created_at=now - timedelta(days=14),
        ),
        WorkoutSession(
            id=uuid.uuid4(),
            user_id=user_uuid,
            plan_id=plan.id,
            day_name="Pull",
            started_at=now - timedelta(days=13),
            completed_at=now - timedelta(days=13) + timedelta(hours=1),
            duration_seconds=3600,
            exercises=[
                {
                    "exercise_name": "Barbell Row",
                    "sets": [
                        {"set_number": 1, "weight_kg": 70, "reps": 10},
                        {"set_number": 2, "weight_kg": 70, "reps": 8},
                    ],
                },
            ],
            client_id=uuid.uuid4(),
            created_at=now - timedelta(days=13),
        ),
        WorkoutSession(
            id=uuid.uuid4(),
            user_id=user_uuid,
            plan_id=plan.id,
            day_name="Push",
            started_at=now - timedelta(days=7),
            completed_at=now - timedelta(days=7) + timedelta(minutes=45),
            duration_seconds=2700,
            exercises=[
                {
                    "exercise_name": "Bench Press",
                    "sets": [
                        {"set_number": 1, "weight_kg": 85, "reps": 10},
                        {"set_number": 2, "weight_kg": 90, "reps": 8},
                        {"set_number": 3, "weight_kg": 90, "reps": 6},
                    ],
                },
            ],
            client_id=uuid.uuid4(),
            created_at=now - timedelta(days=7),
        ),
    ]
    test_db.add_all(sessions)
    await test_db.commit()
    return test_db


@pytest_asyncio.fixture
async def client(test_db: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    """Create a test HTTP client."""

    async def override_get_db():
        yield test_db

    app.dependency_overrides[get_db] = override_get_db
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
    app.dependency_overrides.clear()


@pytest_asyncio.fixture
async def seeded_client(seeded_db: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    """Create a test HTTP client with seeded workout data."""

    async def override_get_db():
        yield seeded_db

    app.dependency_overrides[get_db] = override_get_db
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
    app.dependency_overrides.clear()
