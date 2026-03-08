// Supabase Edge Function – Proxy pro stahování a parsování iCal (CORS workaround)
// Webová Flutter aplikace nemůže přímo stahovat .ics z Airbnb/Booking kvůli CORS.
// Funkce přijme POST s ical_url, stáhne obsah, vyparsuje VEVENT události a vrátí JSON.
//
// Použití: POST /ical-fetch { "ical_url": "https://..." }
// Odpověď: { "events": [ { "uid", "summary", "dtstart", "dtend" } ], "error": null }
import "jsr:@supabase/functions-js/edge-runtime.d.ts"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

interface IcalEvent {
  uid: string
  summary: string
  dtstart: string
  dtend: string
}

/**
 * Vyparsuje hodnotu vlastnosti z iCal bloku.
 * Zohledňuje line folding (pokračování řádku s úvodní mezerou/tabem).
 * Formát: KEY:value nebo KEY;PARAMS:value
 */
function getPropertyValue(block: string, key: string): string | null {
  const re = new RegExp(
    `^${key}(?:;[^:]*)?:([^\\r\\n]*(?:\\r?\\n[ \\t][^\\r\\n]*)*)`,
    "im"
  )
  const match = block.match(re)
  if (!match) return null
  const value = match[1].replace(/\r?\n[ \t]/g, "").trim()
  return value || null
}

/**
 * Převede iCal datum na ISO 8601 string.
 * Formáty: 20260315T140000Z, 20260315T140000, 20260315
 */
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

/**
 * Z iCal textu vyparsuje VEVENT bloky a vrátí pole událostí.
 */
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

    if (dtstartRaw) {
      dtstart = icalDateToIso(dtstartRaw)
    }

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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  const jsonHeaders = { ...corsHeaders, "Content-Type": "application/json" }

  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Pouze metoda POST je podporována", events: [] }),
      { status: 405, headers: jsonHeaders }
    )
  }

  try {
    let body: { ical_url?: string }
    try {
      body = await req.json()
    } catch {
      return new Response(
        JSON.stringify({ error: "Neplatné JSON tělo požadavku", events: [] }),
        { status: 400, headers: jsonHeaders }
      )
    }

    const icalUrl = body?.ical_url
    if (!icalUrl || typeof icalUrl !== "string") {
      return new Response(
        JSON.stringify({ error: "Chybí parametr ical_url v těle požadavku", events: [] }),
        { status: 400, headers: jsonHeaders }
      )
    }

    const trimmedUrl = icalUrl.trim()
    if (!trimmedUrl.startsWith("http://") && !trimmedUrl.startsWith("https://")) {
      return new Response(
        JSON.stringify({ error: "ical_url musí začínat na http:// nebo https://", events: [] }),
        { status: 400, headers: jsonHeaders }
      )
    }

    const fetchRes = await fetch(trimmedUrl, {
      headers: {
        "User-Agent": "FalcoNest-iCal-Fetch/1.0",
        "Accept": "text/calendar, text/plain, */*",
      },
    })

    if (!fetchRes.ok) {
      return new Response(
        JSON.stringify({
          error: `Stažení iCal selhalo: ${fetchRes.status} ${fetchRes.statusText}`,
          events: [],
        }),
        { status: 502, headers: jsonHeaders }
      )
    }

    const icalText = await fetchRes.text()
    if (!icalText || icalText.trim().length === 0) {
      return new Response(
        JSON.stringify({ error: "iCal soubor je prázdný", events: [] }),
        { status: 502, headers: jsonHeaders }
      )
    }

    const events = parseIcalEvents(icalText)

    return new Response(
      JSON.stringify({ events, error: null }),
      { status: 200, headers: jsonHeaders }
    )
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err)
    console.error("ical-fetch error:", msg)
    return new Response(
      JSON.stringify({ error: msg, events: [] }),
      { status: 500, headers: jsonHeaders }
    )
  }
})
