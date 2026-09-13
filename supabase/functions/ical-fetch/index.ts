// Supabase Edge Function – Proxy pro stahování a parsování iCal (CORS workaround)
//
// P0 bezpečnost: vyžaduje JWT admin/manager (nebo super_admin); anti-SSRF allowlist hostů
// a blokace privátních IP / metadata adres.
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import {
  edgeCorsHeaders as corsHeaders,
  isSuperAdminRole,
  isTenantAdminOrManager,
  requireUserProfile,
} from "../_shared/edge_auth.ts"

interface IcalEvent {
  uid: string
  summary: string
  dtstart: string
  dtend: string
}

/** Hostitelé, ze kterých smíme stahovat iCal (SSRF allowlist). */
const ALLOWED_ICAL_HOST_SUFFIXES = [
  "airbnb.com",
  "airbnb.cz",
  "airbnb.es",
  "booking.com",
  "icalendar.com",
  "calendar.google.com",
  "outlook.office365.com",
  "outlook.live.com",
  "guesty.com",
  "hostaway.com",
  "lodgify.com",
  "smoobu.com",
  "beds24.com",
  "vrbo.com",
  "homeaway.com",
]

function getPropertyValue(block: string, key: string): string | null {
  const re = new RegExp(
    `^${key}(?:;[^:]*)?:([^\\r\\n]*(?:\\r?\\n[ \\t][^\\r\\n]*)*)`,
    "im",
  )
  const match = block.match(re)
  if (!match) return null
  const value = match[1].replace(/\r?\n[ \t]/g, "").trim()
  return value || null
}

function icalDateToIso(raw: string): string {
  if (!raw || typeof raw !== "string") return ""
  const s = raw.trim().replace(/\s/g, "")
  if (s.length < 8) return ""

  const year = parseInt(s.slice(0, 4), 10)
  const month = parseInt(s.slice(4, 6), 10) - 1
  const day = parseInt(s.slice(6, 8), 10)

  if (s.length >= 15 && (s[8] === "T" || s[8] === "t")) {
    const hour = parseInt(s.slice(9, 11), 10)
    const min = parseInt(s.slice(11, 13), 10)
    const sec = s.length >= 15 ? parseInt(s.slice(13, 15), 10) : 0
    const isUtc = s.endsWith("Z") || s.endsWith("z")
    if (isUtc) {
      return new Date(Date.UTC(year, month, day, hour, min, sec)).toISOString()
    }
    return new Date(year, month, day, hour, min, sec).toISOString()
  }

  return new Date(Date.UTC(year, month, day, 0, 0, 0)).toISOString()
}

function parseIcalEvents(icalText: string): IcalEvent[] {
  const events: IcalEvent[] = []
  const veventRegex = /BEGIN:VEVENT[\s\S]*?END:VEVENT/gi
  const blocks = icalText.match(veventRegex) ?? []

  for (const block of blocks) {
    const uid = getPropertyValue(block, "UID")
    const summary = getPropertyValue(block, "SUMMARY") ?? ""
    const dtstartRaw = getPropertyValue(block, "DTSTART")
    const dtendRaw = getPropertyValue(block, "DTEND")

    if (!uid) continue

    let dtstart = ""
    let dtend = ""

    if (dtstartRaw) dtstart = icalDateToIso(dtstartRaw)
    if (dtendRaw) {
      dtend = icalDateToIso(dtendRaw)
    } else if (dtstart) {
      const d = new Date(dtstart)
      d.setDate(d.getDate() + 1)
      dtend = d.toISOString()
    }

    events.push({
      uid: uid.trim(),
      summary: summary.trim(),
      dtstart,
      dtend,
    })
  }

  return events
}

/** True, pokud hostname patří na allowlist (včetně subdomén). */
function isAllowedIcalHost(hostname: string): boolean {
  const host = hostname.toLowerCase()
  return ALLOWED_ICAL_HOST_SUFFIXES.some(
    (suffix) => host === suffix || host.endsWith(`.${suffix}`),
  )
}

/** Blokace zjevných privátních / metadata cílů (anti-SSRF). */
function isBlockedHostnameOrIp(hostname: string): boolean {
  const h = hostname.toLowerCase()
  if (h === "localhost" || h.endsWith(".local") || h.endsWith(".internal")) {
    return true
  }
  // IPv4 literal
  const m = h.match(/^(\d+)\.(\d+)\.(\d+)\.(\d+)$/)
  if (m) {
    const a = Number(m[1])
    const b = Number(m[2])
    if (a === 10) return true
    if (a === 127) return true
    if (a === 0) return true
    if (a === 169 && b === 254) return true
    if (a === 172 && b >= 16 && b <= 31) return true
    if (a === 192 && b === 168) return true
  }
  // IPv6 / metadata
  if (h.includes(":") || h === "metadata.google.internal") return true
  return false
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  const jsonHeaders = { ...corsHeaders, "Content-Type": "application/json" }

  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Pouze metoda POST je podporována", events: [] }),
      { status: 405, headers: jsonHeaders },
    )
  }

  try {
    const auth = await requireUserProfile(req)
    if (!auth.ok) return auth.response

    if (
      !isSuperAdminRole(auth.profile.role) &&
      !isTenantAdminOrManager(auth.profile.role)
    ) {
      return new Response(
        JSON.stringify({ error: "Pouze admin/manager může stahovat iCal", events: [] }),
        { status: 403, headers: jsonHeaders },
      )
    }

    let body: { ical_url?: string }
    try {
      body = await req.json()
    } catch {
      return new Response(
        JSON.stringify({ error: "Neplatné JSON tělo požadavku", events: [] }),
        { status: 400, headers: jsonHeaders },
      )
    }

    const icalUrl = body?.ical_url
    if (!icalUrl || typeof icalUrl !== "string") {
      return new Response(
        JSON.stringify({ error: "Chybí parametr ical_url v těle požadavku", events: [] }),
        { status: 400, headers: jsonHeaders },
      )
    }

    let parsed: URL
    try {
      parsed = new URL(icalUrl.trim())
    } catch {
      return new Response(
        JSON.stringify({ error: "Neplatná URL", events: [] }),
        { status: 400, headers: jsonHeaders },
      )
    }

    if (parsed.protocol !== "https:" && parsed.protocol !== "http:") {
      return new Response(
        JSON.stringify({ error: "ical_url musí být http(s)", events: [] }),
        { status: 400, headers: jsonHeaders },
      )
    }

    // Preferovat HTTPS; HTTP jen pro legacy feedy na allowlistu.
    if (isBlockedHostnameOrIp(parsed.hostname) || !isAllowedIcalHost(parsed.hostname)) {
      return new Response(
        JSON.stringify({
          error: "Hostitel iCal není na allowlistu (anti-SSRF)",
          events: [],
        }),
        { status: 403, headers: jsonHeaders },
      )
    }

    const controller = new AbortController()
    const timeout = setTimeout(() => controller.abort(), 15000)

    let fetchRes: Response
    try {
      fetchRes = await fetch(parsed.toString(), {
        headers: {
          "User-Agent": "FalcoNest-iCal-Fetch/1.0",
          "Accept": "text/calendar, text/plain, */*",
        },
        redirect: "error",
        signal: controller.signal,
      })
    } finally {
      clearTimeout(timeout)
    }

    if (!fetchRes.ok) {
      return new Response(
        JSON.stringify({
          error: `Stažení iCal selhalo: ${fetchRes.status} ${fetchRes.statusText}`,
          events: [],
        }),
        { status: 502, headers: jsonHeaders },
      )
    }

    const icalText = await fetchRes.text()
    // Limit velikosti odpovědi (~2 MB) – ochrana proti abuse egress.
    if (icalText.length > 2_000_000) {
      return new Response(
        JSON.stringify({ error: "iCal soubor je příliš velký", events: [] }),
        { status: 413, headers: jsonHeaders },
      )
    }
    if (!icalText || icalText.trim().length === 0) {
      return new Response(
        JSON.stringify({ error: "iCal soubor je prázdný", events: [] }),
        { status: 502, headers: jsonHeaders },
      )
    }

    const events = parseIcalEvents(icalText)

    return new Response(
      JSON.stringify({ events, error: null }),
      { status: 200, headers: jsonHeaders },
    )
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err)
    console.error("ical-fetch error:", msg)
    return new Response(
      JSON.stringify({ error: msg, events: [] }),
      { status: 500, headers: jsonHeaders },
    )
  }
})
