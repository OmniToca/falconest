// =============================================================================
// FalcoNest – Gemini REST klient s dynamickým výběrem modelu (Edge Functions)
// -----------------------------------------------------------------------------
// PROČ: Názvy modelů Google se často mění – nehardcodujeme konkrétní verzi,
// ale přes List Models API vybereme nejvhodnější model podporující generateContent
// a structured JSON (responseSchema).
// =============================================================================

const GEMINI_API_BASE = "https://generativelanguage.googleapis.com/v1beta"

/** Cache vybraného modelu v rámci jedné instance Edge Function (best effort). */
let cachedGenerateContentModel: string | null = null

export type GeminiModelInfo = {
  name: string
  supportedGenerationMethods: string[]
  displayName?: string
}

/** JSON schema pro parsování úkolu – stejný kontrakt jako MVP structured output. */
export const TASK_PARSE_RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    task_mode: {
      type: "STRING",
      enum: ["apartment_bound", "external_service", "unknown"],
    },
    title: { type: "STRING" },
    description: { type: "STRING" },
    scheduled_start_local: { type: "STRING" },
    duration_minutes: { type: "INTEGER" },
    apartment_hint: { type: "STRING" },
    service_hint: { type: "STRING" },
    client_hint: { type: "STRING" },
    custom_location_hint: { type: "STRING" },
    price: { type: "NUMBER" },
    is_cash_payment: { type: "BOOLEAN" },
  },
  required: ["task_mode", "title", "description", "duration_minutes"],
} as const

/**
 * Načte seznam modelů z Gemini API.
 * PROČ: Jediný spolehlivý zdroj pravdy pro aktuálně dostupné názvy modelů.
 */
export async function listGeminiModels(apiKey: string): Promise<GeminiModelInfo[]> {
  const url = `${GEMINI_API_BASE}/models?key=${encodeURIComponent(apiKey)}`
  const res = await fetch(url)
  if (!res.ok) {
    const errText = await res.text()
    throw new Error(`Gemini list models failed (${res.status}): ${errText.slice(0, 300)}`)
  }
  const data = await res.json() as { models?: Array<Record<string, unknown>> }
  const raw = data.models ?? []
  return raw
    .map((m) => {
      const name = typeof m.name === "string" ? m.name : ""
      const methods = Array.isArray(m.supportedGenerationMethods)
        ? m.supportedGenerationMethods.filter((x): x is string => typeof x === "string")
        : []
      const displayName = typeof m.displayName === "string" ? m.displayName : undefined
      return { name, supportedGenerationMethods: methods, displayName }
    })
    .filter((m) => m.name.length > 0)
}

/**
 * Vypočte skóre modelu pro náš use-case (structured JSON extrakce z textu).
 * Vyšší = lepší. Nepoužívá hardcoded konkrétní verzi – jen rodinu (flash/pro) a číslo verze z názvu.
 */
function scoreGeminiModelForStructuredText(modelName: string): number {
  const lower = modelName.toLowerCase()
  if (!lower.startsWith("models/gemini")) return -1
  if (lower.includes("embedding")) return -1
  if (lower.includes("aqa")) return -1
  if (lower.includes("tts")) return -1
  if (lower.includes("image") && !lower.includes("flash")) return -1

  let score = 0
  if (lower.includes("flash")) score += 100
  else if (lower.includes("pro")) score += 60
  else score += 30

  // Preferuj vyšší číselnou verzi z názvu (např. gemini-2.0-… > gemini-1.5-…)
  const versionMatch = lower.match(/gemini-(\d+(?:\.\d+)?)/)
  if (versionMatch?.[1]) {
    const v = parseFloat(versionMatch[1])
    if (!Number.isNaN(v)) score += v * 10
  }

  if (lower.includes("preview") || lower.includes("experimental")) score -= 15
  if (lower.includes("lite")) score += 5

  return score
}

/**
 * Vybere nejlepší model pro generateContent + JSON schema z aktuálního seznamu API.
 */
export function pickGeminiStructuredModel(models: GeminiModelInfo[]): string | null {
  const eligible = models.filter((m) =>
    m.supportedGenerationMethods.includes("generateContent") &&
    scoreGeminiModelForStructuredText(m.name) >= 0
  )
  if (eligible.length === 0) return null

  eligible.sort((a, b) =>
    scoreGeminiModelForStructuredText(b.name) - scoreGeminiModelForStructuredText(a.name)
  )
  return eligible[0]?.name ?? null
}

/**
 * Vrátí název modelu (s cache). Při selhání volání lze cache vymazat a znovu vybrat.
 */
export async function resolveGeminiGenerateContentModel(apiKey: string): Promise<string> {
  if (cachedGenerateContentModel) return cachedGenerateContentModel
  const models = await listGeminiModels(apiKey)
  const picked = pickGeminiStructuredModel(models)
  if (!picked) {
    throw new Error("No Gemini model supporting generateContent found for structured JSON")
  }
  cachedGenerateContentModel = picked
  console.info("[gemini] selected model:", picked)
  return picked
}

/** Vymaže cache – po 404 nebo deprecated modelu zkusíme znovu list models. */
export function clearGeminiModelCache(): void {
  cachedGenerateContentModel = null
}

type GeminiGenerateResponse = {
  candidates?: Array<{
    content?: {
      parts?: Array<{ text?: string }>
    }
  }>
  error?: { message?: string }
}

/**
 * Volá Gemini generateContent s responseMimeType + responseSchema (Structured Output).
 * Volitelně přiloží obrázek jako inlineData (screenshot WhatsApp atd.).
 */
export async function geminiGenerateStructuredJson(args: {
  apiKey: string
  model: string
  prompt: string
  responseSchema: Record<string, unknown>
  /** Base64 bez data-URL prefixu. */
  imageBase64?: string | null
  /** MIME typ, např. image/jpeg. */
  imageMimeType?: string | null
}): Promise<string> {
  const modelPath = args.model.startsWith("models/") ? args.model : `models/${args.model}`
  const url =
    `${GEMINI_API_BASE}/${modelPath}:generateContent?key=${encodeURIComponent(args.apiKey)}`

  const parts: Array<Record<string, unknown>> = [{ text: args.prompt }]
  const b64 = args.imageBase64?.trim()
  if (b64) {
    const mime = (args.imageMimeType?.trim() || "image/jpeg").toLowerCase()
    const allowed = new Set(["image/jpeg", "image/png", "image/webp", "image/gif"])
    const safeMime = allowed.has(mime) ? mime : "image/jpeg"
    parts.push({
      inlineData: {
        mimeType: safeMime,
        data: b64.replace(/^data:[^;]+;base64,/, ""),
      },
    })
  }

  const body = {
    contents: [{ role: "user", parts }],
    generationConfig: {
      responseMimeType: "application/json",
      responseSchema: args.responseSchema,
      temperature: 0.2,
    },
  }

  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  })

  if (!res.ok) {
    const errText = await res.text()
    throw new Error(`Gemini generateContent failed (${res.status}): ${errText.slice(0, 400)}`)
  }

  const data = await res.json() as GeminiGenerateResponse
  const text = data.candidates?.[0]?.content?.parts?.[0]?.text?.trim()
  if (!text) {
    const apiErr = data.error?.message ?? "empty candidates"
    throw new Error(`Gemini empty response: ${apiErr}`)
  }
  return text
}

/**
 * Structured JSON s automatickým výběrem modelu; při chybě modelu jednou re-resolve.
 */
export async function geminiStructuredJsonWithAutoModel(args: {
  apiKey: string
  prompt: string
  responseSchema: Record<string, unknown>
  imageBase64?: string | null
  imageMimeType?: string | null
}): Promise<string> {
  let model = await resolveGeminiGenerateContentModel(args.apiKey)
  try {
    return await geminiGenerateStructuredJson({
      apiKey: args.apiKey,
      model,
      prompt: args.prompt,
      responseSchema: args.responseSchema,
      imageBase64: args.imageBase64,
      imageMimeType: args.imageMimeType,
    })
  } catch (firstErr) {
    const msg = firstErr instanceof Error ? firstErr.message : String(firstErr)
    const retriable = msg.includes("(404)") || msg.includes("not found") ||
      msg.includes("not supported")
    if (!retriable) throw firstErr
    console.warn("[gemini] model failed, re-resolving:", msg.slice(0, 120))
    clearGeminiModelCache()
    model = await resolveGeminiGenerateContentModel(args.apiKey)
    return await geminiGenerateStructuredJson({
      apiKey: args.apiKey,
      model,
      prompt: args.prompt,
      responseSchema: args.responseSchema,
      imageBase64: args.imageBase64,
      imageMimeType: args.imageMimeType,
    })
  }
}
