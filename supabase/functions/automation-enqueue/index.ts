// =============================================================================
// FalcoNest Automations - Enqueue Worker (Mozek)
// -----------------------------------------------------------------------------
// Tato Edge Function je plánovací "mozek" pro modul Automations:
// - bere aktivní pravidla (`automation_rules`)
// - najde relevantní entity (rezervace/úkoly podle `trigger_event`)
// - vypočítá kdy mají být zprávy odeslány (`scheduled_for = eventTime + offset`)
// - respektuje noční klid (`quiet_hours_start/quiet_hours_end`)
// - zajišťuje idempotenci (neenqueueuje duplicity do `automation_message_queue`)
// - provede základní rendering šablony do `editable_payload.text`
//
// Tohle je FÁZE 2/“Enqueue” (Dispatch už existuje).
// VUI pak umí frontu zobrazit manažerovi.
// =============================================================================

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type AutomationChannel = "email" | "sms" | "whatsapp" | "internal_push";

type QueueStatus = "pending" | "processing" | "sent" | "failed" | "cancelled";

type AutomationRuleRow = {
  id: string;
  tenant_id: string;
  name: string;
  is_active: boolean;
  trigger_event: string;
  offset_minutes: number;
  channel: AutomationChannel;
  template_id: string;
  target_entity: string;
  /** PROČ: Příjemce FCM u kanálu internal_push (profiles.id). */
  staff_profile_id: string | null;
  quiet_hours_start: string | null; // 'HH:MM:SS'
  quiet_hours_end: string | null; // 'HH:MM:SS'
};

/// Blok jednoho jazyka uvnitř JSONB `translations` (stejná konvence jako mobilní aplikace).
type TemplateTranslationBlock = {
  body?: string;
  subject?: string;
  name?: string;
};

type TenantMessageTemplateRow = {
  id: string;
  translations: Record<string, TemplateTranslationBlock> | null;
  email_subject: string | null;
  channel: string;
};

type ReservationCandidate = {
  id: string;
  apartment_id: string;
  guest_name: string | null;
  guest_phone: string | null;
  guest_language: string | null;
  arrival_time: string | null; // timestamptz
  departure_time: string | null; // timestamptz
  start_date: string | null; // date 'YYYY-MM-DD'
  end_date: string | null; // date 'YYYY-MM-DD'
  apartments: { keybox: string | null; name?: string | null } | null;
};

type TaskCandidate = {
  id: string;
  reservation_id: string | null;
  client_id: string | null;
  apartment_id: string | null;
  due_date: string | null; // timestamptz
  scheduled_start: string | null; // timestamptz
};

type ClientCandidate = {
  id: string;
  name: string;
  phone: string | null;
  language_code: string | null;
};

type QueueRowKey = {
  rule_id: string;
  entity_type: "reservation" | "task";
  entity_id: string;
};

type QueueInsertPayload = {
  status: QueueStatus;
  scheduled_for: string;
  editable_payload: Record<string, unknown>;
  recipient_contact: string | null;
};

function requireEnv(name: string): string {
  const v = Deno.env.get(name);
  if (!v || v.trim() === "") throw new Error(`Chybí environment variable: ${name}`);
  return v;
}

function nowUtc(): Date {
  return new Date();
}

function toIsoUtc(d: Date): string {
  return d.toISOString();
}

function startOfUtcDay(d: Date): Date {
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate(), 0, 0, 0, 0));
}

function dateOnlyIso(d: Date): string {
  // Vrací 'YYYY-MM-DD' v UTC.
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, "0");
  const day = String(d.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

function parseTimeToMinutes(timeStr: string): number {
  // Očekává 'HH:MM:SS' (podle DB typ `time` se to takto typicky vrací).
  const [hhRaw, mmRaw] = timeStr.split(":");
  const hh = Number(hhRaw);
  const mm = Number(mmRaw);
  if (!Number.isFinite(hh) || !Number.isFinite(mm)) return 0;
  return hh * 60 + mm;
}

function isInQuietHoursUtc(scheduledFor: Date, quietStart: string | null, quietEnd: string | null): boolean {
  if (!quietStart || !quietEnd) return false;

  const startMin = parseTimeToMinutes(quietStart);
  const endMin = parseTimeToMinutes(quietEnd);
  if (startMin === endMin) return false;

  const timeMin = scheduledFor.getUTCHours() * 60 + scheduledFor.getUTCMinutes();

  // Quiet window může přecházet přes půlnoc (typicky 22:00 - 08:00).
  if (startMin < endMin) {
    return timeMin >= startMin && timeMin < endMin;
  }

  // wrap: např. 22:00 - 08:00
  return timeMin >= startMin || timeMin < endMin;
}

function moveToNextAllowedTimeUtc(
  scheduledFor: Date,
  quietStart: string | null,
  quietEnd: string | null,
): Date {
  if (!quietStart || !quietEnd) return scheduledFor;

  const startMin = parseTimeToMinutes(quietStart);
  const endMin = parseTimeToMinutes(quietEnd);
  if (startMin === endMin) return scheduledFor;

  const [endHour, endMinute] = [Math.floor(endMin / 60), endMin % 60];
  const timeMin = scheduledFor.getUTCHours() * 60 + scheduledFor.getUTCMinutes();

  // Pokud quiet window NEpřesahuje půlnoc (start < end), posunujeme na tentýž den `quietEnd`.
  if (startMin < endMin) {
    const shifted = new Date(scheduledFor.getTime());
    shifted.setUTCHours(endHour, endMinute, 0, 0);
    return shifted;
  }

  // wrap (start > end): quietEnd je "ráno".
  // Pokud jsme v quiet window večer (timeMin >= startMin), posuň na quietEnd následujícího dne.
  // Pokud jsme v quiet window v noci/půlnocí (timeMin < endMin), posuň na quietEnd ještě stejného dne.
  const shifted = new Date(scheduledFor.getTime());
  if (timeMin >= startMin) {
    // večerní část quiet okna -> end bude zítra
    shifted.setUTCDate(shifted.getUTCDate() + 1);
  }
  shifted.setUTCHours(endHour, endMinute, 0, 0);
  return shifted;
}

/// Normalizuje kód jazyka z `reservations.guest_language` nebo `clients.language_code`.
/// PROČ: Prázdný řetězec nebo NULL znamená „nevyplněno“ – použijeme stejný výchozí jazyk jako mobilní app (`en`).
function normalizeTargetLang(raw: string | null | undefined): string {
  const v = (raw ?? "").trim().toLowerCase();
  return v.length > 0 ? v : "en";
}

/// Vrací tělo zprávy z JSONB `translations` pro zvolený [targetLang].
///
/// PROČ: Sloupce `body` / `language_code` už v DB neexistují – veškerý text je v mapě `translations[lang].body`.
/// Fallback pořadí (když překlad pro hosta chybí nebo je prázdný):
/// 1) přesný klíč `targetLang`
/// 2) `en`, `cs`, `es` (nejčastější jazyky v tenantovi)
/// 3) libovolný první neprázdný `body` v objektu
function resolveTemplateContent(
  translations: Record<string, TemplateTranslationBlock> | null,
  targetLang: string,
): string {
  const map = translations ?? {};
  const g = targetLang.trim().toLowerCase();
  if (g) {
    const b = map[g]?.body;
    if (typeof b === "string" && b.trim()) return b.trim();
  }
  for (const k of ["en", "cs", "es"]) {
    const b = map[k]?.body;
    if (typeof b === "string" && b.trim()) return b.trim();
  }
  for (const k of Object.keys(map)) {
    const b = map[k]?.body;
    if (typeof b === "string" && b.trim()) return b.trim();
  }
  return "";
}

/// Předmět e-mailu: nejdřív překlad pro [targetLang], pak kořenový `email_subject`, pak stejné jazykové fallbacky jako u těla.
function resolveEmailSubject(
  template: TenantMessageTemplateRow,
  targetLang: string,
): string | null {
  const map = template.translations ?? {};
  const g = targetLang.trim().toLowerCase();
  const trySubject = (key: string): string | null => {
    const s = map[key]?.subject;
    if (typeof s === "string" && s.trim()) return s.trim();
    return null;
  };
  if (g) {
    const a = trySubject(g);
    if (a) return a;
  }
  const root = template.email_subject?.trim();
  if (root) return root;
  for (const k of ["en", "cs", "es"]) {
    const a = trySubject(k);
    if (a) return a;
  }
  for (const k of Object.keys(map)) {
    const a = trySubject(k);
    if (a) return a;
  }
  return template.email_subject?.trim() || null;
}

function extractTextFromTemplate(templateBody: string, replacements: Record<string, string>): string {
  // PROČ: Řetězení placeholderů v této V1 děláme jednoduše přes replace.
  // Neřešíme složitou logiku/placeholder registry jako v Dartu (to bude až v pozdějších fázích),
  // ale pro PO stačí ZÁKLAD pro {guest_name} a {keybox}.
  let text = templateBody ?? "";
  for (const [key, value] of Object.entries(replacements)) {
    // Placeholdery jsou ve tvaru `{guest_name}`.
    text = text.replaceAll(`{${key}}`, value ?? "");
  }
  return text;
}

const DEFAULT_TENANT_TZ = "Europe/Madrid";

function normalizeTenantTz(raw: string | null | undefined): string {
  const v = (raw ?? "").trim();
  return v.length > 0 ? v : DEFAULT_TENANT_TZ;
}

function fmtDdMmYyyyInZone(d: Date, timeZone: string): string {
  const tz = normalizeTenantTz(timeZone);
  const partsFor = (zone: string) =>
    new Intl.DateTimeFormat("en-GB", {
      timeZone: zone,
      day: "2-digit",
      month: "2-digit",
      year: "numeric",
    }).formatToParts(d);
  try {
    const parts = partsFor(tz);
    const g = (t: string) => parts.find((p) => p.type === t)?.value ?? "";
    return `${g("day")}.${g("month")}.${g("year")}`;
  } catch {
    const parts = partsFor(DEFAULT_TENANT_TZ);
    const g = (t: string) => parts.find((p) => p.type === t)?.value ?? "";
    return `${g("day")}.${g("month")}.${g("year")}`;
  }
}

function fmtHhMm24InZone(d: Date, timeZone: string): string {
  const tz = normalizeTenantTz(timeZone);
  const partsFor = (zone: string) =>
    new Intl.DateTimeFormat("en-GB", {
      timeZone: zone,
      hour: "2-digit",
      minute: "2-digit",
      hourCycle: "h23",
    }).formatToParts(d);
  try {
    const parts = partsFor(tz);
    const g = (t: string) => parts.find((p) => p.type === t)?.value ?? "";
    return `${g("hour")}:${g("minute")}`;
  } catch {
    const parts = partsFor(DEFAULT_TENANT_TZ);
    const g = (t: string) => parts.find((p) => p.type === t)?.value ?? "";
    return `${g("hour")}:${g("minute")}`;
  }
}

/** Kalendářní datum YYYY-MM-DD → UTC půlden (stabilní kalendářní den ve většině IANA zón). */
function parseIsoDateOnlyToUtcNoon(iso: string | null | undefined): Date | null {
  if (!iso) return null;
  const s = iso.trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(s)) return null;
  const [y, mo, d] = s.split("-").map(Number);
  return new Date(Date.UTC(y, mo - 1, d, 12, 0, 0));
}

function buildReservationDatePlaceholders(
  r: ReservationCandidate,
  tenantTz: string,
): Record<string, string> {
  const tz = normalizeTenantTz(tenantTz);
  const arrivalInstant = r.arrival_time
    ? new Date(r.arrival_time)
    : parseIsoDateOnlyToUtcNoon(r.start_date);
  const departureInstant = r.departure_time
    ? new Date(r.departure_time)
    : parseIsoDateOnlyToUtcNoon(r.end_date);
  return {
    task_date: "",
    task_time: "",
    arrival_date: arrivalInstant ? fmtDdMmYyyyInZone(arrivalInstant, tz) : "",
    arrival_time: r.arrival_time ? fmtHhMm24InZone(new Date(r.arrival_time), tz) : "",
    departure_date: departureInstant ? fmtDdMmYyyyInZone(departureInstant, tz) : "",
    departure_time: r.departure_time ? fmtHhMm24InZone(new Date(r.departure_time), tz) : "",
  };
}

function computeEventTimeReservationCheckIn(r: ReservationCandidate): Date | null {
  // Preferujeme timestamptz (arrival_time). V DB je default computed z start_date + 15h.
  if (r.arrival_time) return new Date(r.arrival_time);
  if (r.start_date) {
    // Fallback: start_date (date) + 15 hodin jako v DB default.
    const dt = new Date(`${r.start_date}T00:00:00.000Z`);
    dt.setUTCHours(dt.getUTCHours() + 15);
    return dt;
  }
  return null;
}

function computeEventTimeReservationCheckOut(r: ReservationCandidate): Date | null {
  // Preferujeme timestamptz (departure_time). V DB je default computed z end_date + 10h.
  if (r.departure_time) return new Date(r.departure_time);
  if (r.end_date) {
    const dt = new Date(`${r.end_date}T00:00:00.000Z`);
    dt.setUTCHours(dt.getUTCHours() + 10);
    return dt;
  }
  return null;
}

function computeEventTimeTaskStart(t: TaskCandidate): Date | null {
  // Preferujeme scheduled_start, fallback due_date.
  if (t.scheduled_start) return new Date(t.scheduled_start);
  if (t.due_date) return new Date(t.due_date);
  return null;
}

function buildRecipientContact(args: {
  channel: AutomationChannel;
  guestPhone: string | null;
  clientPhone: string | null;
}): string | null {
  // Zatím: pro všechny kanály použijeme telefon jako recipient_contact.
  // PROČ: DB (reservations) nemá email; fallback na telefon je bezpečnější, aby UI i dispatch mohly fungovat.
  const phone = args.guestPhone ?? args.clientPhone;
  if (!phone) return null;
  const trimmed = phone.trim();
  if (!trimmed) return null;
  return trimmed;
}

function buildEditablePayload(args: {
  text: string;
  guestName: string;
  keybox: string;
  channel: AutomationChannel;
  emailSubject?: string | null;
  meta: Record<string, unknown>;
}): Record<string, unknown> {
  const out: Record<string, unknown> = {
    // UI v admin_automations_screen extrahuje primárně `payload.text`.
    text: args.text,
    guest_name: args.guestName,
    keybox: args.keybox,
    ...args.meta,
  };
  // PROČ: SendGrid / dispatch potřebují předmět zvlášť od těla; u SMS/WhatsApp klíč ignorujeme.
  if (args.channel === "email" && args.emailSubject && args.emailSubject.trim()) {
    out.email_subject = args.emailSubject.trim();
  }
  return out;
}

async function queueEntryExists(supabase: ReturnType<typeof createClient>, args: QueueRowKey): Promise<boolean> {
  const { data, error } = await supabase
    .from("automation_message_queue")
    .select("id")
    .eq("rule_id", args.rule_id)
    .eq("entity_type", args.entity_type)
    .eq("entity_id", args.entity_id)
    .limit(1)
    .maybeSingle();

  if (error) throw error;
  return !!data;
}

serve(async (req) => {
  const { requireServiceRoleBearer } = await import("../_shared/edge_auth.ts")
  const denied = requireServiceRoleBearer(req)
  if (denied) return denied

  const supabaseUrl = requireEnv("SUPABASE_URL");
  const serviceRoleKey = requireEnv("SUPABASE_SERVICE_ROLE_KEY");

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  const now = nowUtc();

  // Abychom neznepřístupnili API a nezahltli DB, dáváme limit na počet enqueue insertů.
  // Dispatch má zase limit pro odesílání.
  const maxEnqueuedPerRun = Number(Deno.env.get("AUTOMATION_ENQUEUE_LIMIT") ?? "50");

  // 1) NAČTENÍ PRAVIDEL
  const { data: rules, error: rulesError } = await supabase
    .from("automation_rules")
    .select(
      "id, tenant_id, name, is_active, trigger_event, offset_minutes, channel, template_id, target_entity, staff_profile_id, quiet_hours_start, quiet_hours_end",
    )
    .eq("is_active", true);

  if (rulesError) {
    console.error("[enqueue] Failed to load rules:", rulesError);
    return new Response(JSON.stringify({ ok: false, error: rulesError.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const activeRules = (rules ?? []) as AutomationRuleRow[];

  // Cache šablony (translations jsonb), aby každé pravidlo nemuselo fetchovat znovu.
  const templateCache = new Map<string, TenantMessageTemplateRow>();

  async function getTemplateRow(templateId: string): Promise<TenantMessageTemplateRow> {
    const cached = templateCache.get(templateId);
    if (cached) return cached;

    const { data, error } = await supabase
      .from("tenant_message_templates")
      .select("id, translations, email_subject, channel")
      .eq("id", templateId)
      .single();

    if (error) throw error;
    const row = data as TenantMessageTemplateRow;
    templateCache.set(templateId, row);
    return row;
  }

  const createdIds: string[] = [];
  let enqueuedCount = 0;

  const tenantTzCache = new Map<string, string>();

  async function getTenantIanaTimezone(tenantId: string): Promise<string> {
    const hit = tenantTzCache.get(tenantId);
    if (hit !== undefined) return hit;
    try {
      const { data, error } = await supabase
        .from("tenants")
        .select("timezone")
        .eq("id", tenantId)
        .maybeSingle();
      if (error) throw error;
      const raw = ((data as { timezone?: string } | null)?.timezone ?? "").trim();
      const z = raw.length > 0 ? raw : DEFAULT_TENANT_TZ;
      tenantTzCache.set(tenantId, z);
      return z;
    } catch (e) {
      console.warn("[enqueue] tenant timezone fetch failed:", e);
      tenantTzCache.set(tenantId, DEFAULT_TENANT_TZ);
      return DEFAULT_TENANT_TZ;
    }
  }

  // Z pohledu “blíží se událost” používáme okno pro eventTime tak, aby computed scheduled_for
  // padlo do rozumného rozsahu.
  // - plánujeme jen takové položky, které dispatch stihne ještě v horizontu (teď až za pár dní)
  // - idempotence zabrání duplicitám, ale nechceme dělat obrovské skeny
  const scheduledWindowMin = new Date(now.getTime() - 10 * 60 * 1000); // -10 minut
  const scheduledWindowMax = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000); // +3 dny

  for (const rule of activeRules) {
    if (enqueuedCount >= maxEnqueuedPerRun) break;

    const tenantTz = await getTenantIanaTimezone(rule.tenant_id);

    // V1 guest: SMS/e-mail/WhatsApp na kontakt hosta.
    // internal_push: pouze `target_entity = staff` + vyplněné `staff_profile_id` (FCM dispečer).
    const targetEntityLower = rule.target_entity.trim().toLowerCase();
    const isInternalPush = rule.channel === "internal_push";
    if (isInternalPush) {
      if (targetEntityLower !== "staff") {
        console.warn(
          `[enqueue] Pravidlo ${rule.id}: internal_push vyžaduje target_entity=staff (aktuálně: ${targetEntityLower})`,
        );
        continue;
      }
      const sid = (rule.staff_profile_id ?? "").trim();
      if (!sid) {
        console.warn(`[enqueue] Pravidlo ${rule.id}: internal_push bez staff_profile_id`);
        continue;
      }
    } else if (targetEntityLower !== "guest") {
      continue;
    }

    const entityTypeForRule =
      rule.trigger_event === "task_start"
        ? "task"
        : rule.trigger_event.startsWith("reservation_")
          ? "reservation"
          : null;

    if (!entityTypeForRule) continue;

    const template = await getTemplateRow(rule.template_id);

    // 2) ZPRACOVÁNÍ PRAVIDLA (candidates)
    // V této V1 děláme “základní“ logiku pro trigger_event:
    // - reservation_check_in / reservation_check_out
    // - task_start
    //
    // Poznámka:
    // - eventTime v DB má timezone (timestamptz). Když posíláme do queue, používáme UTC ISO.
    // - quiet hours bereme jako “čas bez timezone” a vyhodnocujeme v UTC pro konzistenci.
    const offsetMs = rule.offset_minutes * 60 * 1000;

    // eventTime window vypočítáme inverzně z scheduled window a offsetu.
    const eventWindowMin = new Date(scheduledWindowMin.getTime() - offsetMs);
    const eventWindowMax = new Date(scheduledWindowMax.getTime() - offsetMs);

    let reservationCandidates: ReservationCandidate[] = [];
    let taskCandidates: TaskCandidate[] = [];

    if (rule.trigger_event === "reservation_check_in") {
      const minDate = dateOnlyIso(eventWindowMin);
      const maxDate = dateOnlyIso(eventWindowMax);
      const { data, error } = await supabase
        .from("reservations")
        .select(
          "id, apartment_id, guest_name, guest_phone, guest_language, arrival_time, start_date, apartments(keybox,name)",
        )
        .eq("status", "confirmed")
        .gte("start_date", minDate)
        .lte("start_date", maxDate)
        .is("deleted_at", null);

      if (error) throw error;
      reservationCandidates = (data ?? []) as ReservationCandidate[];
    }

    if (rule.trigger_event === "reservation_check_out") {
      const minDate = dateOnlyIso(eventWindowMin);
      const maxDate = dateOnlyIso(eventWindowMax);
      const { data, error } = await supabase
        .from("reservations")
        .select(
          "id, apartment_id, guest_name, guest_phone, guest_language, departure_time, end_date, apartments(keybox,name)",
        )
        .eq("status", "confirmed")
        .gte("end_date", minDate)
        .lte("end_date", maxDate)
        .is("deleted_at", null);

      if (error) throw error;
      reservationCandidates = (data ?? []) as ReservationCandidate[];
    }

    if (rule.trigger_event === "task_start") {
      // task due/scheduled start je timestamptz, takže filtrujeme přímo datem v čase.
      // V případě, že tasks mají due_date v jiném rozmezí než scheduled_start,
      // stále máme “range” a idempotence odstraní duplicitní enqueue.
      const dueMinIso = eventWindowMin.toISOString();
      const dueMaxIso = eventWindowMax.toISOString();

      const { data, error } = await supabase
        .from("tasks")
        .select("id, reservation_id, client_id, apartment_id, due_date, scheduled_start, status")
        .gte("due_date", dueMinIso)
        .lte("due_date", dueMaxIso)
        .is("deleted_at", null);

      if (error) throw error;

      const raw = data ?? [];
      // Omezíme kandidáty i na UI/worker straně.
      taskCandidates = (raw as TaskCandidate[]).slice(0, 100);
    }

    // 3) Kandidáti -> scheduled_for -> quiet hours -> idempotence -> insert do queue
    if (entityTypeForRule === "reservation") {
      for (const r of reservationCandidates) {
        if (enqueuedCount >= maxEnqueuedPerRun) break;

        const eventTime =
          rule.trigger_event === "reservation_check_in"
            ? computeEventTimeReservationCheckIn(r)
            : computeEventTimeReservationCheckOut(r);

        if (!eventTime) continue;

        let scheduledFor = new Date(eventTime.getTime() + offsetMs);

        if (isInQuietHoursUtc(scheduledFor, rule.quiet_hours_start, rule.quiet_hours_end)) {
          scheduledFor = moveToNextAllowedTimeUtc(
            scheduledFor,
            rule.quiet_hours_start,
            rule.quiet_hours_end,
          );
        }

        // Pokud je scheduled_for “hodně v minulosti”, nemačkáme zbytečně queue.
        // Dispatch má vlastní limit, ale queue by mohla růst.
        if (scheduledFor.getTime() < now.getTime() - 5 * 60 * 1000) continue;

        // 4) IDEMPOTENCE
        const exists = await queueEntryExists(supabase, {
          rule_id: rule.id,
          entity_type: "reservation",
          entity_id: r.id,
        });
        if (exists) continue;

        // 5) RENDER SHOT
        const guestName = (r.guest_name ?? "").trim();
        const guestPhone = (r.guest_phone ?? "").trim() || null;
        const keybox = (r.apartments?.keybox ?? "").trim();
        const staffRecipient = (rule.staff_profile_id ?? "").trim();
        const recipientForQueue = isInternalPush ? staffRecipient : guestPhone;

        // Jazyk: rezervace.host (guest_language), výchozí `en` pokud není vyplněno.
        const targetLangReservation = normalizeTargetLang(r.guest_language);
        const rawBodyReservation = resolveTemplateContent(template.translations, targetLangReservation);
        const resDatePh = buildReservationDatePlaceholders(r, tenantTz);
        const renderedText = extractTextFromTemplate(rawBodyReservation, {
          guest_name: guestName,
          keybox: keybox,
          ...resDatePh,
        });
        const emailSubReservation = rule.channel === "email"
          ? resolveEmailSubject(template, targetLangReservation)
          : null;

        const editablePayload = buildEditablePayload({
          text: renderedText,
          guestName: guestName || "",
          keybox,
          channel: rule.channel,
          emailSubject: emailSubReservation,
          meta: {
            rule_id: rule.id,
            trigger_event: rule.trigger_event,
            template_id: rule.template_id,
            ...(isInternalPush
              ? { reservation_id: r.id, staff_profile_id: staffRecipient }
              : {}),
          },
        });

        // V UI čekárny se zobrazuje:
        // - scheduled_for
        // - channel
        // - recipient_contact
        // - text z editable_payload.text
        await supabase.from("automation_message_queue").insert({
          tenant_id: rule.tenant_id,
          rule_id: rule.id,
          entity_id: r.id,
          entity_type: "reservation",
          scheduled_for: toIsoUtc(scheduledFor),
          status: "pending",
          channel: rule.channel,
          recipient_contact: recipientForQueue,
          editable_payload: editablePayload,
          attempt_count: 0,
          last_error: null,
        });

        enqueuedCount++;
        createdIds.push(r.id);
      }
    }

    if (entityTypeForRule === "task") {
      for (const t of taskCandidates) {
        if (enqueuedCount >= maxEnqueuedPerRun) break;

        const eventTime = computeEventTimeTaskStart(t);
        if (!eventTime) continue;

        let scheduledFor = new Date(eventTime.getTime() + offsetMs);
        if (isInQuietHoursUtc(scheduledFor, rule.quiet_hours_start, rule.quiet_hours_end)) {
          scheduledFor = moveToNextAllowedTimeUtc(
            scheduledFor,
            rule.quiet_hours_start,
            rule.quiet_hours_end,
          );
        }

        if (scheduledFor.getTime() < now.getTime() - 5 * 60 * 1000) continue;

        const exists = await queueEntryExists(supabase, {
          rule_id: rule.id,
          entity_type: "task",
          entity_id: t.id,
        });
        if (exists) continue;

        // PROČ: Pro rendering placeholderů potřebujeme:
        // - guest_name (z reservation nebo clients)
        // - keybox (z apartment přes reservation.apartment_id nebo task.apartment_id)
        // - jazyk pro výběr textu z translations
        let guestName = "";
        let recipientPhone: string | null = null;
        let keybox = "";
        let guestLang: string | null = null;

        if (t.reservation_id) {
          const { data: res, error } = await supabase
            .from("reservations")
            .select("id, guest_name, guest_phone, guest_language, apartment_id, apartments(keybox)")
            .eq("id", t.reservation_id)
            .maybeSingle();
          if (error) throw error;
          const rr = res as (ReservationCandidate & { guest_phone: string | null }) | null;
          guestName = (rr?.guest_name ?? "").trim();
          recipientPhone = (rr?.guest_phone ?? "").trim() || null;
          keybox = (rr?.apartments?.keybox ?? "").trim();
          guestLang = (rr?.guest_language ?? "").trim() || null;
        } else if (t.client_id) {
          const { data: client, error } = await supabase
            .from("clients")
            .select("id, name, phone, language_code")
            .eq("id", t.client_id)
            .maybeSingle();
          if (error) throw error;
          const c = client as ClientCandidate | null;
          guestName = (c?.name ?? "").trim();
          recipientPhone = (c?.phone ?? "").trim() || null;
          guestLang = (c?.language_code ?? "").trim() || null;
          // keybox není k dispozici pro externí klienty (bez apartmánu).
          keybox = "";
        } else if (t.apartment_id) {
          // edge-case: task bez reservation/client ale má apartment_id.
          const { data: apt, error } = await supabase
            .from("apartments")
            .select("keybox")
            .eq("id", t.apartment_id)
            .maybeSingle();
          if (error) throw error;
          keybox = (apt?.keybox ?? "").trim();
        }

        // Jazyk: rezervace / klient; u úkolu jen s bytem bez hosta bereme `en`.
        const targetLangTask = normalizeTargetLang(guestLang);
        const rawBodyTask = resolveTemplateContent(template.translations, targetLangTask);
        const renderedText = extractTextFromTemplate(rawBodyTask, {
          guest_name: guestName,
          keybox: keybox,
          task_date: fmtDdMmYyyyInZone(eventTime, tenantTz),
          task_time: fmtHhMm24InZone(eventTime, tenantTz),
          arrival_date: "",
          arrival_time: "",
          departure_date: "",
          departure_time: "",
        });
        const emailSubTask = rule.channel === "email"
          ? resolveEmailSubject(template, targetLangTask)
          : null;

        const staffRecipientTask = (rule.staff_profile_id ?? "").trim();
        const recipientForTaskQueue = isInternalPush ? staffRecipientTask : recipientPhone;

        const editablePayload = buildEditablePayload({
          text: renderedText,
          guestName,
          keybox,
          channel: rule.channel,
          emailSubject: emailSubTask,
          meta: {
            rule_id: rule.id,
            trigger_event: rule.trigger_event,
            template_id: rule.template_id,
            task_id: t.id,
            ...(isInternalPush
              ? {
                staff_profile_id: staffRecipientTask,
                ...(t.reservation_id
                  ? { reservation_id: t.reservation_id }
                  : {}),
              }
              : {}),
          },
        });

        await supabase.from("automation_message_queue").insert({
          tenant_id: rule.tenant_id,
          rule_id: rule.id,
          entity_id: t.id,
          entity_type: "task",
          scheduled_for: toIsoUtc(scheduledFor),
          status: "pending",
          channel: rule.channel,
          recipient_contact: recipientForTaskQueue,
          editable_payload: editablePayload,
          attempt_count: 0,
          last_error: null,
        });

        enqueuedCount++;
        createdIds.push(t.id);
      }
    }
  }

  return new Response(JSON.stringify({
    ok: true,
    rules: activeRules.length,
    enqueuedCount,
    createdIds,
  }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});

