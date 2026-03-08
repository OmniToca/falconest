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
import { createClient } from "npm:@supabase/supabase-js@2"
import OpenAI from "https://deno.land/x/openai@v4.24.0/mod.ts"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
    if (!supabaseUrl || !serviceRoleKey) {
      return new Response(
        JSON.stringify({ error: "Chybí SUPABASE_URL nebo SUPABASE_SERVICE_ROLE_KEY" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
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

    // INSERT do tasks s Service Role (obejde RLS)
    const supabase = createClient(supabaseUrl, serviceRoleKey)
    const { data, error } = await supabase.from("tasks").insert(payload).select().single()

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
