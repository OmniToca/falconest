// =============================================================================
// FalcoNest – sdílený in-memory rate limiter pro Edge Functions (Deno)
// -----------------------------------------------------------------------------
// PROČ: Veřejné endpointy (iCal token, webhooky) nemají Redis; jedna instance
// procesu drží Map klíčů → počty v časovém okně. Při růstu počtu klíčů ořezáváme
// staré záznamy, aby paměť nerostla neomezeně. Horizontální škálování = limit je
// „best effort“ per instance (stejné omezení jako dříve u export_calendar).
// =============================================================================

/** Stav jednoho klíče: počet hitů od začátku okna a délka okna (pro ořez paměti). */
type RateBucket = {
  count: number
  windowStart: number
  windowMs: number
}

const defaultBuckets = new Map<string, RateBucket>()

const DEFAULT_MAX_BUCKETS = 5000

/**
 * Složí interní klíč tak, aby stejný identifikátor s jiným limitem/oknem nekolidoval.
 */
function compositeKey(identifier: string, maxRequests: number, windowMs: number): string {
  return `${maxRequests}\x1f${windowMs}\x1f${identifier}`
}

/**
 * Odstraní mrtvé záznamy a při přetížení Map nejstarší bucket, dokud velikost neklesne.
 * PROČ: Stejná strategie jako původní export_calendar – TTL cca 2× okno + tvrdý strop.
 */
function pruneBuckets(now: number, maxBuckets: number): void {
  if (defaultBuckets.size <= maxBuckets) return
  for (const [k, v] of defaultBuckets) {
    if (now - v.windowStart > 2 * v.windowMs) {
      defaultBuckets.delete(k)
    }
  }
  if (defaultBuckets.size > maxBuckets) {
    const sorted = [...defaultBuckets.entries()].sort(
      (a, b) => a[1].windowStart - b[1].windowStart,
    )
    for (const [k] of sorted) {
      defaultBuckets.delete(k)
      if (defaultBuckets.size <= Math.floor(maxBuckets * 0.8)) break
    }
  }
}

/**
 * Vrátí `true`, pokud je požadavek v limitu; `false` při překročení (volající vrátí 429).
 *
 * @param identifier Např. SHA-256 hash tokenu (iCal) nebo IP (webhooky).
 * @param maxRequests Maximální počet povolených požadavků v okně.
 * @param windowMs Délka okna v ms (klouzající okno od prvního hitu v sérii).
 * @param options.maxBuckets Max. položek v Map před agresivnějším ořezem (výchozí 5000).
 */
export function checkRateLimit(
  identifier: string,
  maxRequests: number,
  windowMs: number,
  options?: { maxBuckets?: number },
): boolean {
  const maxBuckets = options?.maxBuckets ?? DEFAULT_MAX_BUCKETS
  const key = compositeKey(identifier, maxRequests, windowMs)
  const now = Date.now()
  pruneBuckets(now, maxBuckets)

  const b = defaultBuckets.get(key)
  if (!b || now - b.windowStart >= windowMs) {
    defaultBuckets.set(key, { count: 1, windowStart: now, windowMs })
    return true
  }
  if (b.count >= maxRequests) {
    return false
  }
  b.count += 1
  return true
}

/**
 * IP klienta za reverse proxy / CDN – vhodné jako `identifier` u webhooků.
 * PROČ: Supabase / Cloudflare často předávají skutečnou IP v těchto hlavičkách.
 */
export function getClientIpForRateLimit(req: Request): string {
  const cf = req.headers.get("cf-connecting-ip")?.trim()
  if (cf) return cf
  const xff = req.headers.get("x-forwarded-for")?.trim()
  if (xff) {
    const first = xff.split(",")[0]?.trim()
    if (first) return first
  }
  return "unknown"
}
