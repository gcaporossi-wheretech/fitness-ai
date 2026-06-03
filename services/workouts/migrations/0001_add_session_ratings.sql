-- Migration 0001: add end-of-workout feedback columns to workout sessions.
--
-- The schema for this service is currently created via SQLAlchemy
-- metadata.create_all (no Alembic runner yet), which only CREATES missing
-- tables and never ALTERs existing ones. This file records the DDL that must
-- be applied to any already-provisioned database so the new model columns
-- (overall_rating, fatigue_rating, pump_rating) exist there too.
--
-- Idempotent: safe to run multiple times.
-- Apply on the server with:
--   docker compose exec -T db psql -U <user> -d <db> -f - < 0001_add_session_ratings.sql
-- (or pipe the statements below via psql).

ALTER TABLE workouts.workout_sessions
    ADD COLUMN IF NOT EXISTS overall_rating INTEGER;
ALTER TABLE workouts.workout_sessions
    ADD COLUMN IF NOT EXISTS fatigue_rating INTEGER;
ALTER TABLE workouts.workout_sessions
    ADD COLUMN IF NOT EXISTS pump_rating INTEGER;

-- Rollback:
-- ALTER TABLE workouts.workout_sessions DROP COLUMN IF EXISTS overall_rating;
-- ALTER TABLE workouts.workout_sessions DROP COLUMN IF EXISTS fatigue_rating;
-- ALTER TABLE workouts.workout_sessions DROP COLUMN IF EXISTS pump_rating;
