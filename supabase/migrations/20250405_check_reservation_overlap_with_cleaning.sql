-- Trigger pro kontrolu kolize rezervací s dynamickým Cleaning Buffer.
-- Zohledňuje: standard_cleaning_duration bytu + fix 60 min + extra minuty ze služeb (reservation_services → apartment_services → tenant_services.duration_minutes).

CREATE OR REPLACE FUNCTION check_reservation_overlap_with_cleaning()
RETURNS TRIGGER AS $$
DECLARE
    v_standard_cleaning_duration INT;
    v_new_check_in TIMESTAMPTZ;
    v_new_check_out TIMESTAMPTZ;
    v_conflict_exists BOOLEAN;
BEGIN
    -- 1. Získání standardní doby úklidu bytu
    SELECT COALESCE(standard_cleaning_duration, 120)
    INTO v_standard_cleaning_duration
    FROM apartments WHERE id = NEW.apartment_id;

    -- 2. Sestavení časů nové rezervace
    v_new_check_in := COALESCE(NEW.arrival_time, NEW.start_date::timestamptz + interval '15 hours');
    v_new_check_out := COALESCE(NEW.departure_time, NEW.end_date::timestamptz + interval '10 hours');

    -- 3. Kontrola konfliktu s dynamickým časem služeb
    SELECT EXISTS (
        SELECT 1
        FROM reservations r
        -- Dynamický součet extra minut z přiřazených služeb pro existující rezervaci
        LEFT JOIN LATERAL (
            SELECT COALESCE(SUM(ts.duration_minutes), 0)::INT AS extra_mins
            FROM reservation_services rs
            JOIN apartment_services aps ON rs.apartment_service_id = aps.id
            JOIN tenant_services ts ON aps.service_id = ts.id
            WHERE rs.reservation_id = r.id
        ) s ON true
        WHERE r.apartment_id = NEW.apartment_id
          AND r.id != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid)
          AND r.deleted_at IS NULL
          AND (
              -- Nový Check-In < (Stávající Check-Out + Fix 60 + Base úklid + Extra služby)
              v_new_check_in < (COALESCE(r.departure_time, r.end_date::timestamptz + interval '10 hours')
                                + ((v_standard_cleaning_duration + 60 + COALESCE(s.extra_mins, 0)) || ' minutes')::interval)
              AND
              -- Nová rezervace: Check-Out + buffer > Stávající Check-In (základní úklid, NEW služby se do DB insertují až po rezervaci)
              (v_new_check_out + ((v_standard_cleaning_duration + 60) || ' minutes')::interval) >
              COALESCE(r.arrival_time, r.start_date::timestamptz + interval '15 hours')
          )
    ) INTO v_conflict_exists;

    IF v_conflict_exists THEN
        RAISE EXCEPTION 'RESERVATION_OVERLAP: Termín koliduje s jinou rezervací nebo rozšířeným časem na úklid (včetně doplňkových služeb).';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Vytvoření triggeru (DROP IF EXISTS pro idempotenci)
DROP TRIGGER IF EXISTS trg_check_reservation_overlap ON reservations;
CREATE TRIGGER trg_check_reservation_overlap
    BEFORE INSERT OR UPDATE ON reservations
    FOR EACH ROW
    EXECUTE FUNCTION check_reservation_overlap_with_cleaning();
