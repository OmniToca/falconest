-- Odstranění duplicitního pole pro kód trezoru.
-- PROČ: V systému ponecháváme jediný zdroj pravdy `apartments.keybox`.

ALTER TABLE public.apartments
DROP COLUMN IF EXISTS keybox_code;
