// =============================================================================
// FalcoNest – Resend Webhook (doručení / bounce / stížnosti e-mailů)
// -----------------------------------------------------------------------------
// PROČ: Resend posílá asynchronní události (Svix) o reálném stavu e-mailu po
// odeslání z API. Uživatel tak vidí v `tenant_message_log` nejen „odesláno
// providerovi“ (`sent`), ale i finální **doručení** (`delivered`) nebo **selhání**
// (bounce, complaint, …). Sloupec `external_api_id` musí obsahovat stejné ID,
// jaké vrátí POST https://api.resend.com/emails (`id`, typicky `re_…`) – viz
// `automation-dispatch` (sendEmailViaResendHttpFallback).
//
// ZABEZPEČENÍ: Ověření podpisu Svix (`RESEND_WEBHOOK_SECRET`). Bez platného
// podpisu vracíme 401 – žádné falšování stavů z internetu.
//
// ŠKÁLOVÁNÍ: Dotaz je podle indexu `idx_tenant_message_log_external_api_id`;
// service role obchází RLS. Pro idempotenci doručení lze v budoucnu ukládat
// hlavičku `svix-id` (Resend doporučuje pro duplicity při retry).
// =============================================================================

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { checkRateLimit, getClientIpForRateLimit } from "../_shared/rate_limiter.ts";
// PROČ: Resend oficiálně používá Svix – stejná knihovna jako v dokumentaci.
import { Webhook } from "npm:svix@1.37.0";

/** Ochrana veřejného webhooku před flood (per IP, in-memory). */
const WEBHOOK_RATE_PER_MINUTE = 60;
const WEBHOOK_RATE_WINDOW_MS = 60_000;

function requireEnv(name: string): string {
  const v = Deno.env.get(name);
  if (!v || v.trim() === "") {
    throw new Error(`Chybí environment variable: ${name}`);
  }
  return v;
}

/**
 * PROČ: Mapujeme typy událostí Resend na textový `status` v `tenant_message_log`,
 * konzistentně s `twilio-webhook` (např. `delivered`, `failed_at_provider`).
 */
function mapResendEventToStatus(eventType: string, data: Record<string, unknown>): {
  status: string;
  errorDetails: string | null;
  /** PROČ: Po `email.delivered` smažeme starou chybovou hlášku (stejně jako Twilio). */
  clearErrorDetails: boolean;
} | null {
  switch (eventType) {
    case "email.delivered":
      return { status: "delivered", errorDetails: null, clearErrorDetails: true };

    case "email.bounced":
    case "email.failed":
    case "email.suppressed":
      return {
        status: "failed_at_provider",
        errorDetails: buildResendFailureDetails(eventType, data),
        clearErrorDetails: false,
      };

    case "email.complained":
      // PROČ: Doručeno, ale uživatel nahlásil spam – jiný význam než technický bounce.
      return {
        status: "complained",
        errorDetails: "Příjemce označil zprávu jako spam (complaint).",
        clearErrorDetails: false,
      };

    case "email.delivery_delayed":
      return {
        status: "delivery_delayed",
        errorDetails: buildResendFailureDetails(eventType, data),
        clearErrorDetails: false,
      };

    case "email.sent":
      // PROČ: API přijato – často už máme `sent` z dispatch; idempotentní doplnění.
      return { status: "sent", errorDetails: null, clearErrorDetails: false };

    default:
      // PROČ: Domain/contact eventy a neznámé typy – 200 bez DB změny (žádné retry smyčky).
      return null;
  }
}

/**
 * PROČ: Resend u různých eventů doplňuje `bounce`, případně jiná pole – serializujeme
 * do `error_details` pro audit v UI.
 */
function buildResendFailureDetails(eventType: string, data: Record<string, unknown>): string {
  const bounce = data["bounce"];
  if (bounce && typeof bounce === "object") {
    try {
      return `${eventType}: ${JSON.stringify(bounce)}`;
    } catch {
      return `${eventType}: (bounce object)`;
    }
  }
  const raw = data["error"] ?? data["message"] ?? data["reason"];
  if (typeof raw === "string" && raw.trim().length > 0) {
    return `${eventType}: ${raw.trim()}`;
  }
  try {
    return `${eventType}: ${JSON.stringify(data)}`;
  } catch {
    return eventType;
  }
}

/**
 * PROČ: `data.email_id` odpovídá poli `id` z odpovědi Emails API (uložené v
 * `external_api_id`). Fallback pro případné aliasy v payloadu.
 */
function extractEmailId(data: Record<string, unknown>): string | null {
  const a = data["email_id"];
  if (typeof a === "string" && a.trim().length > 0) return a.trim();
  const b = data["id"];
  if (typeof b === "string" && b.trim().length > 0) return b.trim();
  return null;
}

serve(async (req) => {
  const clientIp = getClientIpForRateLimit(req);
  if (!checkRateLimit(clientIp, WEBHOOK_RATE_PER_MINUTE, WEBHOOK_RATE_WINDOW_MS)) {
    return new Response("Rate limit exceeded", {
      status: 429,
      headers: { "Content-Type": "text/plain; charset=utf-8" },
    });
  }

  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, svix-id, svix-timestamp, svix-signature",
      },
    });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ ok: false, error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  const jsonHeaders = { "Content-Type": "application/json" };

  const svixId = req.headers.get("svix-id");
  const svixTimestamp = req.headers.get("svix-timestamp");
  const svixSignature = req.headers.get("svix-signature");

  if (!svixId || !svixTimestamp || !svixSignature) {
    return new Response(JSON.stringify({ ok: false, error: "Chybí Svix hlavičky" }), {
      status: 401,
      headers: jsonHeaders,
    });
  }

  const rawBody = await req.text();

  let webhookSecret: string;
  try {
    webhookSecret = requireEnv("RESEND_WEBHOOK_SECRET");
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error("[resend-webhook]", msg);
    return new Response(JSON.stringify({ ok: false, error: "Server misconfiguration" }), {
      status: 500,
      headers: jsonHeaders,
    });
  }

  const wh = new Webhook(webhookSecret);

  // PROČ: Musí být přesně raw řetězec těla – jakékoli přeparse JSON rozbije podpis.
  let evt: Record<string, unknown>;
  try {
    evt = wh.verify(rawBody, {
      "svix-id": svixId,
      "svix-timestamp": svixTimestamp,
      "svix-signature": svixSignature,
    }) as Record<string, unknown>;
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.warn("[resend-webhook] Ověření podpisu selhalo:", msg);
    return new Response(JSON.stringify({ ok: false, error: "Neplatný webhook podpis" }), {
      status: 401,
      headers: jsonHeaders,
    });
  }

  const eventType = typeof evt["type"] === "string" ? (evt["type"] as string) : "";
  const dataRaw = evt["data"];
  const data = dataRaw && typeof dataRaw === "object" && !Array.isArray(dataRaw)
    ? dataRaw as Record<string, unknown>
    : null;

  if (!data) {
    return new Response(JSON.stringify({ ok: true, ignored: true, reason: "empty_data" }), {
      status: 200,
      headers: jsonHeaders,
    });
  }

  const emailId = extractEmailId(data);
  if (!emailId) {
    console.warn("[resend-webhook] Chybí email_id v payloadu, typ:", eventType);
    return new Response(JSON.stringify({ ok: true, ignored: true, reason: "no_email_id" }), {
      status: 200,
      headers: jsonHeaders,
    });
  }

  const mapped = mapResendEventToStatus(eventType, data);
  if (!mapped) {
    return new Response(JSON.stringify({ ok: true, ignored: true, event: eventType }), {
      status: 200,
      headers: jsonHeaders,
    });
  }

  const supabaseUrl = requireEnv("SUPABASE_URL");
  const serviceRoleKey = requireEnv("SUPABASE_SERVICE_ROLE_KEY");
  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  const updatePayload: Record<string, unknown> = {
    status: mapped.status,
  };

  if (mapped.clearErrorDetails) {
    updatePayload["error_details"] = null;
  } else if (mapped.errorDetails) {
    const truncated = mapped.errorDetails.length > 8000
      ? `${mapped.errorDetails.slice(0, 7999)}…`
      : mapped.errorDetails;
    updatePayload["error_details"] = truncated;
  }

  // PROČ: Filtr `channel = email` zabraňuje hypotetické kolizi ID s jiným kanálem.
  const { data: updatedRows, error } = await supabase
    .from("tenant_message_log")
    .update(updatePayload)
    .eq("external_api_id", emailId)
    .eq("channel", "email")
    .select("id");

  if (error) {
    console.error("[resend-webhook] Update tenant_message_log:", error.message);
    return new Response(JSON.stringify({ ok: false, error: error.message }), {
      status: 500,
      headers: jsonHeaders,
    });
  }

  const count = Array.isArray(updatedRows) ? updatedRows.length : 0;
  if (count === 0) {
    // PROČ: Může jít o jiný účet / test / stará zpráva bez uloženého ID – nechceme 500.
    console.warn("[resend-webhook] Žádný řádek pro external_api_id=", emailId, "event=", eventType);
  }

  return new Response(
    JSON.stringify({ ok: true, updated: count, event: eventType, email_id: emailId }),
    { status: 200, headers: jsonHeaders },
  );
});
