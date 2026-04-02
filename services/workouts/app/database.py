"""Database connection and session management for workouts service."""

from __future__ import annotations

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.config import settings

engine = create_async_engine(
    settings.database_url,
    echo=settings.app_debug,
    pool_size=5,
    max_overflow=10,
)

async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


async def get_db() -> AsyncSession:
    """Yield a database session for FastAPI dependency injection.

    Yields:
        AsyncSession that auto-closes after use.
    """
    async with async_session() as session:
        try:
            yield session
        finally:
            await session.close()
