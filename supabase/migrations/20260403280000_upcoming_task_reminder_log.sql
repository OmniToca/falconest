-- =============================================================================
-- FalcoNest – idempotence pro Edge upcoming-task-reminder
-- =============================================================================
-- PROČ: Připomínka může být zapnutá jen jako push/e-mail (bez web). Bez záznamu
-- v notifications nelze spoléhat na deduplikaci podle „už odesláno“ – jeden
-- úkol + konkrétní scheduled_start smí vygenerovat nejvýše jednu vlnu připomínek.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.upcoming_task_reminder_log (
  task_id uuid NOT NULL REFERENCES public.tasks (id) ON DELETE CASCADE,
  scheduled_start timestamp with time zone NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  PRIMARY KEY (task_id, scheduled_start)
);

COMMENT ON TABLE public.upcoming_task_reminder_log IS
  'Idempotence Edge funkce upcoming-task-reminder – max. jedna připomínka na úkol a plánovaný začátek.';

CREATE INDEX IF NOT EXISTS idx_upcoming_task_reminder_log_created_at
  ON public.upcoming_task_reminder_log (created_at DESC);

ALTER TABLE public.upcoming_task_reminder_log ENABLE ROW LEVEL SECURITY;

-- Service role obchází RLS; pro běžné role žádný přístup (bez policy = zamítnuto).
