// =============================================================================
// FalcoNest – Self-service nákup Twilio telefonního čísla pro agenturu (B2B)
// -----------------------------------------------------------------------------
// PROČ: Admin/manager si z UI zakoupí lokální číslo v povolené zemi; uložíme ho do
// `tenants.integration_settings.twilio_phone_number` (merge JSONB). Dispatch SMS pak
// použije toto číslo jako `From` místo globálního TWILIO_PHONE_NUMBER.
//
// Zabezpečení: JWT musí patřit uživateli s profiles.tenant_id a rolí admin/manager.
// Zapisujeme přes service role jen po ověření shody tenant_id.
// =============================================================================

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

/** Země povolené v MVP (bez CZ – často vyžaduje adresu / manuální schválení u Twilio). */
const ALLOWED_COUNTRY_CODES = new Set(["US", "GB", "ES"]);

function requireEnv(name: string): string {
  const v = Deno.env.get(name);
  if (!v || v.trim() === "") {
    throw new Error(`Chybí environment variable: ${name}`);
  }
  return v;
}

function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

/// PROČ: Twilio REST API používá HTTP Basic (Account SID + Auth Token).
function twilioBasicAuthHeader(): string {
  const accountSid = requireEnv("TWILIO_ACCOUNT_SID");
  const authToken = requireEnv("TWILIO_AUTH_TOKEN");
  return `Basic ${btoa(`${accountSid}:${authToken}`)}`;
}

/**
 * PROČ: Příchozí SMS musí jít na funkci `twilio-inbound` (parsování From/Body, tenant).
 * Funkce `twilio-webhook` je určena pro **Status Callback** odchozích zpráv (MessageSid),
 * ne pro příjem SMS od zákazníků.
 */
function buildTwilioInboundSmsUrl(): string {
  const base = requireEnv("SUPABASE_URL").replace(/\/$/, "");
  return `${base}/functions/v1/twilio-inbound`;
}

/**
 * PROČ: Hlasový webhook – Twilio u některých čísel vyžaduje VoiceUrl; jednoduchý demo
 * endpoint, aby hovory nespadly (SMS je primární use-case).
 */
function buildTwilioVoiceFallbackUrl(): string {
  return "https://demo.twilio.com/welcome/voice/";
}

async function fetchFirstAvailableNumber(
  accountSid: string,
  countryCode: string,
): Promise<string | null> {
  const auth = twilioBasicAuthHeader();
  const base = `https://api.twilio.com/2010-04-01/Accounts/${accountSid}`;

  for (const type of ["Local", "Mobile"] as const) {
    const url =
      `${base}/AvailablePhoneNumbers/${countryCode}/${type}.json?PageSize=5`;
    const res = await fetch(url, { headers: { Authorization: auth } });
    const text = await res.text();
    if (!res.ok) {
      console.warn(`[twilio-provision] ${type} list failed:`, res.status, text);
      continue;
    }
    try {
      const json = JSON.parse(text) as Record<string, unknown>;
      const arr = json["available_phone_numbers"] as Array<Record<string, unknown>> | undefined;
      if (Array.isArray(arr) && arr.length > 0) {
        const first = arr[0]["phone_number"];
        if (typeof first === "string" && first.trim().length > 0) {
          return first.trim();
        }
      }
    } catch {
      // další typ
    }
  }
  return null;
}

async function purchaseIncomingNumber(args: {
  accountSid: string;
  phoneNumber: string;
  smsUrl: string;
  voiceUrl: string;
}): Promise<{ sid: string; phoneNumber: string }> {
  const auth = twilioBasicAuthHeader();
  const url =
    `https://api.twilio.com/2010-04-01/Accounts/${args.accountSid}/IncomingPhoneNumbers.json`;

  const form = new URLSearchParams({
    PhoneNumber: args.phoneNumber,
    SmsUrl: args.smsUrl,
    SmsMethod: "POST",
    VoiceUrl: args.voiceUrl,
    VoiceMethod: "POST",
  });

  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: auth,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: form.toString(),
  });

  const text = await res.text();
  if (!res.ok) {
    let detail = text;
    try {
      const j = JSON.parse(text) as Record<string, unknown>;
      detail = (j["message"] as string) ?? text;
    } catch {
      // ponecháme raw
    }
    throw new Error(`Twilio nákup čísla selhal: ${res.status} ${detail}`);
  }

  const json = JSON.parse(text) as Record<string, unknown>;
  const sid = json["sid"];
  const phone = json["phone_number"];
  if (typeof sid !== "string" || typeof phone !== "string") {
    throw new Error("Twilio: neočekávaná odpověď při nákupu čísla");
  }
  return { sid: sid.trim(), phoneNumber: phone.trim() };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return jsonResponse({ error: "Chybí Authorization Bearer" }, 401);
    }

    const jwt = authHeader.slice(7).trim();
    const supabaseUrl = requireEnv("SUPABASE_URL");
    const anonKey = requireEnv("SUPABASE_ANON_KEY");
    const serviceKey = requireEnv("SUPABASE_SERVICE_ROLE_KEY");

    const userClient = createClient(supabaseUrl, anonKey, {
      auth: { persistSession: false },
      global: { headers: { Authorization: authHeader } },
    });

    const { data: userData, error: userErr } = await userClient.auth.getUser(jwt);
    if (userErr || !userData?.user?.id) {
      return jsonResponse({ error: "Neplatný nebo expirovaný token" }, 401);
    }
    const userId = userData.user.id;

    const { data: profile, error: profErr } = await userClient
      .from("profiles")
      .select("tenant_id, role")
      .eq("id", userId)
      .maybeSingle();

    if (profErr) {
      console.error("[twilio-provision] profiles:", profErr.message);
      return jsonResponse({ error: "Chyba načtení profilu" }, 500);
    }

    const tenantId = (profile as { tenant_id?: string | null } | null)?.tenant_id?.trim() ?? "";
    const role = ((profile as { role?: string } | null)?.role ?? "").toLowerCase();

    if (!tenantId) {
      return jsonResponse({ error: "Účet nemá přiřazenou agenturu" }, 403);
    }
    if (role !== "admin" && role !== "manager") {
      return jsonResponse({ error: "Pouze administrátor nebo manažer může zakoupit číslo" }, 403);
    }

    let body: { countryCode?: string };
    try {
      body = await req.json() as { countryCode?: string };
    } catch {
      return jsonResponse({ error: "Neplatné JSON tělo" }, 400);
    }

    const rawCc = (body.countryCode ?? "").trim().toUpperCase();
    if (!ALLOWED_COUNTRY_CODES.has(rawCc)) {
      return jsonResponse({
        error: `Nepovolená země. Povolené: ${[...ALLOWED_COUNTRY_CODES].join(", ")}`,
      }, 400);
    }

    const admin = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false },
    });

    const { data: tenantRow, error: tenantErr } = await admin
      .from("tenants")
      .select("integration_settings")
      .eq("id", tenantId)
      .maybeSingle();

    if (tenantErr || !tenantRow) {
      return jsonResponse({ error: "Tenant nenalezen" }, 404);
    }

    const rawInt = (tenantRow as { integration_settings?: unknown }).integration_settings;
    let current: Record<string, unknown> = {};
    if (rawInt && typeof rawInt === "object" && !Array.isArray(rawInt)) {
      current = { ...(rawInt as Record<string, unknown>) };
    }

    const existing = current["twilio_phone_number"];
    if (typeof existing === "string" && existing.trim().length > 0) {
      return jsonResponse({
        ok: true,
        twilio_phone_number: existing.trim(),
        alreadyProvisioned: true,
      });
    }

    const accountSid = requireEnv("TWILIO_ACCOUNT_SID");
    const available = await fetchFirstAvailableNumber(accountSid, rawCc);
    if (!available) {
      return jsonResponse({
        error: `V zemi ${rawCc} nejsou momentálně dostupná žádná čísla (Local/Mobile). Zkuste jinou zemi.`,
      }, 422);
    }

    const smsUrl = buildTwilioInboundSmsUrl();
    const voiceUrl = buildTwilioVoiceFallbackUrl();

    const purchased = await purchaseIncomingNumber({
      accountSid,
      phoneNumber: available,
      smsUrl,
      voiceUrl,
    });

    current["twilio_phone_number"] = purchased.phoneNumber;

    const { error: updErr } = await admin
      .from("tenants")
      .update({ integration_settings: current })
      .eq("id", tenantId);

    if (updErr) {
      console.error("[twilio-provision] update tenants:", updErr.message);
      return jsonResponse({ error: "Uložení čísla do databáze selhalo" }, 500);
    }

    return jsonResponse({
      ok: true,
      twilio_phone_number: purchased.phoneNumber,
      incoming_phone_sid: purchased.sid,
      alreadyProvisioned: false,
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error("[twilio-provision]", e);
    return jsonResponse({ error: msg }, 500);
  }
});
