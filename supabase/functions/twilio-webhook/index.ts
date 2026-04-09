// =============================================================================
// FalcoNest – Twilio Status Callback Webhook
// -----------------------------------------------------------------------------
// PROČ: Twilio volá tento endpoint (POST, application/x-www-form-urlencoded) při
// změnách stavu zprávy (queued → sent → delivered / failed). Uložíme reálný stav
// do `tenant_message_log` podle `MessageSid` (= external_api_id z odesílání).
//
// ZABEZPEČENÍ: Ověření podpisu `X-Twilio-Signature` (HMAC-SHA1) podle oficiálního
// algoritmu Twilio: řetězec = plná URL požadavku + seřazené klíče POST parametrů,
// každý jako `key`+`value`. Tajný klíč je `TWILIO_AUTH_TOKEN` (stejný jako u REST API).
//
// PROČ URL: Twilio podepisuje **přesně** URL, na kterou callback posílá. V Supabase Edge
// musí být shodná s hodnotou v Twilio Console – nastavte `TWILIO_STATUS_CALLBACK_URL`
// na tutéž veřejnou adresu (včetně https, bez rozdílného trailing slash).
// =============================================================================

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { checkRateLimit, getClientIpForRateLimit } from "../_shared/rate_limiter.ts";

/** Ochrana veřejného webhooku před bruteforce / flood (per IP, in-memory). */
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
 * PROČ: Stejný postup jako oficiální `validateRequest` v Twilio SDK – URL + seřazené
 * páry klíč/hodnota z těla formuláře, pak HMAC-SHA1 s Auth Tokenem, výsledek Base64.
 */
async function validateTwilioSignature(args: {
  authToken: string;
  twilioSignature: string;
  /** Plná URL, kterou Twilio použilo pro callback (musí sedět s konfigurací u Twilio). */
  requestUrl: string;
  /** Všechny POST parametry (hodnoty tak, jak přišly po parse těla). */
  params: Record<string, string>;
}): Promise<boolean> {
  const sortedKeys = Object.keys(args.params).sort();
  let data = args.requestUrl;
  for (const key of sortedKeys) {
    data += key + args.params[key];
  }

  const encoder = new TextEncoder();
  const keyMaterial = await crypto.subtle.importKey(
    "raw",
    encoder.encode(args.authToken),
    { name: "HMAC", hash: "SHA-1" },
    false,
    ["sign"],
  );

  const sigBuf = await crypto.subtle.sign(
    "HMAC",
    keyMaterial,
    encoder.encode(data),
  );
  const expected = btoa(String.fromCharCode(...new Uint8Array(sigBuf)));

  // PROČ: Konstantní čas – zabrání úniku podpisu při porovnání řetězců.
  if (expected.length !== args.twilioSignature.length) {
    return false;
  }
  let diff = 0;
  for (let i = 0; i < expected.length; i++) {
    diff |= expected.charCodeAt(i) ^ args.twilioSignature.charCodeAt(i);
  }
  return diff === 0;
}

/**
 * PROČ: URL z `req.url` může u proxy lišit od adresy v Twilio Console. Primárně bereme
 * `TWILIO_STATUS_CALLBACK_URL` (stejná proměnná jako u `StatusCallback` v automation-dispatch).
 */
function resolveTwilioRequestUrl(req: Request): string {
  const configured = Deno.env.get("TWILIO_STATUS_CALLBACK_URL")?.trim();
  if (configured && configured.length > 0) {
    return configured.replace(/\/+$/, "");
  }
  const u = new URL(req.url);
  return `${u.protocol}//${u.host}${u.pathname}${u.search}`;
}

function urlSearchParamsToLastWinRecord(sp: URLSearchParams): Record<string, string> {
  const o: Record<string, string> = {};
  for (const [k, v] of sp.entries()) {
    o[k] = v;
  }
  return o;
}

/**
 * PROČ: Mapujeme Twilio `MessageStatus` na `tenant_message_log.status` (text).
 * Sladíme se s existujícími hodnotami v DB (`sent`, `delivered`, `failed_at_provider`).
 */
function mapTwilioStatusToDb(messageStatus: string): {
  status: string;
  isFailure: boolean;
} {
  const s = (messageStatus ?? "").trim().toLowerCase();
  if (s === "delivered" || s === "read") {
    return { status: "delivered", isFailure: false };
  }
  if (
    s === "failed" || s === "undelivered" || s === "canceled" ||
    s === "failed_sms"
  ) {
    return { status: "failed_at_provider", isFailure: true };
  }
  // queued, sending, sent, accepted → mezistanice (čekáme na webhook)
  return { status: "sent", isFailure: false };
}

function buildErrorDetails(args: {
  errorCode: string | null;
  errorMessage: string | null;
}): string | null {
  const parts: string[] = [];
  if (args.errorCode) parts.push(`ErrorCode=${args.errorCode}`);
  if (args.errorMessage) parts.push(args.errorMessage);
  return parts.length > 0 ? parts.join(" | ") : null;
}

function twilioOkEmpty(): Response {
  // PROČ: Twilio opakuje webhooky, pokud nevrátíme 200 + prázdný TwiML.
  return new Response(
    `<?xml version="1.0" encoding="UTF-8"?><Response></Response>`,
    {
      status: 200,
      headers: { "Content-Type": "text/xml; charset=utf-8" },
    },
  );
}

function unauthorizedTwilio(): Response {
  return new Response(
    JSON.stringify({ ok: false, error: "Neplatný Twilio podpis" }),
    {
      status: 401,
      headers: { "Content-Type": "application/json" },
    },
  );
}

serve(async (req) => {
  const clientIp = getClientIpForRateLimit(req);
  if (!checkRateLimit(clientIp, WEBHOOK_RATE_PER_MINUTE, WEBHOOK_RATE_WINDOW_MS)) {
    return new Response("Rate limit exceeded", {
      status: 429,
      headers: { "Content-Type": "text/plain; charset=utf-8" },
    });
  }

  if (req.method !== "POST") {
    return twilioOkEmpty();
  }

  // PROČ: Twilio posílá Status Callback jako application/x-www-form-urlencoded (ne JSON).
  const raw = await req.text();
  const sp = new URLSearchParams(raw);
  const paramRecord = urlSearchParamsToLastWinRecord(sp);

  const signature = req.headers.get("X-Twilio-Signature")?.trim() ?? "";
  if (!signature) {
    console.warn("[twilio-webhook] Chybí X-Twilio-Signature");
    return unauthorizedTwilio();
  }

  let authToken: string;
  try {
    authToken = requireEnv("TWILIO_AUTH_TOKEN");
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error("[twilio-webhook]", msg);
    return new Response(JSON.stringify({ ok: false, error: "Server misconfiguration" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const requestUrl = resolveTwilioRequestUrl(req);
  const ok = await validateTwilioSignature({
    authToken,
    twilioSignature: signature,
    requestUrl,
    params: paramRecord,
  });

  if (!ok) {
    console.warn("[twilio-webhook] Ověření podpisu selhalo (URL zkus sjednotit s TWILIO_STATUS_CALLBACK_URL)");
    return unauthorizedTwilio();
  }

  const messageSid = sp.get("MessageSid")?.trim() ?? "";
  const messageStatus = sp.get("MessageStatus")?.trim() ?? "";
  const errorCode = sp.get("ErrorCode")?.trim() ?? null;
  const errorMessage = sp.get("ErrorMessage")?.trim() ?? null;

  if (!messageSid) {
    console.warn("[twilio-webhook] Chybí MessageSid – ignorujeme");
    return twilioOkEmpty();
  }

  const mapped = mapTwilioStatusToDb(messageStatus);

  const supabaseUrl = requireEnv("SUPABASE_URL");
  const serviceRoleKey = requireEnv("SUPABASE_SERVICE_ROLE_KEY");
  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  const errDetails = mapped.isFailure
    ? buildErrorDetails({ errorCode, errorMessage })
    : null;

  const updatePayload: Record<string, unknown> = {
    status: mapped.status,
  };

  if (mapped.status === "delivered") {
    // PROČ: Po úspěšném doručení smažeme starou chybovou hlášku (případný retry).
    updatePayload.error_details = null;
  } else if (errDetails) {
    updatePayload.error_details = errDetails;
  }

  const { error } = await supabase
    .from("tenant_message_log")
    .update(updatePayload)
    .eq("external_api_id", messageSid);

  if (error) {
    console.error("[twilio-webhook] Update tenant_message_log selhal:", error.message);
  }

  return twilioOkEmpty();
});
