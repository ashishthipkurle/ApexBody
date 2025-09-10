-- Migration: create client weekly goals and muscle targets tables
-- Run these on your Postgres / Supabase database.

CREATE TABLE public.client_weekly_goals (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL,
  week_start date NOT NULL,
  target_weight numeric,
  target_calories numeric,
  notes text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT client_weekly_goals_pkey PRIMARY KEY (id),
  CONSTRAINT client_weekly_goals_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.users(id)
);

CREATE TABLE public.client_weekly_goal_muscle_targets (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  goal_id uuid NOT NULL,
  muscle_group text NOT NULL,
  target_sets integer DEFAULT 0,
  target_reps integer DEFAULT 0,
  target_weight numeric,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT client_weekly_goal_muscle_targets_pkey PRIMARY KEY (id),
  CONSTRAINT client_weekly_goal_muscle_targets_goal_id_fkey FOREIGN KEY (goal_id) REFERENCES public.client_weekly_goals(id) ON DELETE CASCADE
);

-- Indexes for faster lookups
CREATE INDEX idx_client_weekly_goals_client_week ON public.client_weekly_goals (client_id, week_start);
CREATE INDEX idx_client_weekly_targets_goal_id ON public.client_weekly_goal_muscle_targets (goal_id);
