// =============================================================================
// FalcoNest – Twilio Inbound SMS / WhatsApp Webhook
// -----------------------------------------------------------------------------
// PROČ: Twilio volá tento endpoint při příchozí zprávě (POST, form-urlencoded).
// Najdeme tenant podle telefonu odesílatele v `clients` / `reservations` a uložíme
// řádek do `tenant_message_log` se směrem inbound.
//
// Zabezpečení (MVP): V produkci ověřte `X-Twilio-Signature` vůči TWILIO_AUTH_TOKEN.
// =============================================================================

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { checkRateLimit, getClientIpForRateLimit } from "../_shared/rate_limiter.ts";

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

function twilioOkEmpty(): Response {
  return new Response(
    `<?xml version="1.0" encoding="UTF-8"?><Response></Response>`,
    {
      status: 200,
      headers: { "Content-Type": "text/xml; charset=utf-8" },
    },
  );
}

/// PROČ: Twilio u WhatsApp posílá `From` jako `whatsapp:+420...`; pro párování s DB
/// čísly bereme kanál z prefixu a číslo ořežeme o `whatsapp:`.
function parseFromHeader(fromRaw: string): {
  channel: "whatsapp" | "sms";
  phoneForMatch: string;
} {
  const t = fromRaw.trim();
  if (t.toLowerCase().startsWith("whatsapp:")) {
    return {
      channel: "whatsapp",
      phoneForMatch: t.slice("whatsapp:".length).trim(),
    };
  }
  return { channel: "sms", phoneForMatch: t };
}

function normalizePhoneDigits(input: string): string {
  return input.replace(/\D/g, "");
}

/// PROČ: V DB může být číslo uložené s/beze země; porovnáváme normalizované číslice
/// a případně posledních 9 číslic (mobilní část).
function phonesMatch(dbPhone: string | null | undefined, inboundDigits: string): boolean {
  if (!dbPhone) return false;
  const d = normalizePhoneDigits(dbPhone);
  if (d.length === 0 || inboundDigits.length === 0) return false;
  if (d === inboundDigits) return true;
  const minLen = 8;
  if (d.length >= minLen && inboundDigits.length >= minLen) {
    if (d.slice(-9) === inboundDigits.slice(-9)) return true;
  }
  return d.endsWith(inboundDigits) || inboundDigits.endsWith(d);
}

/// PROČ: Stejná heuristika jako u outbound logu – v UI neukazujeme plné číslo (PII).
function maskPhoneForLog(contact: string): string | null {
  const trimmed = contact.trim();
  if (trimmed.length === 0) return null;
  const digits = trimmed.replace(/\D/g, "");
  const last3 = digits.slice(-3);
  return `***${last3}`;
}

/**
 * ROUTING: Nejprve `clients.phone`, pak `reservations.guest_phone` (host).
 * PROČ: Host odpovídá z čísla uloženého u klienta CRM nebo u rezervace.
 */
async function findTenantIdForInboundPhone(
  supabase: ReturnType<typeof createClient>,
  phoneForMatch: string,
): Promise<string | null> {
  const inboundDigits = normalizePhoneDigits(phoneForMatch);

  const { data: clientRows, error: e1 } = await supabase
    .from("clients")
    .select("tenant_id, phone")
    .is("deleted_at", null)
    .not("phone", "is", null);

  if (e1) {
    console.error("[twilio-inbound] Chyba čtení clients:", e1.message);
  } else {
    for (const row of clientRows ?? []) {
      const tid = row.tenant_id as string | undefined;
      if (tid && phonesMatch(row.phone as string, inboundDigits)) {
        return tid;
      }
    }
  }

  const { data: resRows, error: e2 } = await supabase
    .from("reservations")
    .select("tenant_id, guest_phone")
    .not("guest_phone", "is", null);

  if (e2) {
    console.error("[twilio-inbound] Chyba čtení reservations:", e2.message);
  } else {
    for (const row of resRows ?? []) {
      const tid = row.tenant_id as string | undefined;
      if (tid && phonesMatch(row.guest_phone as string, inboundDigits)) {
        return tid;
      }
    }
  }

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

  if (req.method !== "POST") {
    return twilioOkEmpty();
  }

  // PROČ: Twilio posílá inbound stejně jako status callback – form-urlencoded, ne JSON.
  const raw = await req.text();
  const params = new URLSearchParams(raw);

  const fromRaw = params.get("From")?.trim() ?? "";
  // To = naše Twilio číslo (MessageSid párujeme; routing je podle From).
  const body = params.get("Body")?.trim() ?? "";
  const messageSid = params.get("MessageSid")?.trim() ?? "";

  // --- Zabezpečení (MVP): ověření Twilio signatury zde doplnit před produkcí ---
  // const signature = req.headers.get("X-Twilio-Signature");
  // validateTwilioRequest(signature, raw, publicUrl);

  if (!fromRaw || !messageSid) {
    console.warn("[twilio-inbound] Chybí From nebo MessageSid – ukončuji bez zápisu");
    return twilioOkEmpty();
  }

  const { channel, phoneForMatch } = parseFromHeader(fromRaw);

  const supabaseUrl = requireEnv("SUPABASE_URL");
  const serviceRoleKey = requireEnv("SUPABASE_SERVICE_ROLE_KEY");
  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  const tenantId = await findTenantIdForInboundPhone(supabase, phoneForMatch);

  if (!tenantId) {
    console.warn(
      "[twilio-inbound] Nenalezen tenant pro telefon (clients/reservations):",
      phoneForMatch,
    );
    return twilioOkEmpty();
  }

  const sentAt = new Date().toISOString();
  const masked = maskPhoneForLog(phoneForMatch);

  const { error: insErr } = await supabase.from("tenant_message_log").insert({
    tenant_id: tenantId,
    queue_id: null,
    sent_at: sentAt,
    channel,
    direction: "inbound",
    external_api_id: messageSid,
    status: "delivered",
    unit_price: null,
    recipient_masked: masked,
    content_snapshot: body,
    inbound_text: body,
    error_details: null,
  });

  if (insErr) {
    console.error("[twilio-inbound] Insert tenant_message_log selhal:", insErr.message);
  }

  return twilioOkEmpty();
});
