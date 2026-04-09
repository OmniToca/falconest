-- =============================================================================
-- FalcoNest – Katalog: placený modul „Vlastní Twilio a WhatsApp“ (pod Komunikací)
-- =============================================================================
-- PROČ: Paywall a aktivace přes existující [tenant_modules] + [isModuleActive] ve Flutteru.
-- Cena 49 EUR = měsíční paušál v produktové logice; v DB zůstává [pricing_type] = fixed
-- (constraint CHECK nepovoluje hodnotu „monthly“).
-- =============================================================================

INSERT INTO public.modules (
  key,
  name,
  parent_module_key,
  description,
  price_eur,
  pricing_type,
  show_in_menu,
  order_index
)
VALUES (
  'custom_twilio_whatsapp',
  'Vlastní Twilio a WhatsApp',
  'communication',
  'Napojení vlastního Twilio účtu, odesílání přes WhatsApp a SMS bez marže.',
  49,
  'fixed',
  true,
  10
)
ON CONFLICT (key) DO NOTHING;
