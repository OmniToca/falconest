-- Režim pronájmu bytu (krátkodobý STR vs. dlouhodobý) + volitelná platnost nájemní smlouvy.
-- PROČ: STR výchozí chování beze změny; u long_term lze v aplikaci evidovat Od–Do (nullable).

ALTER TABLE public.apartments
  ADD COLUMN IF NOT EXISTS rental_mode text NOT NULL DEFAULT 'short_term'
    CHECK (rental_mode IN ('short_term', 'long_term'));

ALTER TABLE public.apartments
  ADD COLUMN IF NOT EXISTS lease_start_date date NULL;

ALTER TABLE public.apartments
  ADD COLUMN IF NOT EXISTS lease_end_date date NULL;

COMMENT ON COLUMN public.apartments.rental_mode IS
  'short_term = Airbnb/Booking styl; long_term = dlouhodobý nájem (volitelné lease_* datumy).';

COMMENT ON COLUMN public.apartments.lease_start_date IS
  'Začátek platnosti smlouvy u long_term; u short_term typicky NULL.';

COMMENT ON COLUMN public.apartments.lease_end_date IS
  'Konec platnosti smlouvy u long_term; u short_term typicky NULL.';
