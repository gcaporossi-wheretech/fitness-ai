-- Migration 0001: create the AI service schema and tables.
--
-- The ai service uses SQLAlchemy models but does NOT auto-create tables on
-- startup (no create_all/lifespan), matching the other services. This file
-- records the DDL to provision the ai schema on a database.
--
-- Idempotent: safe to run multiple times.
-- Apply on the server with:
--   docker compose exec -T db psql -U fitnessai -d fitness_ai -f - < 0001_create_ai_schema.sql

CREATE SCHEMA IF NOT EXISTS ai;

CREATE TABLE IF NOT EXISTS ai.ai_vision_scans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    image_hash VARCHAR(64),
    equipment_name VARCHAR(255),
    equipment_brand VARCHAR(100),
    exercises JSONB,
    raw_response JSONB,
    credits_used INTEGER DEFAULT 1,
    error TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS ix_ai_vision_scans_user_id ON ai.ai_vision_scans (user_id);

CREATE TABLE IF NOT EXISTS ai.ai_coach_generations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    input_data JSONB,
    photo_count INTEGER,
    generated_plan JSONB,
    raw_response JSONB,
    credits_used INTEGER DEFAULT 5,
    error TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS ix_ai_coach_generations_user_id ON ai.ai_coach_generations (user_id);
