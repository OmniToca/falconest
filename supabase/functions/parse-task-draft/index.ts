// Supabase Edge Function – parsování volného textu na návrh formuláře úkolu (Human-in-the-loop).
//
// PROČ: Dispečer vloží WhatsApp zprávu; LLM extrahuje pole; server páruje apartmán v rámci
// tenant_id; klient pouze předvyplní formulář – žádný INSERT do tasks.
//
// Volání: POST + Authorization Bearer (admin/manager).
// Tělo: { raw_text?, image_base64?, image_mime_type?, reference_now_utc, locale?, tenant_timezone? }
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from "npm:@supabase/supabase-js@2"
import { checkRateLimit } from "../_shared/rate_limiter.ts"
import {
  geminiStructuredJsonWithAutoModel,
  TASK_PARSE_RESPONSE_SCHEMA,
} from "../_shared/gemini_structured_client.ts"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

const MAX_RAW_TEXT_LENGTH = 2000
/** Max délka Base64 (po kompresi na klientovi cca ≤ ~900 KB binárně). */
const MAX_IMAGE_BASE64_LENGTH = 1_400_000
const RATE_LIMIT_MAX = 30
const RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000
const APARTMENT_CONFIDENCE_THRESHOLD = 0.85
const DEFAULT_TIMEZONE = "Europe/Madrid"
const DEFAULT_DURATION_MINUTES = 60

type LlmParseResult = {
  task_mode: "apartment_bound" | "external_service" | "unknown"
  title: string
  description: string
  scheduled_start_local: string | null
  duration_minutes: number
  apartment_hint: string | null
  service_hint: string | null
  client_hint: string | null
  custom_location_hint: string | null
  /** Domluvená částka z textu (EUR číslo), null pokud neuvedeno. */
  price: number | null
  /** true = hotovost na místě, false = faktura/předem, null = neuvedeno. */
  is_cash_payment: boolean | null
}

type ApartmentRow = {
  id: string
  name: string
  code: string | null
  address: string | null
}

type ApartmentCandidate = {
  id: string
  label: string
  subtitle: string | null
  confidence: number
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  })
}

function requireEnv(name: string): string {
  const v = Deno.env.get(name)
  if (!v) throw new Error(`Missing env ${name}`)
  return v
}

/** Odstraní běžné prefixy z hintu apartmánu („apartmán A1“ → „a1“). */
function normalizeApartmentHint(raw: string): string {
  let s = raw.trim().toLowerCase()
  const prefixes = [
    "apartamento",
    "apartmán",
    "apartman",
    "apartment",
    "apt",
    "byt",
    "piso",
    "flat",
  ]
  for (const p of prefixes) {
    if (s.startsWith(p + " ")) s = s.slice(p.length + 1).trim()
    if (s.startsWith(p + ".")) s = s.slice(p.length + 1).trim()
  }
  return s.replace(/\s+/g, " ").trim()
}

function scoreApartmentMatch(hint: string, apt: ApartmentRow): number {
  const h = normalizeApartmentHint(hint)
  if (!h) return 0
  const code = (apt.code ?? "").trim().toLowerCase()
  const name = (apt.name ?? "").trim().toLowerCase()
  if (code && code === h) return 1.0
  if (name && name === h) return 0.95
  if (code && (code.includes(h) || h.includes(code))) return 0.88
  if (name && (name.includes(h) || h.includes(name))) return 0.82
  return 0
}

function extractJson(text: string): Record<string, unknown> | null {
  const trimmed = text.trim()
  const match = trimmed.match(/\{[\s\S]*\}/)
  if (!match) return null
  try {
    return JSON.parse(match[0]) as Record<string, unknown>
  } catch {
    return null
  }
}

/** LLM extrakce přes Gemini Structured Output; při výpadku vrátí null (fallback níže). */
async function tryLlmParse(args: {
  apiKey: string
  rawText: string
  referenceNowUtc: string
  tenantTimezone: string
  locale: string
  imageBase64?: string | null
  imageMimeType?: string | null
}): Promise<LlmParseResult | null> {
  const hasImage = !!(args.imageBase64 && args.imageBase64.trim())
  const prompt = `Extract task scheduling fields from informal messages (WhatsApp, SMS)${
    hasImage ? " and/or from the attached screenshot image (OCR the chat bubbles)" : ""
  }.

STRICT DATETIME RULES (critical – wrong timezone breaks the dispatcher form):
- scheduled_start_local must be the user's wall-clock time in timezone ${args.tenantTimezone}.
- Format EXACTLY: YYYY-MM-DDTHH:mm:ss (example: 2026-08-26T11:15:00).
- Do NOT append Z, do NOT use UTC, do NOT include +01:00 / +02:00 offsets.
- If the message says "11:15", output hour 11 and minute 15 (same digits the user wrote).
- Interpret relative words ("tomorrow", "zítra", "mañana") using reference_now_utc ${args.referenceNowUtc} and timezone ${args.tenantTimezone}; still emit local wall-clock without Z.

Other fields:
- task_mode: "apartment_bound" | "external_service" | "unknown"
- title: short task title in the same language as the message (max 8 words)
- description: full description
- duration_minutes: integer, default 60
- apartment_hint: apartment code or name mentioned (e.g. "A1"), null if none
- service_hint: service type hint (cleaning, transfer, maintenance…), null if unclear
- client_hint: short client/person name mentioned (e.g. "Jura" from "Jedu pro Juru"), null if none
- custom_location_hint: address for external service, null otherwise
- price: numeric amount only (e.g. 10 from "10eur" / "cena je 10 €" / "10 euros"); null if no price mentioned. Never include currency symbol – number only.
- is_cash_payment: true if cash on site is implied ("hotovost", "cash", "platí na místě", "vybere personál"); false if invoice/prepaid ("faktura", "invoice", "předem", "převodem"); null if payment method not mentioned.

Locale hint: ${args.locale}. Prefer apartment_bound when an apartment/unit is mentioned. Prefer external_service for airport transfers / rides without a unit code. Always extract client_hint nicknames/first names when a person is mentioned.
${hasImage ? "\nIf an image is attached, read text from the screenshot and merge with any pasted text below. Prefer explicit text over UI chrome (timestamps in WhatsApp header, etc.).\n" : ""}
Message:
${args.rawText || "(no pasted text – use image only)"}`

  const content = await geminiStructuredJsonWithAutoModel({
    apiKey: args.apiKey,
    prompt,
    responseSchema: TASK_PARSE_RESPONSE_SCHEMA as unknown as Record<string, unknown>,
    imageBase64: args.imageBase64,
    imageMimeType: args.imageMimeType,
  })

  const parsed = extractJson(content)
  if (!parsed) return null

  const taskMode = parsed.task_mode
  const mode =
    taskMode === "external_service" || taskMode === "apartment_bound" || taskMode === "unknown"
      ? taskMode
      : "unknown"

  let duration = DEFAULT_DURATION_MINUTES
  const durRaw = parsed.duration_minutes
  if (typeof durRaw === "number" && durRaw > 0) duration = Math.round(durRaw)
  if (typeof durRaw === "string") {
    const p = parseInt(durRaw, 10)
    if (p > 0) duration = p
  }

  let price: number | null = null
  const priceRaw = parsed.price
  if (typeof priceRaw === "number" && Number.isFinite(priceRaw) && priceRaw > 0) {
    price = priceRaw
  } else if (typeof priceRaw === "string") {
    const cleaned = priceRaw.replace(",", ".").replace(/[^\d.]/g, "")
    const p = parseFloat(cleaned)
    if (Number.isFinite(p) && p > 0) price = p
  }

  let isCash: boolean | null = null
  const cashRaw = parsed.is_cash_payment
  if (typeof cashRaw === "boolean") {
    isCash = cashRaw
  } else if (typeof cashRaw === "string") {
    const c = cashRaw.trim().toLowerCase()
    if (c === "true" || c === "1" || c === "yes") isCash = true
    else if (c === "false" || c === "0" || c === "no") isCash = false
  }

  return {
    task_mode: mode,
    title: typeof parsed.title === "string" ? parsed.title.trim() : "",
    description: typeof parsed.description === "string" ? parsed.description.trim() : "",
    scheduled_start_local:
      typeof parsed.scheduled_start_local === "string" &&
        parsed.scheduled_start_local.trim().length > 0
        ? parsed.scheduled_start_local.trim()
        : null,
    duration_minutes: duration,
    apartment_hint:
      typeof parsed.apartment_hint === "string" && parsed.apartment_hint.trim()
        ? parsed.apartment_hint.trim()
        : null,
    service_hint:
      typeof parsed.service_hint === "string" && parsed.service_hint.trim()
        ? parsed.service_hint.trim()
        : null,
    client_hint:
      typeof parsed.client_hint === "string" && parsed.client_hint.trim()
        ? parsed.client_hint.trim()
        : null,
    custom_location_hint:
      typeof parsed.custom_location_hint === "string" &&
        parsed.custom_location_hint.trim()
        ? parsed.custom_location_hint.trim()
        : null,
    price,
    is_cash_payment: isCash,
  }
}

/** Fallback bez LLM – celý text do popisu, režim unknown. */
function fallbackParse(rawText: string): LlmParseResult {
  const firstLine = rawText.split("\n").map((l) => l.trim()).find((l) => l.length > 0) ?? rawText
  const title = firstLine.length > 80 ? firstLine.slice(0, 77) + "…" : firstLine
  return {
    task_mode: "unknown",
    title,
    description: rawText.trim(),
    scheduled_start_local: null,
    duration_minutes: DEFAULT_DURATION_MINUTES,
    apartment_hint: null,
    service_hint: null,
    client_hint: null,
    custom_location_hint: null,
    price: null,
    is_cash_payment: null,
  }
}

/** Načte apartmány tenanta a vrátí nejlepší shodu + kandidáty. */
async function resolveApartment(
  userClient: ReturnType<typeof createClient>,
  tenantId: string,
  hint: string | null,
): Promise<{
  apartmentId: string | null
  confidence: number
  candidates: ApartmentCandidate[]
}> {
  if (!hint || !hint.trim()) {
    return { apartmentId: null, confidence: 0, candidates: [] }
  }

  const normalizedHint = normalizeApartmentHint(hint)
  const candidates: ApartmentCandidate[] = []
  const seen = new Set<string>()

  const pushRow = (row: ApartmentRow, scoreOverride?: number) => {
    if (seen.has(row.id)) return
    seen.add(row.id)
    const score = scoreOverride ?? scoreApartmentMatch(hint, row)
    if (score <= 0) return
    candidates.push({
      id: row.id,
      label: row.name?.trim() || row.code || row.id,
      subtitle: [row.code, row.address].filter(Boolean).join(" • ") || null,
      confidence: score,
    })
  }

  // 1) Přesná shoda kódu (case-insensitive)
  const { data: codeRows } = await userClient
    .from("apartments")
    .select("id, name, code, address")
    .eq("tenant_id", tenantId)
    .is("deleted_at", null)
    .ilike("code", normalizedHint || hint.trim())
    .limit(5)

  if (codeRows?.length) {
    for (const row of codeRows as ApartmentRow[]) pushRow(row, 1.0)
  }

  // 2) Přesná shoda názvu
  const { data: nameRows } = await userClient
    .from("apartments")
    .select("id, name, code, address")
    .eq("tenant_id", tenantId)
    .is("deleted_at", null)
    .ilike("name", hint.trim())
    .limit(5)

  if (nameRows?.length) {
    for (const row of nameRows as ApartmentRow[]) pushRow(row, 0.95)
  }

  // 3) FTS doplnění
  const ftsQuery = normalizedHint || hint.trim()
  if (ftsQuery.length >= 1) {
    const { data: ftsRows, error: ftsErr } = await userClient
      .from("apartments")
      .select("id, name, code, address")
      .eq("tenant_id", tenantId)
      .is("deleted_at", null)
      .textSearch("search_vector", ftsQuery, {
        config: "simple",
        type: "websearch",
      })
      .limit(8)

    if (ftsErr) {
      console.error("[parse-task-draft] apartment FTS:", ftsErr.message)
    } else if (ftsRows?.length) {
      for (const row of ftsRows as ApartmentRow[]) {
        pushRow(row, Math.max(scoreApartmentMatch(hint, row), 0.72))
      }
    }
  }

  candidates.sort((a, b) => b.confidence - a.confidence)
  const top = candidates[0]
  if (top && top.confidence >= APARTMENT_CONFIDENCE_THRESHOLD) {
    return {
      apartmentId: top.id,
      confidence: top.confidence,
      candidates: candidates.slice(0, 5),
    }
  }

  return {
    apartmentId: null,
    confidence: top?.confidence ?? 0,
    candidates: candidates.slice(0, 5),
  }
}

type ClientRow = {
  id: string
  name: string
  phone: string | null
  email: string | null
  client_type: string | null
}

type ServiceRow = {
  id: string
  name: string
  service_type: string
  description: string | null
}

const CLIENT_CONFIDENCE_THRESHOLD = 0.85
const SERVICE_CONFIDENCE_THRESHOLD = 0.85

function normalizePersonHint(raw: string): string {
  return raw
    .trim()
    .toLowerCase()
    .normalize("NFD")
    .replace(/\p{M}/gu, "")
    .replace(/\s+/g, " ")
}

/** Odstraní časté české pádové koncovky u křestních jmen („Juru“ → „jur“). */
function clientHintSearchVariants(hint: string): string[] {
  const base = normalizePersonHint(hint)
  if (!base) return []
  const variants = new Set<string>([base])
  const stripped = base.replace(/(ovi|ovy|emu|ech|ami|ama|u|a|e|y|i)$/u, "")
  if (stripped.length >= 3) variants.add(stripped)
  return [...variants]
}

function scoreClientMatch(hint: string, row: ClientRow): number {
  const h = normalizePersonHint(hint)
  if (!h) return 0
  const name = normalizePersonHint(row.name ?? "")
  if (!name) return 0
  if (name === h) return 1.0
  if (name.startsWith(h + " ") || name.startsWith(h)) return 0.92
  const tokens = name.split(" ").filter(Boolean)
  if (tokens.some((t) => t === h)) return 0.9
  if (name.includes(h)) return 0.82
  const phoneDigits = (row.phone ?? "").replace(/\D/g, "")
  const hintDigits = h.replace(/\D/g, "")
  if (hintDigits.length >= 6 && phoneDigits.includes(hintDigits)) return 0.95
  return 0
}

/** Párování klienta (name/phone/FTS) v rámci tenant_id – např. „Jura“ → „Jura Boš“. */
async function resolveClient(
  userClient: ReturnType<typeof createClient>,
  tenantId: string,
  hint: string | null,
): Promise<{
  clientId: string | null
  confidence: number
  candidates: ApartmentCandidate[]
}> {
  if (!hint || !hint.trim()) {
    return { clientId: null, confidence: 0, candidates: [] }
  }

  const normalizedHint = normalizePersonHint(hint)
  const candidates: ApartmentCandidate[] = []
  const seen = new Set<string>()

  const pushRow = (row: ClientRow, scoreOverride?: number) => {
    if (seen.has(row.id)) return
    seen.add(row.id)
    const score = scoreOverride ?? scoreClientMatch(hint, row)
    if (score <= 0) return
    candidates.push({
      id: row.id,
      label: row.name?.trim() || row.id,
      subtitle: [row.phone, row.client_type].filter(Boolean).join(" • ") || null,
      confidence: score,
    })
  }

  const { data: nameRows } = await userClient
    .from("clients")
    .select("id, name, phone, email, client_type")
    .eq("tenant_id", tenantId)
    .is("deleted_at", null)
    .ilike("name", `%${hint.trim().replace(/[%_]/g, "")}%`)
    .limit(12)

  if (nameRows?.length) {
    for (const row of nameRows as ClientRow[]) pushRow(row)
  }

  // Doplňkové hledání podle zkráceného jména (Juru → Jur…)
  for (const variant of clientHintSearchVariants(hint)) {
    if (variant === normalizedHint) continue
    const { data: variantRows } = await userClient
      .from("clients")
      .select("id, name, phone, email, client_type")
      .eq("tenant_id", tenantId)
      .is("deleted_at", null)
      .ilike("name", `%${variant}%`)
      .limit(8)
    if (variantRows?.length) {
      for (const row of variantRows as ClientRow[]) {
        pushRow(row, Math.max(scoreClientMatch(hint, row), 0.86))
      }
    }
  }

  const ftsQuery = normalizedHint || hint.trim()
  if (ftsQuery.length >= 2) {
    const { data: ftsRows, error: ftsErr } = await userClient
      .from("clients")
      .select("id, name, phone, email, client_type")
      .eq("tenant_id", tenantId)
      .is("deleted_at", null)
      .textSearch("search_vector", ftsQuery, {
        config: "simple",
        type: "websearch",
      })
      .limit(8)

    if (ftsErr) {
      console.error("[parse-task-draft] client FTS:", ftsErr.message)
    } else if (ftsRows?.length) {
      for (const row of ftsRows as ClientRow[]) {
        pushRow(row, Math.max(scoreClientMatch(hint, row), 0.72))
      }
    }
  }

  candidates.sort((a, b) => b.confidence - a.confidence)
  const top = candidates[0]
  if (top && top.confidence >= CLIENT_CONFIDENCE_THRESHOLD) {
    return {
      clientId: top.id,
      confidence: top.confidence,
      candidates: candidates.slice(0, 5),
    }
  }

  return {
    clientId: null,
    confidence: top?.confidence ?? 0,
    candidates: candidates.slice(0, 5),
  }
}

function inferServiceTypeFromHint(hint: string): string | null {
  const h = normalizePersonHint(hint)
  if (!h) return null
  if (
    h.includes("transfer") ||
    h.includes("letist") ||
    h.includes("airport") ||
    h.includes("odvoz") ||
    h.includes("aeropuerto") ||
    h.includes("pickup") ||
    h.includes("dropoff")
  ) {
    return "transfer"
  }
  if (h.includes("uklid") || h.includes("clean") || h.includes("limpieza")) {
    return "cleaning"
  }
  if (h.includes("udrzb") || h.includes("mainten") || h.includes("repar")) {
    return "maintenance"
  }
  return null
}

function scoreServiceMatch(hint: string, row: ServiceRow): number {
  const h = normalizePersonHint(hint)
  if (!h) return 0
  const name = normalizePersonHint(row.name ?? "")
  const stype = normalizePersonHint(row.service_type ?? "")
  let score = 0
  if (name && name === h) score = 1.0
  else if (name && name.includes(h)) score = 0.9
  else if (name && h.includes(name) && name.length >= 4) score = 0.84
  else if (stype && (stype === h || h.includes(stype) || stype.includes(h))) {
    score = 0.8
  }

  const inferred = inferServiceTypeFromHint(hint)
  if (inferred) {
    if (stype.includes(inferred) || stype.startsWith(inferred)) {
      score = Math.max(score, 0.88)
    }
    // „Transfer Z letiště“ vs hint „transfer / odvoz na letiště“
    if (inferred === "transfer" && name.includes("transfer")) {
      score = Math.max(score, 0.9)
    }
    if (inferred === "transfer" && (name.includes("letist") || name.includes("airport"))) {
      score = Math.max(score, 0.92)
    }
  }

  return score
}

/** Párování služby z katalogu tenant_services podle service_hint. */
async function resolveService(
  userClient: ReturnType<typeof createClient>,
  tenantId: string,
  hint: string | null,
): Promise<{
  serviceId: string | null
  confidence: number
  candidates: ApartmentCandidate[]
}> {
  if (!hint || !hint.trim()) {
    return { serviceId: null, confidence: 0, candidates: [] }
  }

  const { data: rows, error } = await userClient
    .from("tenant_services")
    .select("id, name, service_type, description")
    .eq("tenant_id", tenantId)
    .eq("is_active", true)
    .is("deleted_at", null)
    .order("order_index", { ascending: true })
    .limit(200)

  if (error) {
    console.error("[parse-task-draft] tenant_services:", error.message)
    return { serviceId: null, confidence: 0, candidates: [] }
  }

  const candidates: ApartmentCandidate[] = []
  for (const row of (rows ?? []) as ServiceRow[]) {
    const score = scoreServiceMatch(hint, row)
    if (score <= 0) continue
    candidates.push({
      id: row.id,
      label: row.name?.trim() || row.service_type || row.id,
      subtitle: row.service_type || null,
      confidence: score,
    })
  }

  candidates.sort((a, b) => b.confidence - a.confidence)
  const top = candidates[0]
  if (top && top.confidence >= SERVICE_CONFIDENCE_THRESHOLD) {
    return {
      serviceId: top.id,
      confidence: top.confidence,
      candidates: candidates.slice(0, 5),
    }
  }

  return {
    serviceId: null,
    confidence: top?.confidence ?? 0,
    candidates: candidates.slice(0, 5),
  }
}

/** Wall-clock lokální čas bez Z/offset – Flutter ho bere jako lokální (ne UTC→toLocal). */
function normalizeWallClockLocalIso(localIso: string): string | null {
  const s = localIso.trim()
  if (!s) return null
  // Odstraní Z i offset (+02:00 / +0200), ponechá jen čísla data a času.
  const noTz = s.replace(/(?:[Zz]|[+-]\d{2}:?\d{2})$/, "").trim()
  const m = noTz.match(
    /^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2}))?/,
  )
  if (!m) return null
  const sec = (m[6] ?? "00").padStart(2, "0")
  return `${m[1]}-${m[2]}-${m[3]}T${m[4]}:${m[5]}:${sec}`
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405)
  }

  try {
    const authHeader = req.headers.get("Authorization")
    if (!authHeader?.startsWith("Bearer ")) {
      console.warn(
        "[parse-task-draft] 401 – Missing Authorization Bearer header" +
          ` (got: ${authHeader ? authHeader.slice(0, 20) + "…" : "null"})`,
      )
      return jsonResponse({ error: "Missing Authorization Bearer" }, 401)
    }

    const jwt = authHeader.slice(7).trim()
    if (!jwt) {
      console.warn("[parse-task-draft] 401 – Bearer token is empty")
      return jsonResponse({ error: "Empty Bearer token" }, 401)
    }

    // PROČ: Jen délka JWT – nikdy nelogujeme celý token (bezpečnost).
    console.info(
      `[parse-task-draft] auth: Bearer present (jwt length=${jwt.length})`,
    )

    const supabaseUrl = requireEnv("SUPABASE_URL")
    const anonKey = requireEnv("SUPABASE_ANON_KEY")

    const userClient = createClient(supabaseUrl, anonKey, {
      auth: { persistSession: false },
      global: { headers: { Authorization: authHeader } },
    })

    const { data: userData, error: userErr } = await userClient.auth.getUser(jwt)
    if (userErr || !userData?.user?.id) {
      const reason = userErr?.message?.trim() || "no user id in getUser response"
      console.warn(
        `[parse-task-draft] 401 – Invalid JWT / getUser failed: ${reason}`,
      )
      return jsonResponse({ error: "Invalid or expired token", detail: reason }, 401)
    }
    const userId = userData.user.id

    const { data: profile, error: profErr } = await userClient
      .from("profiles")
      .select("tenant_id, role")
      .eq("auth_id", userId)
      .maybeSingle()

    if (profErr) {
      console.error("[parse-task-draft] profiles:", profErr.message)
      return jsonResponse({ error: "Profile load failed" }, 500)
    }

    if (!profile) {
      console.warn(
        `[parse-task-draft] 403 – No profile row for auth_id=${userId}`,
      )
      return jsonResponse({ error: "Profile not found" }, 403)
    }

    const tenantId = (profile as { tenant_id?: string | null } | null)?.tenant_id?.trim() ?? ""
    const roleRaw = ((profile as { role?: string } | null)?.role ?? "").trim()
    const role = roleRaw.toLowerCase()

    if (!tenantId) {
      console.warn(
        `[parse-task-draft] 403 – User ${userId} has no tenant_id (role=${roleRaw || "empty"})`,
      )
      return jsonResponse({ error: "Account has no tenant" }, 403)
    }
    if (role !== "admin" && role !== "manager") {
      console.warn(
        `[parse-task-draft] 403 – User role is '${roleRaw || "empty"}', ` +
          `allowed: admin/manager (userId=${userId}, tenantId=${tenantId})`,
      )
      return jsonResponse({
        error: "Admin or manager role required",
        detail: `User role is ${roleRaw || "empty"}, allowed: admin/manager`,
      }, 403)
    }

    console.info(
      `[parse-task-draft] auth OK userId=${userId} role=${role} tenantId=${tenantId}`,
    )

    if (!checkRateLimit(`parse-task-draft:${userId}`, RATE_LIMIT_MAX, RATE_LIMIT_WINDOW_MS)) {
      return jsonResponse({ error: "Rate limit exceeded" }, 429)
    }

    let body: Record<string, unknown>
    try {
      body = await req.json() as Record<string, unknown>
    } catch {
      return jsonResponse({ error: "Invalid JSON body" }, 400)
    }

    const rawText = typeof body.raw_text === "string" ? body.raw_text.trim() : ""
    let imageBase64 =
      typeof body.image_base64 === "string" ? body.image_base64.trim() : ""
    if (imageBase64.startsWith("data:")) {
      const comma = imageBase64.indexOf(",")
      if (comma >= 0) imageBase64 = imageBase64.slice(comma + 1)
    }
    let imageMimeType =
      typeof body.image_mime_type === "string" ? body.image_mime_type.trim().toLowerCase() : ""
    if (!imageMimeType && imageBase64) imageMimeType = "image/jpeg"

    if (!rawText && !imageBase64) {
      return jsonResponse({ error: "raw_text or image_base64 is required" }, 400)
    }
    if (rawText.length > MAX_RAW_TEXT_LENGTH) {
      return jsonResponse({ error: `raw_text max ${MAX_RAW_TEXT_LENGTH} chars` }, 400)
    }
    if (imageBase64.length > MAX_IMAGE_BASE64_LENGTH) {
      return jsonResponse({ error: "image_base64 too large" }, 400)
    }

    const referenceNowUtc =
      typeof body.reference_now_utc === "string" && body.reference_now_utc.trim()
        ? body.reference_now_utc.trim()
        : new Date().toISOString()

    const locale =
      typeof body.locale === "string" && body.locale.trim() ? body.locale.trim() : "cs"

    let tenantTimezone = DEFAULT_TIMEZONE
    if (typeof body.tenant_timezone === "string" && body.tenant_timezone.trim()) {
      tenantTimezone = body.tenant_timezone.trim()
    } else {
      const { data: tenantRow } = await userClient
        .from("tenants")
        .select("timezone")
        .eq("id", tenantId)
        .maybeSingle()
      const tz = (tenantRow as { timezone?: string | null } | null)?.timezone?.trim()
      if (tz) tenantTimezone = tz
    }

    let llmResult: LlmParseResult | null = null
    const apiKey = Deno.env.get("GEMINI_API_KEY")
    if (apiKey) {
      try {
        llmResult = await tryLlmParse({
          apiKey,
          rawText,
          referenceNowUtc,
          tenantTimezone,
          locale,
          imageBase64: imageBase64 || null,
          imageMimeType: imageMimeType || null,
        })
      } catch (e) {
        console.error("[parse-task-draft] Gemini error:", e)
      }
    } else {
      console.warn("[parse-task-draft] GEMINI_API_KEY missing – using fallback parser")
    }

    const parsed = llmResult ?? fallbackParse(
      rawText || (imageBase64 ? "[screenshot]" : ""),
    )

    const warnings: string[] = []
    if (!llmResult) warnings.push("llm_fallback")

    let apartmentId: string | null = null
    let apartmentConfidence = 0
    let apartmentCandidates: ApartmentCandidate[] = []

    if (parsed.apartment_hint) {
      const resolved = await resolveApartment(userClient, tenantId, parsed.apartment_hint)
      apartmentId = resolved.apartmentId
      apartmentConfidence = resolved.confidence
      apartmentCandidates = resolved.candidates
      if (!apartmentId) {
        warnings.push("apartment_unresolved")
      } else if (apartmentConfidence < APARTMENT_CONFIDENCE_THRESHOLD) {
        warnings.push("apartment_low_confidence")
      }
    } else if (parsed.task_mode === "apartment_bound") {
      warnings.push("apartment_hint_missing")
    }

    let clientId: string | null = null
    let clientConfidence = 0
    let clientCandidates: ApartmentCandidate[] = []
    if (parsed.client_hint) {
      const resolved = await resolveClient(userClient, tenantId, parsed.client_hint)
      clientId = resolved.clientId
      clientConfidence = resolved.confidence
      clientCandidates = resolved.candidates
      if (!clientId) {
        warnings.push("client_unresolved")
      } else if (clientConfidence < CLIENT_CONFIDENCE_THRESHOLD) {
        warnings.push("client_low_confidence")
      }
    } else if (parsed.task_mode === "external_service") {
      warnings.push("client_hint_missing")
    }

    let serviceId: string | null = null
    let serviceConfidence = 0
    let serviceCandidates: ApartmentCandidate[] = []
    if (parsed.service_hint) {
      const resolved = await resolveService(userClient, tenantId, parsed.service_hint)
      serviceId = resolved.serviceId
      serviceConfidence = resolved.confidence
      serviceCandidates = resolved.candidates
      if (!serviceId) {
        warnings.push("service_unresolved")
      } else if (serviceConfidence < SERVICE_CONFIDENCE_THRESHOLD) {
        warnings.push("service_low_confidence")
      }
    } else if (parsed.task_mode === "external_service") {
      warnings.push("service_hint_missing")
    }

    let scheduledStartIso: string | null = null
    if (parsed.scheduled_start_local) {
      // PROČ: Neposíláme UTC (toISOString) – Flutter formulář očekává wall-clock 11:15 → 11:15.
      scheduledStartIso = normalizeWallClockLocalIso(parsed.scheduled_start_local)
      if (!scheduledStartIso) warnings.push("datetime_unparsed")
    } else {
      warnings.push("datetime_missing")
    }

    const draft = {
      task_mode: parsed.task_mode,
      title: parsed.title || null,
      description: parsed.description || null,
      scheduled_start_iso: scheduledStartIso,
      duration_minutes: parsed.duration_minutes,
      apartment_id: apartmentId,
      apartment_match_confidence: apartmentConfidence,
      client_id: clientId,
      client_match_confidence: clientConfidence,
      service_id: serviceId,
      service_match_confidence: serviceConfidence,
      custom_location_hint: parsed.custom_location_hint,
      price: parsed.price,
      is_cash_payment: parsed.is_cash_payment,
      raw_source_text: rawText,
    }

    return jsonResponse({
      draft,
      apartment_candidates: apartmentCandidates,
      client_candidates: clientCandidates,
      service_candidates: serviceCandidates,
      warnings,
    })
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err)
    console.error("[parse-task-draft] unhandled:", msg)
    return jsonResponse({ error: msg }, 500)
  }
})
