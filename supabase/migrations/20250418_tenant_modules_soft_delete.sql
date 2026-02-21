-- =============================================================================
-- FalcoNest – Soft Delete pro tenant_modules (standardizace s ostatními tabulkami)
-- =============================================================================
-- Aplikuje ověřený vzor Soft Delete (deleted_at): místo fyzického DELETE se
-- volá UPDATE deleted_at = now(). Záznamy s deleted_at IS NOT NULL se při
-- načítání vynechávají. Zachovává fakturační historii pro budoucí Stripe.
-- =============================================================================

ALTER TABLE public.tenant_modules
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz;

COMMENT ON COLUMN public.tenant_modules.deleted_at IS 'Soft delete: NULL = aktivní modul; NOT NULL = modul vypnutý (pro zachování fakturační historie). Místo DELETE se volá UPDATE deleted_at = now().';

CREATE INDEX IF NOT EXISTS idx_tenant_modules_deleted_at ON public.tenant_modules(deleted_at);
