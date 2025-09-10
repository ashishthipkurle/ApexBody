-- Migration: add daily_targets column to client_weekly_goal_muscle_targets
-- Adds a jsonb column to store per-day targets (sets/reps/weight) for each muscle

ALTER TABLE IF EXISTS client_weekly_goal_muscle_targets
  ADD COLUMN IF NOT EXISTS daily_targets jsonb;

-- Backfill is not performed here; existing rows will have null daily_targets.
