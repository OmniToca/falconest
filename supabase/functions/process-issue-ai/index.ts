// Supabase Edge Function – AI zpracování hlášení závad (Voice-to-Task)
//
// PROČ: Pracovník nahlásí problém v libovolném jazyce (např. česky). Funkce použije
// OpenAI k překladu do španělštiny a vytvoření profesionálního nadpisu. KRITICKÉ:
// Při výpadku OpenAI (API klíč, rate limit, síť) se úkol NESMÍ ztratit – fallback
// uloží surový text s obecným nadpisem.
//
// Volání: POST s JSON payloadem úkolu (tenant_id, apartment_id, description, …).
// Odpověď: 200 + vložený úkol; při chybě DB 5xx (mutace zůstane ve frontě).
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import OpenAI from "https://deno.land/x/openai@v4.24.0/mod.ts"
import {
  edgeCorsHeaders as corsHeaders,
  requireUserProfile,
} from "../_shared/edge_auth.ts"

/** Fallback nadpis při výpadku AI – dvojjazyčný. */
const FALLBACK_TITLE = "Nové hlasové hlášení / Nuevo reporte"

/** Volitelně vybere JSON z odpovědi (odstraní markdown bloky). */
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

/** Pokusí se získat AI nadpis a překlad popisu. Při chybě vrací null. */
async function tryAiEnrichment(
  apiKey: string,
  rawDescription: string,
): Promise<{ title: string; translated_description: string } | null> {
  const openai = new OpenAI({ apiKey })
  const prompt = `Translate the issue description to Spanish. Create a short professional title in Spanish (max 5 words). Return JSON with "title" and "translated_description" only. No other keys. Example: {"title":"Fuga en el baño","translated_description":"Hay una fuga de agua en el baño"}

Issue description:
${rawDescription}`

  const completion = await openai.chat.completions.create({
    model: "gpt-4o-mini",
    messages: [{ role: "user", content: prompt }],
    stream: false,
  })

  const content = completion.choices[0]?.message?.content?.trim()
  if (!content) return null

  const parsed = extractJson(content)
  if (!parsed || typeof parsed.title !== "string" || typeof parsed.translated_description !== "string") {
    return null
  }

  return {
    title: parsed.title,
    translated_description: parsed.translated_description,
  }
}

/** Výchozí blok v kalendáři, když start == konec (issue toky). Shodně s Dart [kDefaultTaskDurationMinutes]. */
const DEFAULT_DURATION_MINUTES = 60

function parseIsoUtc(v: unknown): Date | null {
  if (v == null) return null
  if (typeof v !== "string") return null
  const d = new Date(v)
  return Number.isNaN(d.getTime()) ? null : d
}

/** Parsuje odhad trvání z popisu – zrcadlí [parseDurationMinutesFromDescription] v Dartu. */
function parseDurationMinutesFromDescription(description: string | undefined): number {
  if (!description || !description.trim()) return 60
  const s = description.trim()
  let minutes = 0
  const hourReg = /(\d+)\s*(?:hod|h|hrs|horas|hour|hours)/i
  const minReg = /(\d+)\s*(?:min|m|mins|minutos|minute|minutes)/i
  const hourMatch = s.match(hourReg)
  if (hourMatch) {
    const h = parseInt(hourMatch[1] ?? "0", 10) || 0
    minutes += h * 60
  }
  const minMatch = s.match(minReg)
  if (minMatch) {
    minutes += parseInt(minMatch[1] ?? "0", 10) || 0
  }
  return minutes > 0 ? minutes : 60
}

function readEstimatedFromMetadata(meta: Record<string, unknown>): number | null {
  const raw = meta["estimated_minutes"] ?? meta["estimate_minutes"]
  if (raw == null) return null
  if (typeof raw === "number" && raw > 0) return Math.round(raw)
  if (typeof raw === "string") {
    const p = parseInt(raw.trim(), 10)
    return p > 0 ? p : null
  }
  return null
}

/**
 * Sanitizace INSERT payloadu pro `tasks` před zápisem – stejná pravidla jako Dart [sanitizeTaskInsertPayload].
 * PROČ: Edge Function obchází aplikační repository; musí doplnit interval a estimated_minutes konzistentně.
 *
 * KRITICKÉ – merge `metadata`: rozšířením `{ ...existing }` zachováme všechna existující pole
 * (finance, procesní příznaky); přepisujeme jen logiku kolem `estimated_minutes` a časů.
 */
function sanitizeTaskInsertPayload(raw: Record<string, unknown>): Record<string, unknown> {
  const out = { ...raw }
  if (out["metadata"] != null && typeof out["metadata"] !== "object") {
    out["metadata"] = {}
  }
  // Bezpečný merge: kopie všech klíčů z metadata, pak jen doplnění estimated_minutes.
  const meta = { ...((out["metadata"] as Record<string, unknown>) ?? {}) }

  let sched = parseIsoUtc(out["scheduled_start"])
  let due = parseIsoUtc(out["due_date"])
  const desc = typeof out["description"] === "string" ? out["description"] : String(out["description"] ?? "")

  let est = readEstimatedFromMetadata(meta)

  if (sched != null && due != null) {
    const diffMin = Math.floor((due.getTime() - sched.getTime()) / 60000)
    if (diffMin > 0) {
      if (est == null || est <= 0) {
        est = diffMin
      }
      meta["estimated_minutes"] = est
    } else {
      est = DEFAULT_DURATION_MINUTES
      due = new Date(sched.getTime() + est * 60 * 1000)
      meta["estimated_minutes"] = est
    }
  } else if (sched != null && due == null) {
    if (est == null || est <= 0) {
      est = parseDurationMinutesFromDescription(desc)
      if (est <= 0) est = DEFAULT_DURATION_MINUTES
    }
    due = new Date(sched.getTime() + est * 60 * 1000)
    meta["estimated_minutes"] = est
  } else if (sched == null && due != null) {
    if (est == null || est <= 0) {
      est = parseDurationMinutesFromDescription(desc)
      if (est <= 0) est = DEFAULT_DURATION_MINUTES
    }
    sched = new Date(due.getTime() - est * 60 * 1000)
    meta["estimated_minutes"] = est
  }

  out["scheduled_start"] = sched != null ? sched.toISOString() : out["scheduled_start"]
  out["due_date"] = due != null ? due.toISOString() : out["due_date"]
  out["metadata"] = meta
  return out
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    // P0 bezpečnost: vyžadovat uživatelský JWT – nikdy service_role + důvěra body.tenant_id.
    const auth = await requireUserProfile(req)
    if (!auth.ok) return auth.response

    const { client, profile } = auth
    if (!profile.tenantId) {
      return new Response(
        JSON.stringify({ error: "Uživatel nemá přiřazený tenant_id" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      )
    }

    let payload: Record<string, unknown>
    try {
      payload = await req.json()
    } catch {
      return new Response(
        JSON.stringify({ error: "Neplatný JSON v těle požadavku" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      )
    }

    // Vynutit tenant a created_by z autentizovaného profilu (body nelze zneužít).
    payload.tenant_id = profile.tenantId
    if (payload.created_by == null || String(payload.created_by).trim() === "") {
      payload.created_by = profile.id
    }

    const description = typeof payload.description === "string" ? payload.description : String(payload.description ?? "")

    // TRY: AI překlad a nadpis
    const apiKey = Deno.env.get("OPENAI_API_KEY")
    if (apiKey) {
      try {
        const enriched = await tryAiEnrichment(apiKey, description)
        if (enriched) {
          payload.title = enriched.title
          payload.description = enriched.translated_description
        }
      } catch (e) {
        // CATCH (FALLBACK): OpenAI selhal – loguj, ale NEPŘERUŠUJ
        console.error("process-issue-ai OpenAI error:", e)
      }
    }

    // Fallback: pokud AI nenastavila title/description, použij surový text
    if (typeof payload.title !== "string" || payload.title.length === 0) {
      payload.title = FALLBACK_TITLE
    }
    if (typeof payload.description !== "string") {
      payload.description = description
    }

    // INSERT přes uživatelský klient – RLS na tasks musí projít (worker/owner vlastního tenanta).
    const sanitized = sanitizeTaskInsertPayload(payload as Record<string, unknown>)
    const { data, error } = await client.from("tasks").insert(sanitized).select().single()

    if (error) {
      console.error("process-issue-ai tasks insert error:", error)
      return new Response(
        JSON.stringify({ error: error.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      )
    }

    return new Response(
      JSON.stringify({ task: data }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err)
    console.error("process-issue-ai unhandled error:", msg)
    return new Response(
      JSON.stringify({ error: msg }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  }
})
