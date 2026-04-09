-- Seed prémiových komunikačních šablon pro životní cyklus rezervace.
-- POZOR: Upravte tenant_id na cílového tenanta před spuštěním.
-- Tabulka v aplikaci: tenant_message_templates.

WITH seed_data AS (
  SELECT * FROM (
    VALUES
      (
        'YOUR_TENANT_ID'::uuid,
        'check_in_self_checkin_cs',
        'Self Check-in',
        'Ahoj {guest_name}, vitej v apartmanu {apartment_name}. Samoobsluzny check-in je pripraven. Kod k trezoru je: {keybox}.',
        'cs',
        'check_in',
        10
      ),
      (
        'YOUR_TENANT_ID'::uuid,
        'check_in_self_checkin_en',
        'Self Check-in',
        'Hi {guest_name}, welcome to {apartment_name}. Your self check-in is ready. Keybox code: {keybox}.',
        'en',
        'check_in',
        11
      ),
      (
        'YOUR_TENANT_ID'::uuid,
        'check_in_parking_navigation_cs',
        'Parkovani a navigace',
        'Ahoj {guest_name}, tady jsou informace k parkovani pro {apartment_name}: {parking}',
        'cs',
        'check_in',
        20
      ),
      (
        'YOUR_TENANT_ID'::uuid,
        'check_in_parking_navigation_en',
        'Parking and navigation',
        'Hi {guest_name}, here are parking details for {apartment_name}: {parking}',
        'en',
        'check_in',
        21
      ),
      (
        'YOUR_TENANT_ID'::uuid,
        'general_day2_check_cs',
        'Kontrola po 1. noci',
        'Ahoj {guest_name}, jen kontrolujeme, zda je vse v poradku a jste v {apartment_name} spokojeni.',
        'cs',
        'general',
        30
      ),
      (
        'YOUR_TENANT_ID'::uuid,
        'general_day2_check_en',
        'Day 2 check',
        'Hi {guest_name}, just checking if everything is fine and you are enjoying your stay at {apartment_name}.',
        'en',
        'general',
        31
      ),
      (
        'YOUR_TENANT_ID'::uuid,
        'check_out_departure_instructions_cs',
        'Instrukce k odjezdu',
        'Ahoj {guest_name}, pripominame check-out z {apartment_name}. Dekujeme, ze nechate klice dle instrukci a zamknete apartman.',
        'cs',
        'check_out',
        40
      ),
      (
        'YOUR_TENANT_ID'::uuid,
        'check_out_departure_instructions_en',
        'Check-out instructions',
        'Hi {guest_name}, this is a reminder about check-out from {apartment_name}. Please leave keys as instructed and lock the apartment.',
        'en',
        'check_out',
        41
      ),
      (
        'YOUR_TENANT_ID'::uuid,
        'check_out_review_request_cs',
        'Zadost o recenzi',
        'Ahoj {guest_name}, dekujeme za pobyt v {apartment_name}. Budeme radi za recenzi: {review_link}',
        'cs',
        'check_out',
        50
      ),
      (
        'YOUR_TENANT_ID'::uuid,
        'check_out_review_request_en',
        'Review request',
        'Hi {guest_name}, thank you for staying at {apartment_name}. We would appreciate your review: {review_link}',
        'en',
        'check_out',
        51
      )
  ) AS t(tenant_id, key, name, body, language_code, trigger_context, order_index)
)
INSERT INTO tenant_message_templates (
  tenant_id,
  key,
  name,
  body,
  channel,
  language_code,
  trigger_context,
  order_index
)
SELECT
  s.tenant_id,
  s.key,
  s.name,
  s.body,
  'whatsapp_link' AS channel,
  s.language_code,
  s.trigger_context,
  s.order_index
FROM seed_data s
WHERE NOT EXISTS (
  SELECT 1
  FROM tenant_message_templates t
  WHERE t.tenant_id = s.tenant_id
    AND t.key = s.key
    AND t.deleted_at IS NULL
);
