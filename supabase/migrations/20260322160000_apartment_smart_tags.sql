-- Rozšíření apartments pro chytré komunikační placeholdery.
-- PROČ: Šablony životního cyklu rezervace potřebují keybox, parkování a odkaz na recenzi.

ALTER TABLE public.apartments
ADD COLUMN IF NOT EXISTS keybox_code text,
ADD COLUMN IF NOT EXISTS parking_instructions text,
ADD COLUMN IF NOT EXISTS review_link text;

COMMENT ON COLUMN public.apartments.keybox_code IS
'Kód k trezoru / smart locku pro komunikaci s hostem.';

COMMENT ON COLUMN public.apartments.parking_instructions IS
'Instrukce k parkování, GPS navigace a doplňující informace pro hosta.';

COMMENT ON COLUMN public.apartments.review_link IS
'URL odkaz na zanechání recenze po pobytu (Booking/Airbnb/Google).';
