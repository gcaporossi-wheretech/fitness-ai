-- 0002_normalize_session_durations.sql
-- Data fix: some workout sessions (imported from the GymTracker prototype and a
-- former resume bug) have absurd durations — completed_at was stored as
-- started_at + a corrupted duration, producing 12h-36h "workouts".
--
-- Normalize any session longer than 4h (14400s) to a sane 90 min, keeping the
-- original started_at and recomputing completed_at accordingly.
-- Idempotent: rows already <= 4h are untouched, so re-running is a no-op.

UPDATE workouts.workout_sessions
SET
    duration_seconds = 5400,
    completed_at = started_at + INTERVAL '90 minutes'
WHERE duration_seconds > 14400;
