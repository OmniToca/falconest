// =============================================================================
// FalcoNest – Edge Function export_calendar (read-only .ics podle tajného tokenu)
// -----------------------------------------------------------------------------
// PROČ: Home Assistant a další systémy potřebují HTTP GET bez přihlášení; token
// v URL se nejprve zahashuje (SHA-256) a do Postgres jde jen hash – sladěno s tabulkou
// tenant_calendar_feed_tokens a funkcí get_calendar_feed_data. VEVENT doplňujeme o
// LOCATION (adresa ± souřadnice), GEO (RFC lat;lon), DESCRIPTION (+ odkaz Navigovat → Maps).
// Na konec DESCRIPTION přidáme blok --- / Type / AgencyPrice / TransitPrice (z RPC feed_*).
// =============================================================================

import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { checkRateLimit } from "../_shared/rate_limiter.ts"

/** CORS pro případné testování z prohlížeče (HA samotné CORS nepotřebuje). */
const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

/** Jedna řádka z RPC get_calendar_feed_data (názvy sloupců como z DB). */
type CalendarFeedRow = {
  id: string
  title: string | null
  scheduled_start: string
  due_date: string | null
  /** Adresa bytu nebo custom_location – pro LOCATION v iCal (HA navigace). */
  location_text: string | null
  guest_name: string | null
  apartment_name: string | null
  task_description: string | null
  assignee_display_name: string | null
  /** WGS 84 z tasks.geo_location nebo apartments.geo_location (PostGIS ST_Y / ST_X). */
  geo_latitude: number | string | null
  geo_longitude: number | string | null
  /** Kód typu (tenant_services.service_type / tasks.task_type / zkrácený title) pro HA regex. */
  feed_task_type: string | null
  /** tasks.metadata.amount_to_collect – PostgREST může vrátit string. */
  feed_agency_price: number | string | null
  /** tasks.metadata.transit_amount_to_collect */
  feed_transit_price: number | string | null
}

// -----------------------------------------------------------------------------
// SHA-256 → hexadecimální řetězec (stejný formát, jaký má uložit backend u zápisu tokenu)
// -----------------------------------------------------------------------------
// PROČ: Do Supabase posíláme výhradně hash; surový export_token se v dotazu ani v logu
// neukládáme. Hex je běžná reprezentace digestu a snadno se ukládá do textového sloupce.
async function sha256Hex(plain: string): Promise<string> {
  const enc = new TextEncoder().encode(plain)
  const buf = await crypto.subtle.digest("SHA-256", enc)
  const bytes = new Uint8Array(buf)
  return Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("")
}

/** Max. požadavků na token za minutu (stejné chování jako před extrakcí do _shared). */
const RATE_LIMIT_PER_MINUTE = 20
const RATE_WINDOW_MS = 60_000

// -----------------------------------------------------------------------------
// Escapování hodnot vlastností iCalendar (SUMMARY, LOCATION, DESCRIPTION) dle RFC 5545
// -----------------------------------------------------------------------------
// PROČ: Čárky v adresách (např. „Avenida …, La Mata“) musí být jako \, jinak parser
// hodnotu rozštípne. Stejně středníky, zpětná lomítka a konce řádků – jinak spadne
// import do Home Assistant / Google Kalendáře. Pořadí náhrad: nejdřív \, pak \n, ;, ,.
function escapeIcsPropertyValue(text: string): string {
  const normalized = text.replace(/\r\n/g, "\n").replace(/\r/g, "\n")
  return normalized
    .replace(/\\/g, "\\\\")
    .replace(/\n/g, "\\n")
    .replace(/;/g, "\\;")
    .replace(/,/g, "\\,")
}

// -----------------------------------------------------------------------------
// Formát data/času v UTC do tvaru YYYYMMDDTHHMMSSZ (přípona Z = UTC dle RFC 5545)
// -----------------------------------------------------------------------------
// PROČ: Konzistentní časová zóna vůči timestamptz v Postgresu; odběratel (HA, Google)
// přepočítá na lokální zeď. Nepoužíváme VALUE=DATE u běžných úkolů – viz buildVeventLines.
function formatIcsDateTimeUtc(d: Date): string {
  const y = d.getUTCFullYear()
  const m = String(d.getUTCMonth() + 1).padStart(2, "0")
  const day = String(d.getUTCDate()).padStart(2, "0")
  const h = String(d.getUTCHours()).padStart(2, "0")
  const min = String(d.getUTCMinutes()).padStart(2, "0")
  const s = String(d.getUTCSeconds()).padStart(2, "0")
  return `${y}${m}${day}T${h}${min}${s}Z`
}

// -----------------------------------------------------------------------------
// Výchozí délka VEVENT v milisekundách, když v DB chybí platný konec (due_date)
// -----------------------------------------------------------------------------
// PROČ: RFC 5545 vyžaduje DTEND > DTSTART u časově určené události. Dříve jsme bez
// due_date používali DTSTART;VALUE=DATE – v UTC kalendářní den pak u nočních lokálních
// časů posouval odběratele o den a ztratili přesný čas. Jedna hodina v UTC je konzervativní
// výchozí blok pro dispečerské úkoly; klient si zobrazí správný okamžik začátku a rozumný konec.
const DEFAULT_EVENT_DURATION_MS = 60 * 60 * 1000

/** Pokus o parsování due_date z DB (text může být ISO nebo jen datum). */
function tryParseEndDate(raw: string | null | undefined): Date | null {
  if (raw == null || typeof raw !== "string") return null
  const t = raw.trim()
  if (!t) return null
  const parsed = Date.parse(t)
  if (Number.isNaN(parsed)) return null
  return new Date(parsed)
}

/** Bezpečná konverze hodnoty z PostgREST na konečné číslo (JSON někdy vrací string). */
function toFiniteNumber(x: number | string | null | undefined): number | null {
  if (x == null) return null
  if (typeof x === "string") {
    const t = x.trim().toLowerCase()
    if (t === "" || t === "null" || t === "nan" || t === "undefined") return null
  }
  const n = typeof x === "number" ? x : Number(x)
  return Number.isFinite(n) ? n : null
}

function isValidWgs84Pair(lat: number, lon: number): boolean {
  return lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180
}

/**
 * Formát čísla pro řádek GEO:lat;lon – desetinná tečka, bez zbytečných nul.
 * PROČ: iCal a Home Assistant očekávají stabilní text, ne exponenciální zápis.
 */
function formatIcsGeoComponent(n: number): string {
  if (!Number.isFinite(n)) return "0"
  const s = n.toFixed(8).replace(/\.?0+$/, "")
  if (s === "" || s === "-" || s.toLowerCase() === "nan") return "0"
  return s
}

/** Par souřadnic z řádku RPC; null pokud chybí nebo jsou mimo WGS 84. */
function extractGeoPair(row: CalendarFeedRow): { lat: number; lon: number } | null {
  const lat = toFiniteNumber(row.geo_latitude)
  const lon = toFiniteNumber(row.geo_longitude)
  if (lat == null || lon == null) return null
  if (!isValidWgs84Pair(lat, lon)) return null
  return { lat, lon }
}

/**
 * Sestaví text DESCRIPTION: jen neprázdné řádky (Host, Byt, Pracovník, Poznámka).
 * PROČ: Automatizace čtou strukturovaný kontext; prázdné sekce šum v HA notifikacích.
 */
function buildDescriptionBlock(row: CalendarFeedRow): string | null {
  const parts: string[] = []
  const host = row.guest_name?.trim()
  if (host) parts.push(`Host: ${host}`)
  const apt = row.apartment_name?.trim()
  if (apt) parts.push(`Byt: ${apt}`)
  const worker = row.assignee_display_name?.trim()
  if (worker) parts.push(`Pracovník: ${worker}`)
  const note = row.task_description?.trim()
  if (note) parts.push(`Poznámka k úkolu: ${note}`)
  if (parts.length === 0) return null
  return parts.join("\n")
}

/**
 * Jedna řádka pro klíče Type / AgencyPrice / TransitPrice – bez zalomení, aby regex v HA byl spolehlivý.
 */
function sanitizeHaTypeLine(raw: string | null | undefined): string {
  const t = (raw ?? "")
    .replace(/\r\n/g, " ")
    .replace(/\r/g, " ")
    .replace(/\n/g, " ")
    .trim()
  return t.length > 0 ? t : "other"
}

/**
 * Parsování peněžní hodnoty z RPC (numeric může přijít jako string).
 * PROČ: Chybějící nebo nečíselná hodnota → 0.00 v exportu dle zadání zákazníka.
 */
function parseFeedMoney(value: number | string | null | undefined): number {
  if (value == null) return 0
  if (typeof value === "number") return Number.isFinite(value) ? value : 0
  const t = String(value).trim().replace(",", ".")
  if (t === "") return 0
  const n = Number(t)
  return Number.isFinite(n) ? n : 0
}

function formatHaMoneyFixed2(n: number): string {
  return n.toFixed(2)
}

/**
 * Blok na konec DESCRIPTION: oddělovač + strojově čitelné řádky pro Home Assistant.
 * PROČ: iCal nemá vlastní pole pro ceny; escape proběhne až na celém DESCRIPTION včetně \\n.
 */
function buildHomeAssistantStructuredBlock(row: CalendarFeedRow): string {
  const typ = sanitizeHaTypeLine(row.feed_task_type ?? undefined)
  const agency = formatHaMoneyFixed2(parseFeedMoney(row.feed_agency_price))
  const transit = formatHaMoneyFixed2(parseFeedMoney(row.feed_transit_price))
  return `---\nType: ${typ}\nAgencyPrice: ${agency}\nTransitPrice: ${transit}`
}

/**
 * Sestaví řádky VEVENT pro jeden úkol.
 *
 * PROČ: Vždy časové DTSTART/DTEND v UTC (...Z). Platné due_date z DB (konec > začátek)
 * použijeme jako DTEND; jinak syntetický konec = začátek + 1 hodina v UTC, aby odpadly
 * chybné celodenní VALUE=DATE události a posuny kalendářního dne u časových pásem.
 */
function buildVeventLines(row: CalendarFeedRow): string[] {
  const uid = `${row.id}@falco-nest.calendar`
  const summaryRaw = row.title?.trim() ? row.title.trim() : "Úkol"
  const summary = escapeIcsPropertyValue(summaryRaw)

  const startMs = Date.parse(row.scheduled_start)
  if (Number.isNaN(startMs)) {
    return []
  }
  const start = new Date(startMs)
  const endFromDb = tryParseEndDate(row.due_date)

  const lines: string[] = ["BEGIN:VEVENT", `UID:${uid}`, `SUMMARY:${summary}`]

  // DTSTART vždy přesný okamžik v UTC (odpovídá timestamptz scheduled_start v DB).
  lines.push(`DTSTART:${formatIcsDateTimeUtc(start)}`)

  let endUtc: Date
  if (endFromDb && !Number.isNaN(endFromDb.getTime()) && endFromDb.getTime() > start.getTime()) {
    endUtc = endFromDb
  } else {
    // PROČ: Úkol bez platného konce v DB nesmí spadnout do celodenního VALUE=DATE –
    // při odvození data jen z UTC by se v externích kalendářích zobrazil špatný „den na zdi“
    // a ztratil by se plánovaný čas. Proto přičítáme pevnou délku v UTC (1 hodina); odběratel
    // zobrazí správný začátek a konec v lokálním čase bez falešného all-day na předchozí den.
    endUtc = new Date(start.getTime() + DEFAULT_EVENT_DURATION_MS)
  }
  lines.push(`DTEND:${formatIcsDateTimeUtc(endUtc)}`)

  const geo = extractGeoPair(row)
  const loc = row.location_text?.trim()
  let locationCombined: string | null = null
  if (loc && geo) {
    const coordsPlain = `${formatIcsGeoComponent(geo.lat)}, ${formatIcsGeoComponent(geo.lon)}`
    locationCombined = `${loc} | ${coordsPlain}`
  } else if (loc) {
    locationCombined = loc
  } else if (geo) {
    locationCombined = `${formatIcsGeoComponent(geo.lat)}, ${formatIcsGeoComponent(geo.lon)}`
  }
  if (locationCombined) {
    lines.push(`LOCATION:${escapeIcsPropertyValue(locationCombined)}`)
  }
  if (geo) {
    lines.push(`GEO:${formatIcsGeoComponent(geo.lat)};${formatIcsGeoComponent(geo.lon)}`)
  }

  let descBody = buildDescriptionBlock(row)
  if (geo) {
    const qLat = formatIcsGeoComponent(geo.lat)
    const qLon = formatIcsGeoComponent(geo.lon)
    const navLine = `Navigovat: https://maps.google.com/?q=${qLat},${qLon}`
    descBody = descBody ? `${descBody}\n${navLine}` : navLine
  }
  const haBlock = buildHomeAssistantStructuredBlock(row)
  descBody = descBody ? `${descBody}\n${haBlock}` : haBlock
  lines.push(`DESCRIPTION:${escapeIcsPropertyValue(descBody)}`)

  lines.push(`DTSTAMP:${formatIcsDateTimeUtc(new Date())}`)
  lines.push("END:VEVENT")
  return lines
}

/**
 * Spojí řádky iCal s CRLF a uzavře kalendář.
 */
function buildIcsCalendar(veventBlocks: string[][]): string {
  const body: string[] = [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//FalcoNest//Calendar Export//CS",
    "CALSCALE:GREGORIAN",
    "METHOD:PUBLISH",
  ]
  for (const ev of veventBlocks) {
    body.push(...ev)
  }
  body.push("END:VCALENDAR")
  return body.join("\r\n") + "\r\n"
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  if (req.method !== "GET") {
    return new Response("Povolena je pouze metoda GET.", {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "text/plain; charset=utf-8" },
    })
  }

  const url = new URL(req.url)
  const exportToken = url.searchParams.get("export_token")?.trim() ?? ""

  if (!exportToken) {
    return new Response("Chybí query parametr export_token.", {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "text/plain; charset=utf-8" },
    })
  }

  const tokenHash = await sha256Hex(exportToken)

  if (!checkRateLimit(tokenHash, RATE_LIMIT_PER_MINUTE, RATE_WINDOW_MS)) {
    return new Response(
      "Příliš mnoho požadavků na tento odkaz. Zkuste to znovu za minutu.",
      {
        status: 429,
        headers: {
          ...corsHeaders,
          "Content-Type": "text/plain; charset=utf-8",
          "Retry-After": "60",
        },
      },
    )
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? ""
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""

  if (!supabaseUrl || !serviceKey) {
    console.error("export_calendar: chybí SUPABASE_URL nebo SUPABASE_SERVICE_ROLE_KEY")
    return new Response("Konfigurace serveru je neúplná.", {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "text/plain; charset=utf-8" },
    })
  }

  // PROČ: Pouze service role smí volat get_calendar_feed_data (GRANT EXECUTE); anon klíč by selhal.
  const supabase = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })

  const { data, error } = await supabase.rpc("get_calendar_feed_data", {
    p_token_hash: tokenHash,
  })

  if (error) {
    console.error("export_calendar RPC:", error.message)
    return new Response("Chyba při čtení kalendáře.", {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "text/plain; charset=utf-8" },
    })
  }

  const rows = (data ?? []) as CalendarFeedRow[]

  // Poznámka: DB vrací 0 řádků i při neplatném tokenu i při platném tokenu bez úkolů – dle zadání vracíme 401.
  if (rows.length === 0) {
    return new Response("Neplatný nebo zrušený token, nebo žádná data k exportu.", {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "text/plain; charset=utf-8" },
    })
  }

  const blocks: string[][] = []
  for (const row of rows) {
    const bl = buildVeventLines(row)
    if (bl.length > 0) blocks.push(bl)
  }

  if (blocks.length === 0) {
    return new Response("Neplatný nebo zrušený token, nebo žádná data k exportu.", {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "text/plain; charset=utf-8" },
    })
  }

  const ics = buildIcsCalendar(blocks)

  return new Response(ics, {
    status: 200,
    headers: {
      ...corsHeaders,
      "Content-Type": "text/calendar; charset=utf-8",
      "Cache-Control": "no-cache",
    },
  })
})
