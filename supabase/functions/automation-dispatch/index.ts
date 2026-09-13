// =============================================================================
// FalcoNest Automations - Dispatch Worker (Odesílač)
// -----------------------------------------------------------------------------
// Tato Edge Function slouží jako "worker" pro odesílání zpráv z tabulky
// `automation_message_queue`.
//
// FÁZE:
// - Fáze 1: databázové tabulky a RLS hotové (viz migration)
// - Fáze 3: UI pro tvorbu pravidel + edit/cancel fronty hotové
// - Fáze 3.2/3.3: queue + log UI hotové
// - Tohle je FÁZE 4 (Dispatch): picking pending položek a zápis audit logu
// =============================================================================

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { getToken } from "https://deno.land/x/google_jwt_sa@v0.2.5/mod.ts";
import {
  buildAutomationEmailPlainText,
  buildFalcoNestEmailHtml,
} from "./emailTemplates.ts";
// PROČ: Odesílání přes tenantův SMTP (Gmail, Seznam, …).
import * as nodemailer from "npm:nodemailer";

// PROČ: Flutter Web volá Edge Function přímo z prohlížeče – bez CORS hlaviček a bez
// odpovědi na OPTIONS (preflight) selže fetch s „Load failed“ / ClientException.
const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// PROČ: CJS `module.exports` z nodemailer – pod Deno je default na namespace importu.
// deno-lint-ignore no-explicit-any
const nodemailerLib: any = (nodemailer as any).default ?? nodemailer;

/** Pevná adresa při fallbacku na sdílený Resend (bez vlastního SMTP u tenanta). */
const FALLBACK_RESEND_FROM = "FalcoNest <agentura@falconestapp.com>";

// -----------------------------------------------------------------------------
// FCM HTTP v1 – kanál internal_push (připomínka dispečerovi, bez Meta/WhatsApp)
// -----------------------------------------------------------------------------
// PROČ: Stejné secrets jako `daily-task-summary` / `template-reminders` (FIREBASE_PROJECT_ID,
// FIREBASE_SERVICE_ACCOUNT_JSON). Nepoužíváme Firebase Admin SDK v Node – čistý REST jako ostatní Edge.
const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";

async function getFcmAccessTokenForDispatch(): Promise<string> {
  const json = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (!json?.trim()) {
    throw new Error("FIREBASE_SERVICE_ACCOUNT_JSON není nastaven v Supabase secrets");
  }
  const token = await getToken(json, { scope: [FCM_SCOPE] });
  return token.access_token;
}

/**
 * Odešle datovou + notifikační zprávu (pevný titulek/tělo dle zadání produktu).
 * [data] musí mít hodnoty typu string (požadavek FCM).
 */
async function sendFcmInternalPushMessage(args: {
  projectId: string;
  accessToken: string;
  fcmToken: string;
  title: string;
  body: string;
  data: Record<string, string>;
}): Promise<boolean> {
  const url =
    `https://fcm.googleapis.com/v1/projects/${args.projectId}/messages:send`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${args.accessToken}`,
    },
    body: JSON.stringify({
      message: {
        token: args.fcmToken,
        notification: {
          title: args.title,
          body: args.body,
        },
        data: args.data,
        android: { priority: "HIGH" },
        apns: {
          payload: {
            aps: {
              alert: { title: args.title, body: args.body },
              sound: "default",
            },
          },
        },
      },
    }),
  });
  if (!res.ok) {
    const text = await res.text();
    console.error(
      `[dispatch] FCM internal_push failed token=${args.fcmToken.slice(0, 12)}… ${res.status} ${text}`,
    );
    return false;
  }
  return true;
}

function parseSmtpPort(raw: unknown): number {
  if (typeof raw === "number" && Number.isFinite(raw)) return Math.round(raw);
  if (typeof raw === "string") {
    const n = parseInt(raw.trim(), 10);
    if (Number.isFinite(n) && n > 0) return n;
  }
  return 587;
}

// -----------------------------------------------------------------------------
// JWT a Supabase klient (service role)
// -----------------------------------------------------------------------------
// PROČ: Na bráně je `verify_jwt = false` (viz `supabase/config.toml`), aby se předešlo 401
// „Invalid JWT“ u Flutter Web / cron. Autorizaci dělá [authorizeAutomationDispatchRequest]:
// – pg_cron: `Authorization: Bearer` == `SUPABASE_SERVICE_ROLE_KEY` (viz migrace `cron_edge_config`);
// – Flutter: platný user access_token + role admin/manager v `profiles` (explicitní hlavička v
// [AutomationQueueRepository.invokeAutomationDispatch]).
// DB operace dispečinku zůstávají přes SERVICE_ROLE_KEY: worker musí číst frontu a zapisovat
// log bez omezení RLS napříč tenanty.
// -----------------------------------------------------------------------------

type AutomationChannel = "email" | "sms" | "whatsapp" | "internal_push";

type QueueStatus = "pending" | "processing" | "sent" | "failed" | "cancelled";

type AutomationMessageQueueRow = {
  id: string;
  tenant_id: string;
  rule_id: string | null;
  entity_id: string;
  entity_type: string;
  scheduled_for: string; // timestamptz (string v JSON)
  status: QueueStatus;
  channel: AutomationChannel;
  recipient_contact: string | null;
  editable_payload: unknown; // jsonb
  attempt_count: number;
  last_error: string | null;
};

type TenantMessageLogInsert = {
  tenant_id: string;
  queue_id: string;
  sent_at: string;
  channel: AutomationChannel;
  /** PROČ: Twilio SID, Resend `id` z API (`re_…`, ukládá se pro `resend-webhook` / `data.email_id`), SMTP Message-ID. */
  external_api_id?: string | null;
  status: string;
  unit_price: number | null;
  recipient_masked: string | null;
  content_snapshot: string;
  error_details?: string | null;
  /** PROČ: např. `{ num_segments: N }` z Twilio – viz migrace tenant_message_log.metadata. */
  metadata?: Record<string, unknown> | null;
};

/** Výsledek odeslání u providera: externí ID + počet zúčtovatelných jednotek (SMS segmenty). */
type DispatchSendResult = {
  externalApiId: string;
  /** SMS: Twilio `num_segments`; WhatsApp a e-mail: vždy 1. */
  billableUnits: number;
  /** Pouze internal_push – text uložený do tenant_message_log.content_snapshot. */
  contentSnapshot?: string;
};

type InternalPushContext = {
  profileId: string;
  apartmentName: string;
  guestName: string;
  reservationId: string;
};

/**
 * Z fronty a volitelně z DB (rezervace) sestaví kontext pro text push zprávy.
 * PROČ: [recipient_contact] = UUID profilu dispečera (admin/manager); metadata v editable_payload.
 */
async function resolveInternalPushContext(
  supabase: ReturnType<typeof createClient>,
  msg: AutomationMessageQueueRow,
): Promise<InternalPushContext> {
  const p = (msg.editable_payload && typeof msg.editable_payload === "object")
    ? msg.editable_payload as Record<string, unknown>
    : {};

  const fromPayload = (k: string): string => {
    const v = p[k];
    return typeof v === "string" ? v.trim() : "";
  };

  const profileId = (msg.recipient_contact?.trim() ||
    fromPayload("staff_profile_id") ||
    fromPayload("profile_id")).trim();
  if (!profileId) {
    throw new Error(
      "internal_push: chybí recipient_contact nebo staff_profile_id / profile_id v editable_payload",
    );
  }

  let reservationId = fromPayload("reservation_id");
  if (!reservationId && msg.entity_type === "reservation") {
    reservationId = msg.entity_id.trim();
  }
  // PROČ: Úkol v queue má entity_id = task; pro deep link na rezervaci načteme vazbu z tasks.
  if (!reservationId && msg.entity_type === "task") {
    const { data: taskRow, error: taskErr } = await supabase
      .from("tasks")
      .select("reservation_id")
      .eq("id", msg.entity_id.trim())
      .eq("tenant_id", msg.tenant_id)
      .maybeSingle();
    if (taskErr) {
      console.warn("[dispatch] internal_push task lookup:", taskErr.message);
    }
    const rid = (taskRow as { reservation_id?: string | null } | null)?.reservation_id;
    reservationId = typeof rid === "string" ? rid.trim() : "";
  }
  if (!reservationId) {
    throw new Error(
      "internal_push: chybí reservation_id (nebo reservation přes entity_type=reservation/task)",
    );
  }

  let apartmentName = fromPayload("apartment_name");
  let guestName = fromPayload("guest_name");

  if (!apartmentName || !guestName) {
    const { data: resv, error } = await supabase
      .from("reservations")
      .select("guest_name, apartments(name)")
      .eq("id", reservationId)
      .eq("tenant_id", msg.tenant_id)
      .maybeSingle();
    if (error) {
      console.warn("[dispatch] internal_push reservation lookup:", error.message);
    }
    if (resv) {
      const row = resv as Record<string, unknown>;
      if (!guestName && row["guest_name"]) {
        guestName = String(row["guest_name"]).trim();
      }
      const apt = row["apartments"];
      if (!apartmentName && apt && typeof apt === "object") {
        const n = (apt as Record<string, unknown>)["name"];
        if (typeof n === "string") apartmentName = n.trim();
      }
    }
  }

  return {
    profileId,
    apartmentName: apartmentName || "—",
    guestName: guestName || "—",
    reservationId,
  };
}

function internalPushProfileIdFromQueue(msg: AutomationMessageQueueRow): string {
  const p = (msg.editable_payload && typeof msg.editable_payload === "object")
    ? msg.editable_payload as Record<string, unknown>
    : {};
  const fromPayload = (k: string): string => {
    const v = p[k];
    return typeof v === "string" ? v.trim() : "";
  };
  return (msg.recipient_contact?.trim() ||
    fromPayload("staff_profile_id") ||
    fromPayload("profile_id")).trim();
}

/**
 * Push při přiřazení úkolu – titulek/tělo z DB triggeru (`editable_payload`),
 * deep link na worker detail úkolu. Nezávislé na rezervaci.
 */
async function dispatchNewTaskAssignedInternalPush(args: {
  supabase: ReturnType<typeof createClient>;
  msg: AutomationMessageQueueRow;
}): Promise<DispatchSendResult> {
  const p = (args.msg.editable_payload && typeof args.msg.editable_payload === "object")
    ? args.msg.editable_payload as Record<string, unknown>
    : {};
  const title = typeof p["push_title"] === "string" ? p["push_title"].trim() : "";
  const body = typeof p["push_body"] === "string" ? p["push_body"].trim() : "";
  const taskId = (typeof p["task_id"] === "string" && p["task_id"].trim().length > 0)
    ? p["task_id"].trim()
    : args.msg.entity_id.trim();
  const profileId = internalPushProfileIdFromQueue(args.msg);
  if (!profileId) {
    throw new Error(
      "internal_push new_task_assigned: chybí recipient_contact nebo staff_profile_id / profile_id v editable_payload",
    );
  }
  if (!title || !body) {
    throw new Error("internal_push new_task_assigned: chybí push_title nebo push_body v editable_payload");
  }

  const firebaseProjectId = Deno.env.get("FIREBASE_PROJECT_ID")?.trim();
  if (!firebaseProjectId) {
    throw new Error("Chybí FIREBASE_PROJECT_ID v Supabase secrets");
  }
  const accessToken = await getFcmAccessTokenForDispatch();

  const { data: devices, error: devErr } = await args.supabase
    .from("user_devices")
    .select("fcm_token")
    .eq("profile_id", profileId)
    .eq("tenant_id", args.msg.tenant_id);

  if (devErr) throw new Error(`user_devices: ${devErr.message}`);

  const tokens = (devices ?? [])
    .map((d) => String((d as Record<string, unknown>)["fcm_token"] ?? "").trim())
    .filter((t) => t.length > 0);

  if (tokens.length === 0) {
    throw new Error(
      "internal_push: žádný FCM token v user_devices pro daný profil (aplikace musí zaregistrovat zařízení)",
    );
  }

  const data: Record<string, string> = {
    route: `/worker/task/${taskId}`,
    task_id: taskId,
  };
  const resId = typeof p["reservation_id"] === "string" ? p["reservation_id"].trim() : "";
  if (resId.length > 0) {
    data.reservation_id = resId;
  }

  let okCount = 0;
  for (const token of tokens) {
    const ok = await sendFcmInternalPushMessage({
      projectId: firebaseProjectId,
      accessToken,
      fcmToken: token,
      title,
      body,
      data,
    });
    if (ok) okCount++;
  }

  if (okCount === 0) {
    throw new Error("internal_push: FCM odmítl všechny tokeny (Firebase / expirované tokeny)");
  }

  return {
    externalApiId: `fcm_internal:${args.msg.id}:${okCount}/${tokens.length}`,
    billableUnits: okCount,
    contentSnapshot: `${title}\n${body}`,
  };
}

/** Kanály majitele (Klientský portál) — titulek/tělo z DB triggeru, deep link /owner. */
const OWNER_LIFECYCLE_PUSH_KINDS = new Set([
  "owner_task_started",
  "owner_task_completed",
  "owner_cash_collected",
]);

/**
 * Push pro property_owner: stejný transport jako new_task_assigned (FCM data z payloadu),
 * ale route směřuje do portálu majitele (/owner).
 */
async function dispatchOwnerLifecycleInternalPush(args: {
  supabase: ReturnType<typeof createClient>;
  msg: AutomationMessageQueueRow;
}): Promise<DispatchSendResult> {
  const p = (args.msg.editable_payload && typeof args.msg.editable_payload === "object")
    ? args.msg.editable_payload as Record<string, unknown>
    : {};
  const title = typeof p["push_title"] === "string" ? p["push_title"].trim() : "";
  const body = typeof p["push_body"] === "string" ? p["push_body"].trim() : "";
  const profileId = internalPushProfileIdFromQueue(args.msg);
  if (!profileId) {
    throw new Error(
      "internal_push owner_lifecycle: chybí recipient_contact nebo staff_profile_id / profile_id v editable_payload",
    );
  }
  if (!title || !body) {
    throw new Error("internal_push owner_lifecycle: chybí push_title nebo push_body v editable_payload");
  }

  const firebaseProjectId = Deno.env.get("FIREBASE_PROJECT_ID")?.trim();
  if (!firebaseProjectId) {
    throw new Error("Chybí FIREBASE_PROJECT_ID v Supabase secrets");
  }
  const accessToken = await getFcmAccessTokenForDispatch();

  const { data: devices, error: devErr } = await args.supabase
    .from("user_devices")
    .select("fcm_token")
    .eq("profile_id", profileId)
    .eq("tenant_id", args.msg.tenant_id);

  if (devErr) throw new Error(`user_devices: ${devErr.message}`);

  const tokens = (devices ?? [])
    .map((d) => String((d as Record<string, unknown>)["fcm_token"] ?? "").trim())
    .filter((t) => t.length > 0);

  if (tokens.length === 0) {
    throw new Error(
      "internal_push: žádný FCM token v user_devices pro daný profil (aplikace musí zaregistrovat zařízení)",
    );
  }

  const kindRaw = p["internal_push_kind"];
  const kind = typeof kindRaw === "string" ? kindRaw.trim() : "";
  const taskId = typeof p["task_id"] === "string" ? p["task_id"].trim() : "";
  const apartmentId = typeof p["apartment_id"] === "string" ? p["apartment_id"].trim() : "";
  const reservationId = typeof p["reservation_id"] === "string" ? p["reservation_id"].trim() : "";
  const cashTxId = typeof p["cash_transaction_id"] === "string" ? p["cash_transaction_id"].trim() : "";

  const data: Record<string, string> = {
    route: "/owner",
    owner_push_kind: kind,
  };
  if (taskId.length > 0) data.task_id = taskId;
  if (apartmentId.length > 0) data.apartment_id = apartmentId;
  if (reservationId.length > 0) data.reservation_id = reservationId;
  if (cashTxId.length > 0) data.cash_transaction_id = cashTxId;

  let okCount = 0;
  for (const token of tokens) {
    const ok = await sendFcmInternalPushMessage({
      projectId: firebaseProjectId,
      accessToken,
      fcmToken: token,
      title,
      body,
      data,
    });
    if (ok) okCount++;
  }

  if (okCount === 0) {
    throw new Error("internal_push: FCM odmítl všechny tokeny (Firebase / expirované tokeny)");
  }

  return {
    externalApiId: `fcm_internal:${args.msg.id}:${okCount}/${tokens.length}`,
    billableUnits: okCount,
    contentSnapshot: `${title}\n${body}`,
  };
}

async function dispatchInternalPushForQueueItem(args: {
  supabase: ReturnType<typeof createClient>;
  msg: AutomationMessageQueueRow;
}): Promise<DispatchSendResult> {
  const p = (args.msg.editable_payload && typeof args.msg.editable_payload === "object")
    ? args.msg.editable_payload as Record<string, unknown>
    : {};
  const kind = typeof p["internal_push_kind"] === "string" ? p["internal_push_kind"].trim() : "";
  if (kind === "new_task_assigned") {
    return await dispatchNewTaskAssignedInternalPush(args);
  }
  if (OWNER_LIFECYCLE_PUSH_KINDS.has(kind)) {
    return await dispatchOwnerLifecycleInternalPush(args);
  }

  const firebaseProjectId = Deno.env.get("FIREBASE_PROJECT_ID")?.trim();
  if (!firebaseProjectId) {
    throw new Error("Chybí FIREBASE_PROJECT_ID v Supabase secrets");
  }

  const ctx = await resolveInternalPushContext(args.supabase, args.msg);
  const accessToken = await getFcmAccessTokenForDispatch();

  const { data: devices, error: devErr } = await args.supabase
    .from("user_devices")
    .select("fcm_token")
    .eq("profile_id", ctx.profileId)
    .eq("tenant_id", args.msg.tenant_id);

  if (devErr) throw new Error(`user_devices: ${devErr.message}`);

  const tokens = (devices ?? [])
    .map((d) => String((d as Record<string, unknown>)["fcm_token"] ?? "").trim())
    .filter((t) => t.length > 0);

  if (tokens.length === 0) {
    throw new Error(
      "internal_push: žádný FCM token v user_devices pro daný profil (aplikace musí zaregistrovat zařízení)",
    );
  }

  const title = "Čas odeslat instrukce";
  const body = `Apartmán: ${ctx.apartmentName}, Host: ${ctx.guestName}`;
  const data: Record<string, string> = {
    route: "/admin/reservations",
    reservation_id: ctx.reservationId,
  };

  let okCount = 0;
  for (const token of tokens) {
    const ok = await sendFcmInternalPushMessage({
      projectId: firebaseProjectId,
      accessToken,
      fcmToken: token,
      title,
      body,
      data,
    });
    if (ok) okCount++;
  }

  if (okCount === 0) {
    throw new Error("internal_push: FCM odmítl všechny tokeny (Firebase / expirované tokeny)");
  }

  return {
    externalApiId: `fcm_internal:${args.msg.id}:${okCount}/${tokens.length}`,
    billableUnits: okCount,
    contentSnapshot: `${title}\n${body}`,
  };
}

function requireEnv(name: string): string {
  const v = Deno.env.get(name);
  if (!v || v.trim() === "") {
    throw new Error(`Chybí environment variable: ${name}`);
  }
  return v;
}

function nowUtcIso(): string {
  return new Date().toISOString();
}

function billingMonthUtcIsoDate(isoUtc: string): string {
  // Format YYYY-MM pro sloupec tenant_usage_monthly.billing_month.
  // Používáme UTC, aby výpočet nebyl závislý na timezone serveru.
  return isoUtc.slice(0, 7);
}

function formatRecipientMask(contact: string | null, channel: AutomationChannel): string | null {
  if (!contact) return null;
  const trimmed = contact.trim();
  if (trimmed.length === 0) return null;

  // PROČ: Nechceme ukládat plnou hodnotu (PII). V UI/logu ukazujeme maskovanou verzi.
  // Heuristiky:
  // - pro telefony: necháme poslední 3 číslice
  // - pro email: necháme první 1-2 znaky + doménu
  if (channel === "sms" || channel === "whatsapp") {
    const digits = trimmed.replaceAll(/[^\d]/g, "");
    const last3 = digits.slice(-3);
    return `${trimmed.startsWith("+") ? "+" : ""}${"***"}${last3}`;
  }

  if (channel === "email") {
    const [user, domain] = trimmed.split("@");
    if (!user || !domain) return "***";
    const safeUser = user.length <= 2 ? user[0] ?? "*" : `${user.slice(0, 2)}***`;
    return `${safeUser}@${domain}`;
  }

  // internal_push: recipient_contact = profiles.id (UUID) – v logu neukládáme celé UUID.
  if (channel === "internal_push") {
    if (trimmed.length >= 4) return `prof…${trimmed.slice(-4)}`;
    return "internal_push";
  }

  return "***";
}

/// PROČ: Twilio může volat náš Status Callback po změně stavu zprávy (edge `twilio-webhook`).
/// Nastav env `TWILIO_STATUS_CALLBACK_URL` na plnou URL funkce (např. …/functions/v1/twilio-webhook).
function appendTwilioStatusCallback(form: URLSearchParams): void {
  const cb = Deno.env.get("TWILIO_STATUS_CALLBACK_URL")?.trim();
  if (cb) {
    form.append("StatusCallback", cb);
  }
}

function sanitizePhone(input: string): string {
  // Twilio API chce telefon ve formátu s + a čísly.
  // Tady odstraníme vše kromě číslic a plus na začátku.
  const trimmed = input.trim();
  if (trimmed.startsWith("+")) {
    return `+${trimmed.slice(1).replaceAll(/[^\d]/g, "")}`;
  }
  // Bez plusu:
  const digits = trimmed.replaceAll(/[^\d]/g, "");
  return digits.length > 0 ? `+${digits}` : digits;
}

function extractTextFromEditablePayload(payload: unknown): string {
  // `editable_payload` je jsonb. UI teď ukládá text pod klíčem `text`,
  // ale v budoucnu může obsahovat i aliasy `body` nebo `message`.
  if (!payload) return "";
  if (typeof payload === "string") {
    try {
      const parsed = JSON.parse(payload);
      return extractTextFromEditablePayload(parsed);
    } catch {
      return "";
    }
  }

  if (typeof payload === "object") {
    const p = payload as Record<string, unknown>;
    const v = p["text"] ?? p["body"] ?? p["message"];
    if (typeof v === "string") return v;
  }

  return "";
}

/// Předmět e-mailu z fronty – enqueue ho doplňuje z šablony (`email_subject` / překlady).
function extractEmailSubjectFromEditablePayload(payload: unknown): string | null {
  if (!payload || typeof payload !== "object") return null;
  const p = payload as Record<string, unknown>;
  const s = p["email_subject"];
  if (typeof s === "string" && s.trim()) return s.trim();
  return null;
}

/** UUID v4/v5 z editable_payload – pro deep link do webové aplikace. */
const UUID_LIKE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function extractTaskIdFromEditablePayload(payload: unknown): string | null {
  if (!payload || typeof payload !== "object") return null;
  const p = payload as Record<string, unknown>;
  const raw = p["task_id"];
  if (typeof raw !== "string") return null;
  const id = raw.trim();
  return UUID_LIKE.test(id) ? id : null;
}

/**
 * Veřejná URL webové aplikace (hash routing pro Flutter web build).
 * PROČ: Nastavitelné přes secret – staging vs. produkce.
 */
function falconestWebAppBaseUrl(): string {
  return (Deno.env.get("FALCONEST_WEB_APP_BASE_URL") ?? "https://admin.falconestapp.com").trim()
    .replace(/\/$/, "");
}

function buildWorkerTaskDeepLink(taskId: string): string {
  const base = falconestWebAppBaseUrl();
  return `${base}/#/worker/task/${encodeURIComponent(taskId)}`;
}

/**
 * Formátuje tělo transakčního e-mailu (interní notifikace: new_task_assigned, daily_summary, …).
 * HTML: šablona FalcoNest ([buildFalcoNestEmailHtml]); text: vždy čistý fallback ([buildAutomationEmailPlainText]).
 * Metadata z fronty: [editable_payload.task_id] → deep link shodný s FCM [data.task_id].
 */
function augmentEmailWithTaskDeepLink(
  plainText: string,
  payload: unknown,
): { text: string; html: string } {
  const title =
    extractEmailSubjectFromEditablePayload(payload)?.trim() ?? "FalcoNest";
  const taskId = extractTaskIdFromEditablePayload(payload);
  const ctaUrl = taskId ? buildWorkerTaskDeepLink(taskId) : null;
  const text = buildAutomationEmailPlainText({
    body: plainText,
    ctaUrl,
    ctaLabel: "Zobrazit úkol v aplikaci",
  });
  const html = buildFalcoNestEmailHtml({
    title,
    body: plainText,
    ctaUrl,
    ctaLabel: "Otevřít v aplikaci",
  });
  return { text, html };
}

/// Twilio vrací `num_segments` jako řetězec v JSON odpovědi Messages API.
function parseTwilioNumSegments(json: Record<string, unknown>): number {
  const raw = json["num_segments"];
  if (typeof raw === "number" && Number.isFinite(raw) && raw > 0) {
    return Math.round(raw);
  }
  if (typeof raw === "string") {
    const n = parseInt(raw.trim(), 10);
    if (Number.isFinite(n) && n > 0) return n;
  }
  return 1;
}

async function sendViaTwilioSms(args: {
  supabase: ReturnType<typeof createClient>;
  tenantId: string;
  recipient: string;
  text: string;
}): Promise<DispatchSendResult> {
  const accountSid = requireEnv("TWILIO_ACCOUNT_SID");
  const authToken = requireEnv("TWILIO_AUTH_TOKEN");

  // PROČ: Vlastní číslo agentury z self-service (integration_settings.twilio_phone_number);
  // jinak sdílený odesílatel z env (legacy / fallback).
  const settings = await fetchTenantIntegrationSettings(args.supabase, args.tenantId);
  const tenantFrom = settings?.["twilio_phone_number"];
  // PROČ: Globální TWILIO_PHONE_NUMBER bereme z env jen při absenci vlastního čísla agentury.
  const fromRaw =
    typeof tenantFrom === "string" && tenantFrom.trim().length > 0
      ? tenantFrom.trim()
      : requireEnv("TWILIO_PHONE_NUMBER");

  // Twilio SMS endpoint:
  // POST https://api.twilio.com/2010-04-01/Accounts/{AccountSid}/Messages.json
  //
  // PROČ BASIC auth:
  // Twilio REST API používá HTTP Basic (Account SID + Auth Token).
  // Basic auth generujeme jako base64(SID:TOKEN).
  const to = sanitizePhone(args.recipient);
  const from = sanitizePhone(fromRaw);

  // Připravené tělo requestu (form-urlencoded).
  // Twilio očekává parametry: To, From, Body.
  const form = new URLSearchParams({
    To: to,
    From: from,
    Body: args.text,
  });
  appendTwilioStatusCallback(form);

  const url = `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`;
  const basicAuth = btoa(`${accountSid}:${authToken}`);

  // Odeslání:
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      "Authorization": `Basic ${basicAuth}`,
    },
    body: form.toString(),
  });

  if (!res.ok) {
    // Twilio obvykle vrací JSON s message/code. Chceme vypsat smysluplnou
    // chybovou hlášku do `last_error` (a tím i do UI).
    const text = await res.text();
    let errorDetails = text;
    try {
      const json = JSON.parse(text) as Record<string, unknown>;
      errorDetails = (json["message"] as string) ??
        (json["error"] as string) ??
        (json["errors"] && Array.isArray(json["errors"]) && json["errors"].length > 0
          ? (json["errors"][0] as Record<string, unknown>)["message"] as string
          : undefined) ??
        text;
    } catch {
      // fallback: ponecháme původní text
    }
    throw new Error(`Twilio SMS failed: ${res.status} ${errorDetails}`);
  }

  // PROČ: `sid` + `num_segments` z Messages resource (účtování po segmentech).
  const bodyText = await res.text();
  try {
    const json = JSON.parse(bodyText) as Record<string, unknown>;
    const sid = json["sid"];
    if (typeof sid === "string" && sid.trim().length > 0) {
      const billableUnits = parseTwilioNumSegments(json);
      return { externalApiId: sid.trim(), billableUnits };
    }
  } catch {
    // fallback níže
  }
  throw new Error("Twilio SMS: v odpovědi chybí platné pole sid");
}

/** Prefix chybové zprávy – při tomto stavu nesmíme dělat SMS fallback (jiný typ doručení). */
const WA_AUTOMATION_REQUIRES_CUSTOM_TWILIO = "WA_AUTOMATION_REQUIRES_CUSTOM_TWILIO";

async function sendViaTwilioWhatsApp(args: {
  supabase: ReturnType<typeof createClient>;
  tenantId: string;
  recipient: string;
  text: string;
}): Promise<DispatchSendResult> {
  const settings = await fetchTenantIntegrationSettings(args.supabase, args.tenantId);
  const sidRaw = settings?.["twilio_account_sid"];
  const tokenRaw = settings?.["twilio_auth_token"];
  const hasCustomTwilio =
    typeof sidRaw === "string" &&
    sidRaw.trim().length > 0 &&
    typeof tokenRaw === "string" &&
    tokenRaw.trim().length > 0;

  // PROČ: Automatizace WhatsApp přes Twilio API musí používat účet agentury (Meta schválení u vlastního čísla);
  // bez uložených přihlašovacích údajů pravidlo nesmí „němě“ spadnout na sdílený účet.
  if (!hasCustomTwilio) {
    throw new Error(
      `${WA_AUTOMATION_REQUIRES_CUSTOM_TWILIO}: Automatický WhatsApp vyžaduje vlastní Twilio (twilio_account_sid + twilio_auth_token) v integracích.`,
    );
  }

  const accountSid = sidRaw.trim();
  const authToken = tokenRaw.trim();

  // Twilio WhatsApp obvykle vyžaduje From/To ve formátu `whatsapp:+420...`.
  const fromPool = settings?.["twilio_phone_number"];
  const fromPhoneRaw =
    typeof fromPool === "string" && fromPool.trim().length > 0
      ? fromPool.trim()
      : requireEnv("TWILIO_PHONE_NUMBER");

  const to = sanitizePhone(args.recipient);
  const from = sanitizePhone(fromPhoneRaw);

  // PROČ prefix `whatsapp:`:
  // Twilio rozlišuje typ kanálu podle prefixu u To/From.
  const form = new URLSearchParams({
    To: `whatsapp:${to}`,
    From: `whatsapp:${from}`,
    Body: args.text,
  });
  appendTwilioStatusCallback(form);

  const url = `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`;
  const basicAuth = btoa(`${accountSid}:${authToken}`);

  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      "Authorization": `Basic ${basicAuth}`,
    },
    body: form.toString(),
  });

  if (!res.ok) {
    const text = await res.text();
    let errorDetails = text;
    try {
      const json = JSON.parse(text) as Record<string, unknown>;
      errorDetails = (json["message"] as string) ??
        (json["error"] as string) ??
        (json["errors"] && Array.isArray(json["errors"]) && json["errors"].length > 0
          ? (json["errors"][0] as Record<string, unknown>)["message"] as string
          : undefined) ??
        text;
    } catch {
      // fallback: ponecháme původní text
    }
    throw new Error(`Twilio WhatsApp failed: ${res.status} ${errorDetails}`);
  }

  const bodyText = await res.text();
  try {
    const json = JSON.parse(bodyText) as Record<string, unknown>;
    const sid = json["sid"];
    if (typeof sid === "string" && sid.trim().length > 0) {
      // PROČ: Fakturace segmentů jen u klasické SMS; WhatsApp účtujeme jako 1 jednotku (požadavek produktu).
      return { externalApiId: sid.trim(), billableUnits: 1 };
    }
  } catch {
    // fallback níže
  }
  throw new Error("Twilio WhatsApp: v odpovědi chybí platné pole sid");
}

/**
 * PROČ: Načte `tenants.integration_settings` přes service-role klienta (bez RLS) pro SMTP / fallback.
 */
async function fetchTenantIntegrationSettings(
  supabase: ReturnType<typeof createClient>,
  tenantId: string,
): Promise<Record<string, unknown> | null> {
  const { data, error } = await supabase
    .from("tenants")
    .select("integration_settings")
    .eq("id", tenantId)
    .maybeSingle();

  if (error) {
    console.warn("[dispatch] tenants.integration_settings:", error.message);
    return null;
  }

  const raw = (data as { integration_settings?: unknown } | null)?.integration_settings;
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    return null;
  }
  return raw as Record<string, unknown>;
}

/// PROČ: Odeslání přes tenantův SMTP (nodemailer) – špatné heslo / port chytíme a propagujeme do výjimky.
async function sendEmailViaTenantSmtp(args: {
  settings: Record<string, unknown>;
  recipient: string;
  text: string;
  subjectLine: string;
  html?: string | null;
}): Promise<DispatchSendResult> {
  const host = String(args.settings["smtp_host"] ?? "").trim();
  const user = String(args.settings["smtp_username"] ?? "").trim();
  const pass = String(args.settings["smtp_password"] ?? "");
  const senderName = String(args.settings["smtp_sender_name"] ?? "").trim();
  const port = parseSmtpPort(args.settings["smtp_port"]);
  const secure = port === 465;

  const transport = nodemailerLib.createTransport({
    host,
    port,
    secure,
    auth: {
      user,
      pass,
    },
  });

  const fromHeader =
    senderName.length > 0 ? `${senderName} <${user}>` : user;

  let info: { messageId?: string };
  try {
    const mailOpts: Record<string, unknown> = {
      from: fromHeader,
      to: args.recipient.trim(),
      subject: args.subjectLine,
      text: args.text,
    };
    const html = typeof args.html === "string" && args.html.trim().length > 0
      ? args.html.trim()
      : "";
    if (html.length > 0) {
      mailOpts.html = html;
    }
    info = await transport.sendMail(mailOpts);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    throw new Error(`SMTP odeslání selhalo: ${msg}`);
  }

  const mid = info.messageId;
  const externalId =
    typeof mid === "string" && mid.trim().length > 0
      ? mid.trim()
      : `smtp-${Date.now()}`;
  return { externalApiId: externalId, billableUnits: 1 };
}

/// PROČ: Sdílený Resend účet FalcoNest – pevný From (bez env), aby všechny fallback e-maily
/// měly jednotnou identitu produktu.
///
/// PROČ: Vracené pole `id` z odpovědi API je **stejné** jako `data.email_id` v Resend webhooku
/// (Svix) – uložíme ho do `tenant_message_log.external_api_id` pro sledování doručení.
async function sendEmailViaResendHttpFallback(args: {
  recipient: string;
  text: string;
  subjectLine: string;
  html?: string | null;
}): Promise<DispatchSendResult> {
  const apiKey = requireEnv("RESEND_API_KEY");
  const from = FALLBACK_RESEND_FROM;
  const toEmail = args.recipient.trim();

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from,
      to: [toEmail],
      subject: args.subjectLine,
      text: args.text,
      ...(typeof args.html === "string" && args.html.trim().length > 0
        ? { html: args.html.trim() }
        : {}),
    }),
  });

  const raw = await res.text();
  if (!res.ok) {
    let detail = raw;
    try {
      const errJson = JSON.parse(raw) as Record<string, unknown>;
      detail = (errJson["message"] as string) ?? raw;
    } catch {
      // ponecháme raw tělo odpovědi
    }
    throw new Error(`Resend failed: ${res.status} ${detail}`);
  }

  try {
    const json = JSON.parse(raw) as Record<string, unknown>;
    const id = json["id"];
    if (typeof id === "string" && id.trim().length > 0) {
      return { externalApiId: id.trim(), billableUnits: 1 };
    }
  } catch {
    // fallback níže
  }
  throw new Error("Resend: v odpovědi chybí platné pole id");
}

/// PROČ: Transakční e-mail z fronty – při vyplněném `smtp_host` + `smtp_username` (viz Flutter UI)
/// použijeme nodemailer; jinak HTTP/fetch na Resend s pevným From.
async function sendViaSmtpOrFallback(args: {
  supabase: ReturnType<typeof createClient>;
  tenantId: string;
  recipient: string;
  text: string;
  /// PROČ: Šablona ukládá předmět do JSONB – enqueue ho propíše do `editable_payload.email_subject`.
  subject?: string | null;
  /** HTML tělo (deep link na úkol) – volitelné vedle plain textu. */
  html?: string | null;
}): Promise<DispatchSendResult> {
  const settings = await fetchTenantIntegrationSettings(args.supabase, args.tenantId);
  const host = settings?.["smtp_host"];
  const user = settings?.["smtp_username"];

  const hasTenantSmtp =
    typeof host === "string" &&
    host.trim().length > 0 &&
    typeof user === "string" &&
    user.trim().length > 0;

  const toEmail = args.recipient.trim();
  const subjectTrim = args.subject?.trim() ?? "";
  const subjectLine = subjectTrim.length > 0
    ? subjectTrim
    : "Nová zpráva / New message";

  if (hasTenantSmtp && settings) {
    return await sendEmailViaTenantSmtp({
      settings,
      recipient: toEmail,
      text: args.text,
      subjectLine,
      html: args.html,
    });
  }

  return await sendEmailViaResendHttpFallback({
    recipient: toEmail,
    text: args.text,
    subjectLine,
    html: args.html,
  });
}

/**
 * PROČ: Do provozních logů nepatří celý text výjimky od Twilia (může obsahovat PII nebo obsah zprávy).
 * Vracíme jen krátký kód (např. HTTP status) nebo oříznutý text s maskou telefonních vzorů.
 */
function briefProviderErrorForLog(message: string): string {
  const twilioHttp = message.match(/Twilio\s+WhatsApp\s+failed:\s*(\d{3})\b/i) ??
    message.match(/\b(\d{3})\b/);
  if (twilioHttp) {
    return `twilio_http_${twilioHttp[1]}`;
  }
  let s = message.replace(/\+?\d[\d\s\-()]{8,}/g, "[tel]");
  if (s.length > 96) s = `${s.slice(0, 95)}…`;
  return s;
}

/**
 * Odeslání podle kanálu – jednotný vstup pro dispatch smyčku.
 *
 * PROČ: **Sjednocený error handling** – všechny větve (SMS, WhatsApp vč. fallbacku na SMS, e-mail)
 * vyhazují výjimku při chybě providera. Volající větev A) v dispatchu je jediným místem, které
 * volá `recordOutboundFailureLogAndFailQueue` – fronta se tak nikdy nezasekne ve `pending` kvůli
 * jednomu kanálu.
 *
 * Vrací externí ID a počet zúčtovatelných jednotek (SMS segmenty z Twilio).
 */
async function sendWithSmartFallback(args: {
  supabase: ReturnType<typeof createClient>;
  tenantId: string;
  /** PROČ: Pro bezpečný log při WA→SMS fallbacku (bez citlivého textu chyby). */
  queueId: string;
  channel: AutomationChannel;
  recipientContact: string | null;
  text: string;
  emailSubject?: string | null;
  /** HTML tělo jen pro kanál e-mail (deep link úkolu). */
  emailHtml?: string | null;
}): Promise<DispatchSendResult> {
  if (args.channel === "internal_push") {
    throw new Error(
      "Interní chyba: internal_push se odesílá přes FCM (dispatchInternalPushForQueueItem), ne Twilio/e-mail.",
    );
  }

  const recipient = args.recipientContact?.trim() ?? "";
  if (recipient.length === 0) {
    throw new Error("Chybí recipient_contact pro odeslání.");
  }

  // WhatsApp: nejprve Twilio WhatsApp; při chybě (24h okno, sandbox, apod.) fallback na SMS.
  // PROČ: Pokud selžou i obě, složíme jednu výjimku s oběma hláškami (audit v `error_details`).
  if (args.channel === "whatsapp") {
    try {
      return await sendViaTwilioWhatsApp({
        supabase: args.supabase,
        tenantId: args.tenantId,
        recipient,
        text: args.text,
      });
    } catch (waErr) {
      const waMsg = waErr instanceof Error ? waErr.message : String(waErr);
      // PROČ: Chybí vlastní Twilio – neposíláme SMS místo WhatsApp (jiný záměr komunikace).
      if (waMsg.includes(WA_AUTOMATION_REQUIRES_CUSTOM_TWILIO)) {
        throw new Error(waMsg);
      }
      console.warn(
        "[dispatch] WhatsApp→SMS fallback",
        JSON.stringify({
          queue_id: args.queueId,
          tenant_id: args.tenantId,
          wa_err: briefProviderErrorForLog(waMsg),
        }),
      );
      try {
        return await sendViaTwilioSms({
          supabase: args.supabase,
          tenantId: args.tenantId,
          recipient,
          text: args.text,
        });
      } catch (smsErr) {
        const smsMsg = smsErr instanceof Error ? smsErr.message : String(smsErr);
        throw new Error(`WhatsApp: ${waMsg} | SMS fallback: ${smsMsg}`);
      }
    }
  }

  if (args.channel === "sms") {
    return await sendViaTwilioSms({
      supabase: args.supabase,
      tenantId: args.tenantId,
      recipient,
      text: args.text,
    });
  }

  if (args.channel === "email") {
    return await sendViaSmtpOrFallback({
      supabase: args.supabase,
      tenantId: args.tenantId,
      recipient,
      text: args.text,
      subject: args.emailSubject,
      html: args.emailHtml ?? null,
    });
  }

  throw new Error(`Neznámý kanál automatizace: ${String(args.channel)}`);
}

async function upsertUsageMonthly(args: {
  supabase: ReturnType<typeof createClient>;
  tenantId: string;
  channel: AutomationChannel;
  billingMonth: string;
  /** Počet zúčtovatelných jednotek: u SMS = součet Twilio segmentů, jinde typicky 1. */
  increment: number;
}): Promise<void> {
  // PROČ: Upsert s inkrementací v jednom kroku není v supabase-js tak přímočarý.
  // Uděláme 2 kroky:
  // 1) zjistíme existující sent_count
  // 2) aktualizujeme na sent_count + increment (SMS segmenty / jednotky odeslání)
  const existingRes = await args.supabase
    .from("tenant_usage_monthly")
    .select("sent_count")
    .eq("tenant_id", args.tenantId)
    .eq("billing_month", args.billingMonth)
    .eq("channel", args.channel)
    .maybeSingle();

  if (existingRes.error) {
    throw new Error(`Chyba při čtení tenant_usage_monthly: ${existingRes.error.message}`);
  }

  const existing = existingRes.data as { sent_count: number } | null;
  const current = existing?.sent_count ?? 0;
  const next = current + args.increment;

  if (!existing) {
    await args.supabase.from("tenant_usage_monthly").insert({
      tenant_id: args.tenantId,
      billing_month: args.billingMonth,
      channel: args.channel,
      sent_count: next,
    });
    return;
  }

  await args.supabase
    .from("tenant_usage_monthly")
    .update({ sent_count: next })
    .eq("tenant_id", args.tenantId)
    .eq("billing_month", args.billingMonth)
    .eq("channel", args.channel);
}

/** Ořízne text pro uložení do DB (ochrana před extrémně dlouhými chybami z Twilio). */
function truncateUtf8(s: string, maxLen: number): string {
  if (s.length <= maxLen) return s;
  return `${s.slice(0, maxLen)}…`;
}

/** Výchozí EUR za zúčtovatelnou jednotku – shodné se seedem v `platform_messaging_rates` (fallback při výpadku dotazu). */
const FALLBACK_UNIT_PRICES: Record<AutomationChannel, number> = {
  sms: 0.05,
  whatsapp: 0.08,
  email: 0.02,
  /** PROČ: Interní FCM není zpoplatněno přes Meta/Twilio – tarif v DB je 0. */
  internal_push: 0,
};

/**
 * PROČ: Načte aktuální globální tarif **jednou za běh** dispatchu (ne pro každou položku fronty).
 * Pro každý kanál bere řádek s nejnovějším `valid_from`, který je již platný (`<= now()`).
 */
async function loadUnitPricesByChannel(
  supabase: ReturnType<typeof createClient>,
): Promise<Record<AutomationChannel, number>> {
  const nowIso = new Date().toISOString();
  const { data, error } = await supabase
    .from("platform_messaging_rates")
    .select("channel, price_eur, valid_from")
    .lte("valid_from", nowIso);

  if (error) {
    console.warn(
      "[dispatch] platform_messaging_rates:",
      error.message,
      "- používám výchozí ceny (fallback)",
    );
    return { ...FALLBACK_UNIT_PRICES };
  }

  const rows = (data ?? []) as Array<{
    channel: string;
    price_eur: unknown;
    valid_from: string;
  }>;

  const best: Partial<Record<AutomationChannel, { t: number; p: number }>> = {};
  for (const r of rows) {
    const ch = r.channel as AutomationChannel;
    if (
      ch !== "sms" && ch !== "whatsapp" && ch !== "email" &&
      ch !== "internal_push"
    ) continue;
    const t = Date.parse(r.valid_from);
    const raw = r.price_eur;
    const p = typeof raw === "number" ? raw : Number(raw);
    if (!Number.isFinite(p)) continue;
    const prev = best[ch];
    if (!prev || t > prev.t) {
      best[ch] = { t, p };
    }
  }

  return {
    sms: best.sms?.p ?? FALLBACK_UNIT_PRICES.sms,
    whatsapp: best.whatsapp?.p ?? FALLBACK_UNIT_PRICES.whatsapp,
    email: best.email?.p ?? FALLBACK_UNIT_PRICES.email,
    internal_push: best.internal_push?.p ?? FALLBACK_UNIT_PRICES.internal_push,
  };
}

/**
 * PROČ: Když **Twilio** (SMS/WhatsApp) nebo **SMTP / Resend** (e-mail) vrátí chybu (4xx/5xx, síť…), nesmíme
 * nechat položku ve `pending` ani shodit celý Edge handler 500. Zapíšeme řádek do historie
 * (`tenant_message_log`, status `failed_at_provider`, `error_details`) a frontu uvolníme
 * přepisem na `failed` – UI „Čekárna“ zobrazuje jen `pending`. Platí stejně pro všechny kanály.
 *
 * POZOR: Nemažeme řádek ve frontě (`DELETE`), aby zůstala vazba `queue_id` → log; mazání by při
 * ON DELETE CASCADE smazalo i auditní řádek.
 */
async function recordOutboundFailureLogAndFailQueue(args: {
  supabase: ReturnType<typeof createClient>;
  tenantId: string;
  queueId: string;
  channel: AutomationChannel;
  recipientContact: string | null;
  contentSnapshot: string;
  dispatchNow: string;
  unitPrice: number;
  errMsg: string;
}): Promise<void> {
  const errDetails = truncateUtf8(args.errMsg, 8000);
  const snapshot = truncateUtf8(
    args.contentSnapshot.trim().length > 0 ? args.contentSnapshot : "(prázdný obsah)",
    40000,
  );

  const logInsert: TenantMessageLogInsert = {
    tenant_id: args.tenantId,
    queue_id: args.queueId,
    sent_at: args.dispatchNow,
    channel: args.channel,
    external_api_id: null,
    status: "failed_at_provider",
    unit_price: args.unitPrice,
    recipient_masked: formatRecipientMask(args.recipientContact, args.channel),
    content_snapshot: snapshot,
    error_details: errDetails,
  };

  const { error: insErr } = await args.supabase.from("tenant_message_log").insert({
    ...logInsert,
    direction: "outbound",
  });
  if (insErr) {
    console.error("[dispatch] tenant_message_log insert (provider failure):", insErr.message);
  }

  const { error: upErr } = await args.supabase
    .from("automation_message_queue")
    .update({
      status: "failed",
      last_error: truncateUtf8(args.errMsg, 2000),
      updated_at: args.dispatchNow,
    })
    .eq("id", args.queueId);

  if (upErr) {
    console.error("[dispatch] automation_message_queue -> failed:", upErr.message);
  }
}

/**
 * PROČ: Po `verify_jwt = false` na API gateway musíme ověřit volajícího uvnitř funkce.
 * Jinak by stačil veřejný `anon` klíč a URL funkce bez přihlášení.
 *
 * Povolené cesty:
 * - **Cron / pg_net:** Bearer token je přesně `SUPABASE_SERVICE_ROLE_KEY` (JWT service role),
 *   stejně jako v migraci `cron_edge_config.automation_edge_auth_token`.
 * - **Flutter (Odeslat okamžitě):** platný uživatelský JWT + `profiles.role` ∈ {admin, manager}.
 */
async function authorizeAutomationDispatchRequest(
  req: Request,
  jsonHeaders: Record<string, string>,
): Promise<Response | null> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return new Response(JSON.stringify({ ok: false, error: "Chybí Authorization Bearer" }), {
      status: 401,
      headers: jsonHeaders,
    });
  }

  const jwt = authHeader.slice(7).trim();
  if (jwt.length === 0) {
    return new Response(JSON.stringify({ ok: false, error: "Prázdný token" }), {
      status: 401,
      headers: jsonHeaders,
    });
  }

  const supabaseUrl = requireEnv("SUPABASE_URL");
  const serviceRoleKey = requireEnv("SUPABASE_SERVICE_ROLE_KEY").trim();
  if (jwt === serviceRoleKey) {
    return null;
  }

  const anonKey = requireEnv("SUPABASE_ANON_KEY");
  const userClient = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false },
    global: { headers: { Authorization: authHeader } },
  });

  const { data: userData, error: userErr } = await userClient.auth.getUser(jwt);
  if (userErr || !userData?.user?.id) {
    return new Response(JSON.stringify({ ok: false, error: "Neplatný nebo expirovaný token" }), {
      status: 401,
      headers: jsonHeaders,
    });
  }

  const userId = userData.user.id;
  const { data: profile, error: profErr } = await userClient
    .from("profiles")
    .select("role")
    .eq("id", userId)
    .maybeSingle();

  if (profErr) {
    console.error("[dispatch] authorize profiles:", profErr.message);
    return new Response(JSON.stringify({ ok: false, error: "Chyba načtení profilu" }), {
      status: 500,
      headers: jsonHeaders,
    });
  }

  const role = ((profile as { role?: string } | null)?.role ?? "").toLowerCase();
  if (role !== "admin" && role !== "manager") {
    return new Response(
      JSON.stringify({
        ok: false,
        error: "Pouze administrátor nebo manažer může spustit dispatch",
      }),
      { status: 403, headers: jsonHeaders },
    );
  }

  return null;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const jsonHeaders = { ...corsHeaders, "Content-Type": "application/json" };

  try {
  const authDenied = await authorizeAutomationDispatchRequest(req, jsonHeaders);
  if (authDenied) {
    return authDenied;
  }

  // Edge function může běžet jako cron trigger. Vstup ignorujeme a vracíme jen log/summary.
  const supabaseUrl = requireEnv("SUPABASE_URL");
  const serviceRoleKey = requireEnv("SUPABASE_SERVICE_ROLE_KEY");

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  const dispatchNow = nowUtcIso();

  // 1) NAČTENÍ Z FRONT:
  // Vybereme jen pending a jen ty, které už jsou splatné (scheduled_for <= now()).
  // Dávka (limit 20) zabrání přetížení externích API.
  const { data: rows, error: selectError } = await supabase
    .from("automation_message_queue")
    .select(
      "id, tenant_id, rule_id, entity_id, entity_type, scheduled_for, status, channel, recipient_contact, editable_payload, attempt_count, last_error",
    )
    .eq("status", "pending")
    .lte("scheduled_for", dispatchNow)
    .order("scheduled_for", { ascending: true })
    .limit(20);

  if (selectError) {
    console.error("[dispatch] Select failed:", selectError);
    return new Response(JSON.stringify({ ok: false, error: selectError.message }), {
      status: 500,
      headers: jsonHeaders,
    });
  }

  const messages = (rows ?? []) as AutomationMessageQueueRow[];

  // PROČ: Tarif načteme jednou z DB a použijeme pro celý batch; prázdná fronta = žádný dotaz na ceny.
  const unitPricesByChannel = messages.length > 0
    ? await loadUnitPricesByChannel(supabase)
    : FALLBACK_UNIT_PRICES;

  const results: Array<{
    id: string;
    status: "sent" | "failed" | "skipped";
    reason?: string;
  }> = [];

  // 2) ZPRACOVÁNÍ KAŽDÉ ZPRÁVY (Smyčka)
  for (const msg of messages) {
    const queueId = msg.id;
    const tenantId = msg.tenant_id;
    const channel = msg.channel;
    const text = extractTextFromEditablePayload(msg.editable_payload);
    const emailSubjectFromQueue = extractEmailSubjectFromEditablePayload(msg.editable_payload);
    const recipientContact = msg.recipient_contact;

    const emailAugmented = channel === "email"
      ? augmentEmailWithTaskDeepLink(text, msg.editable_payload)
      : { text, html: null as string | null };
    const textForChannel = emailAugmented.text;
    const emailHtmlForDispatch = emailAugmented.html;

    // internal_push: text šablony nepotřebujeme – titulek/tělo jsou pevné + data z rezervace (FCM v1).
    if (channel !== "internal_push" && !text) {
      // Bez textu nemá smysl odesílat – stejně jako u chyby providera zapíšeme historii a uvolníme frontu.
      await recordOutboundFailureLogAndFailQueue({
        supabase,
        tenantId,
        queueId,
        channel,
        recipientContact,
        contentSnapshot: "",
        dispatchNow,
        unitPrice: unitPricesByChannel[channel] ?? 0,
        errMsg: "Chybí text v editable_payload",
      });
      results.push({ id: queueId, status: "failed", reason: "empty_payload_text" });
      continue;
    }

    // --- A) Odeslání: Twilio/SMTP vs. FCM internal_push.
    let sendResult: DispatchSendResult;
    try {
      if (channel === "internal_push") {
        sendResult = await dispatchInternalPushForQueueItem({ supabase, msg });
      } else {
        sendResult = await sendWithSmartFallback({
          supabase,
          tenantId,
          queueId,
          channel,
          recipientContact,
          text: textForChannel,
          emailSubject: emailSubjectFromQueue,
          emailHtml: channel === "email" ? emailHtmlForDispatch : null,
        });
      }
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      await recordOutboundFailureLogAndFailQueue({
        supabase,
        tenantId,
        queueId,
        channel,
        recipientContact,
        contentSnapshot: channel === "internal_push"
          ? (text || "(internal_push)")
          : textForChannel,
        dispatchNow,
        unitPrice: unitPricesByChannel[channel] ?? 0,
        errMsg,
      });
      results.push({ id: queueId, status: "failed", reason: errMsg });
      continue;
    }

    const contentSnapshotForLog = sendResult.contentSnapshot ?? textForChannel;

    // --- B) Provider přijal zprávu – DB kroky odděleně (chyba DB nesmí vypadat jako zamítnutí Twiliem).
    try {
      await supabase
        .from("automation_message_queue")
        .update({ status: "sent", updated_at: dispatchNow })
        .eq("id", queueId);

      const sentAt = dispatchNow;
      const billingMonth = billingMonthUtcIsoDate(sentAt);
      const baseUnitPrice = unitPricesByChannel[channel] ?? 0;
      const billableUnits = sendResult.billableUnits;
      const totalLineCost = baseUnitPrice * billableUnits;

      const logInsert: TenantMessageLogInsert = {
        tenant_id: tenantId,
        queue_id: queueId,
        sent_at: sentAt,
        channel,
        external_api_id: sendResult.externalApiId,
        status: "sent",
        unit_price: totalLineCost,
        recipient_masked: formatRecipientMask(recipientContact, channel),
        content_snapshot: contentSnapshotForLog,
        error_details: null,
        metadata: { num_segments: billableUnits },
      };

      await supabase.from("tenant_message_log").insert({
        ...logInsert,
        direction: "outbound",
      });

      try {
        await upsertUsageMonthly({
          supabase,
          tenantId,
          channel,
          billingMonth,
          increment: billableUnits,
        });
      } catch (usageErr) {
        console.warn("[dispatch] upsertUsageMonthly po úspěšném odeslání selhalo:", usageErr);
      }

      results.push({ id: queueId, status: "sent" });
    } catch (dbErr) {
      const errMsg = dbErr instanceof Error ? dbErr.message : String(dbErr);
      console.error("[dispatch] DB po úspěšném odeslání u providerovi:", dbErr);
      results.push({
        id: queueId,
        status: "sent",
        reason: `post_send_db_error:${errMsg}`,
      });
    }
  }

  return new Response(JSON.stringify({
    ok: true,
    dispatched: messages.length,
    results,
  }), {
    status: 200,
    headers: jsonHeaders,
  });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error("[dispatch] Unhandled error:", e);
    return new Response(JSON.stringify({ ok: false, error: msg }), {
      status: 500,
      headers: jsonHeaders,
    });
  }
});

