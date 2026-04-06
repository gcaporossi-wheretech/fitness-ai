"""SQLAlchemy models for AI service — ai schema tables."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

from sqlalchemy import DateTime, Integer, String, Text
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    """Base class for all AI service models."""

    pass


class AIVisionScan(Base):
    """Record of an AI vision scan (equipment recognition from photo).

    Stores the analysis result but never the original photo (ADR-003).
    """

    __tablename__ = "ai_vision_scans"
    __table_args__ = {"schema": "ai"}

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False, index=True)
    image_hash: Mapped[str | None] = mapped_column(String(64), nullable=True)
    equipment_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    equipment_brand: Mapped[str | None] = mapped_column(String(100), nullable=True)
    exercises: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    raw_response: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    credits_used: Mapped[int] = mapped_column(Integer, default=1)
    error: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC)
    )


class AICoachGeneration(Base):
    """Record of an AI coach generation (personalized workout plan).

    Stores the generated plan and input metadata but never the original photos (ADR-003).
    """

    __tablename__ = "ai_coach_generations"
    __table_args__ = {"schema": "ai"}

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False, index=True)
    input_data: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    photo_count: Mapped[int | None] = mapped_column(Integer, nullable=True)
    generated_plan: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    raw_response: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    credits_used: Mapped[int] = mapped_column(Integer, default=5)
    error: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC)
    )
