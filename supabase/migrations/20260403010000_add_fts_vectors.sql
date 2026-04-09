-- Enterprise: Full-Text Search (tsvector) nad klíčovými entitami.
-- PROČ: Rychlé vyhledávání přes GIN bez full table scan; konfigurace „simple“ = bez stemování (vhodné pro jména, e-maily, reference).
-- Sloupce GENERATED ALWAYS ... STORED se přepočítají při INSERT/UPDATE zdrojových polí automaticky.

-- clients: CRM identita
ALTER TABLE public.clients
  ADD COLUMN search_vector tsvector
  GENERATED ALWAYS AS (
    to_tsvector(
      'simple',
      coalesce(name, '') || ' ' || coalesce(email, '') || ' ' || coalesce(phone, '')
    )
  ) STORED;

CREATE INDEX IF NOT EXISTS idx_clients_search ON public.clients USING GIN (search_vector);

COMMENT ON COLUMN public.clients.search_vector IS
  'FTS vektor (simple): name, email, phone.';

-- apartments: provozní byty
ALTER TABLE public.apartments
  ADD COLUMN search_vector tsvector
  GENERATED ALWAYS AS (
    to_tsvector(
      'simple',
      coalesce(name, '') || ' ' || coalesce(address, '') || ' ' || coalesce(code, '')
    )
  ) STORED;

CREATE INDEX IF NOT EXISTS idx_apartments_search ON public.apartments USING GIN (search_vector);

COMMENT ON COLUMN public.apartments.search_vector IS
  'FTS vektor (simple): name, address, code.';

-- tasks: operativa
ALTER TABLE public.tasks
  ADD COLUMN search_vector tsvector
  GENERATED ALWAYS AS (
    to_tsvector(
      'simple',
      coalesce(title, '') || ' ' || coalesce(custom_title, '') || ' ' ||
      coalesce(description, '') || ' ' || coalesce(custom_location, '') || ' ' ||
      coalesce(reference_number, '')
    )
  ) STORED;

CREATE INDEX IF NOT EXISTS idx_tasks_search ON public.tasks USING GIN (search_vector);

COMMENT ON COLUMN public.tasks.search_vector IS
  'FTS vektor (simple): title, custom_title, description, custom_location, reference_number.';

-- reservations: hosté a externí reference
ALTER TABLE public.reservations
  ADD COLUMN search_vector tsvector
  GENERATED ALWAYS AS (
    to_tsvector(
      'simple',
      coalesce(guest_name, '') || ' ' || coalesce(guest_phone, '') || ' ' ||
      coalesce(reference_number, '') || ' ' || coalesce(external_uid, '')
    )
  ) STORED;

CREATE INDEX IF NOT EXISTS idx_reservations_search ON public.reservations USING GIN (search_vector);

COMMENT ON COLUMN public.reservations.search_vector IS
  'FTS vektor (simple): guest_name, guest_phone, reference_number, external_uid.';
