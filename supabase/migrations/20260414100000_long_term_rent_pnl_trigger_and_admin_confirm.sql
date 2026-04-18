-- =============================================================================
-- FalcoNest – P&L příjem z dlouhodobého nájmu: trigger po dokončení rent_collection
-- + RLS pro admin/manager upsert příjmu u režimu notification (potvrzení převodu)
-- =============================================================================
-- PROČ: Režim „task“ zapisuje příjem automaticky při completed úkolu; režim
-- „notification“ potřebuje ruční potvrzení z Owner portálu nebo z adminu – dříve
-- neměli staff INSERT/UPDATE na apartment_investment_pnl_entries.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) Funkce + trigger: dokončený úkol rent_collection → upsert income P&L
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.apply_rent_collection_task_to_pnl()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rental_mode text;
  v_coll_mode text;
  v_rent numeric;
  v_key text;
  v_colon int;
  v_month date;
BEGIN
  IF TG_OP <> 'UPDATE' THEN
    RETURN NEW;
  END IF;

  IF NEW.deleted_at IS NOT NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.status IS DISTINCT FROM 'completed' THEN
    RETURN NEW;
  END IF;

  IF OLD.status IS NOT DISTINCT FROM 'completed' THEN
    RETURN NEW;
  END IF;

  IF lower(trim(coalesce(NEW.task_type, ''))) <> 'rent_collection' THEN
    RETURN NEW;
  END IF;

  IF NEW.apartment_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT a.rental_mode,
         a.rent_collection_mode,
         coalesce(a.rent_amount, 0)::numeric
    INTO v_rental_mode, v_coll_mode, v_rent
    FROM public.apartments a
   WHERE a.id = NEW.apartment_id
     AND a.deleted_at IS NULL;

  IF v_rental_mode IS NULL OR v_rental_mode <> 'long_term' THEN
    RETURN NEW;
  END IF;

  IF v_coll_mode IS NULL OR v_coll_mode <> 'task' THEN
    RETURN NEW;
  END IF;

  v_key := NEW.metadata ->> 'rent_cycle_key';
  IF v_key IS NULL OR length(trim(v_key)) < 12 THEN
    RETURN NEW;
  END IF;

  v_colon := strpos(v_key, ':');
  IF v_colon < 2 THEN
    RETURN NEW;
  END IF;

  BEGIN
    v_month := substring(v_key from v_colon + 1)::date;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NEW;
  END;

  IF v_month IS NULL THEN
    RETURN NEW;
  END IF;

  v_month := date_trunc('month', v_month)::date;

  IF extract(day from v_month) <> 1 THEN
    v_month := date_trunc('month', v_month)::date;
  END IF;

  INSERT INTO public.apartment_investment_pnl_entries (
    apartment_id,
    entry_month,
    entry_type,
    amount,
    description
  )
  VALUES (
    NEW.apartment_id,
    v_month,
    'income',
    v_rent,
    'Automatický výběr hotovosti (Úkol)'
  )
  ON CONFLICT ON CONSTRAINT apartment_investment_pnl_entries_apartment_month_type_uniq
  DO UPDATE SET
    amount = EXCLUDED.amount,
    description = EXCLUDED.description,
    updated_at = (now() AT TIME ZONE 'utc');

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.apply_rent_collection_task_to_pnl() IS
  'Po prvním přechodu úkolu rent_collection na completed: upsert income do apartment_investment_pnl_entries (měsíc z metadata.rent_cycle_key).';

DROP TRIGGER IF EXISTS tasks_apply_rent_collection_to_pnl ON public.tasks;

CREATE TRIGGER tasks_apply_rent_collection_to_pnl
  AFTER UPDATE OF status ON public.tasks
  FOR EACH ROW
  EXECUTE FUNCTION public.apply_rent_collection_task_to_pnl();

-- -----------------------------------------------------------------------------
-- 2) RLS: admin/manager může INSERT/UPDATE jen income u long_term + notification
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "apartment_investment_pnl_entries_admin_long_term_income_upsert"
  ON public.apartment_investment_pnl_entries;

CREATE POLICY "apartment_investment_pnl_entries_admin_long_term_income_upsert"
  ON public.apartment_investment_pnl_entries
  FOR INSERT
  TO authenticated
  WITH CHECK (
    entry_type = 'income'
    AND (
      public.is_super_admin()
      OR (
        public.is_tenant_admin_or_manager()
        AND EXISTS (
          SELECT 1
            FROM public.apartments a
           WHERE a.id = apartment_investment_pnl_entries.apartment_id
             AND a.tenant_id = public.my_tenant_id()
             AND a.deleted_at IS NULL
             AND a.rental_mode = 'long_term'
             AND a.rent_collection_mode = 'notification'
        )
      )
    )
  );

COMMENT ON POLICY "apartment_investment_pnl_entries_admin_long_term_income_upsert"
  ON public.apartment_investment_pnl_entries IS
  'INSERT income: super_admin nebo admin/manager tenanta jen u bytu long_term + notification (potvrzení převodu nájmu).';

DROP POLICY IF EXISTS "apartment_investment_pnl_entries_admin_long_term_income_update"
  ON public.apartment_investment_pnl_entries;

CREATE POLICY "apartment_investment_pnl_entries_admin_long_term_income_update"
  ON public.apartment_investment_pnl_entries
  FOR UPDATE
  TO authenticated
  USING (
    entry_type = 'income'
    AND (
      public.is_super_admin()
      OR (
        public.is_tenant_admin_or_manager()
        AND EXISTS (
          SELECT 1
            FROM public.apartments a
           WHERE a.id = apartment_investment_pnl_entries.apartment_id
             AND a.tenant_id = public.my_tenant_id()
             AND a.deleted_at IS NULL
             AND a.rental_mode = 'long_term'
             AND a.rent_collection_mode = 'notification'
        )
      )
    )
  )
  WITH CHECK (
    entry_type = 'income'
    AND (
      public.is_super_admin()
      OR (
        public.is_tenant_admin_or_manager()
        AND EXISTS (
          SELECT 1
            FROM public.apartments a
           WHERE a.id = apartment_investment_pnl_entries.apartment_id
             AND a.tenant_id = public.my_tenant_id()
             AND a.deleted_at IS NULL
             AND a.rental_mode = 'long_term'
             AND a.rent_collection_mode = 'notification'
        )
      )
    )
  );

COMMENT ON POLICY "apartment_investment_pnl_entries_admin_long_term_income_update"
  ON public.apartment_investment_pnl_entries IS
  'UPDATE income: stejné omezení jako INSERT (potvrzení převodu).';

NOTIFY pgrst, 'reload schema';
