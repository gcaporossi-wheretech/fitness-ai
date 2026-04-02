"""Shared test fixtures for auth service tests."""

from __future__ import annotations

import asyncio
from collections.abc import AsyncGenerator

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy import JSON
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.database import get_db
from app.main import app
from app.models import Base

# Use SQLite for tests (in-memory) to avoid requiring PostgreSQL
TEST_DATABASE_URL = "sqlite+aiosqlite:///./test.db"


def _make_sqlite_compatible(base):
    """Patch SQLAlchemy models to be SQLite-compatible for testing.

    Replaces JSONB with JSON and removes schema prefixes, since SQLite
    does not support PostgreSQL-specific types or schemas.
    """
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
async def client(test_db: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    """Create a test HTTP client with database dependency override."""

    async def override_get_db():
        yield test_db

    app.dependency_overrides[get_db] = override_get_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac

    app.dependency_overrides.clear()
