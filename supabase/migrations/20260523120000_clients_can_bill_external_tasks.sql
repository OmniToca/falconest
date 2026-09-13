-- =============================================================================
-- FalcoNest – hybridní B2B klienti: flag pro výběr v externích úkolech
-- =============================================================================
-- PROČ: Majitel (client_type = owner) může zároveň objednávat ad-hoc externí práce
-- (např. ESP House) – bez duplicitního CRM záznamu a bez zahlcení roletky všemi majiteli.
-- Fakturace seskupuje úkoly podle clients.id → jedna souhrnná faktura na měsíc.
-- =============================================================================

ALTER TABLE public.clients
  ADD COLUMN IF NOT EXISTS can_bill_external_tasks boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.clients.can_bill_external_tasks IS
  'True = klient se zobrazí v roletce „Klient“ u typu úkolu Externí služba (hybridní B2B partner s rolí majitele).';

-- ESP House – aktivace hybridní role (upravte jméno podle produkčního záznamu).
UPDATE public.clients
   SET can_bill_external_tasks = true
 WHERE deleted_at IS NULL
   AND lower(trim(name)) = lower('ESP House');

NOTIFY pgrst, 'reload schema';
