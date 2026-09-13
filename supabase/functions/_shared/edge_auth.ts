/**
 * Sdílená autentizace Edge funkcí – cron vs. uživatelský JWT.
 *
 * PROČ: Audit P0 – cron funkce nesmí běžet bez Bearer tokenu; uživatelské
 * funkce musí vázat tenant_id na profiles, ne na body requestu.
 */
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2"

export type AuthedProfile = {
  id: string
  authId: string
  tenantId: string | null
  role: string
}

/** Ověří Authorization: Bearer == SUPABASE_SERVICE_ROLE_KEY (pg_cron / interní joby). */
export function requireServiceRoleBearer(req: Request): Response | null {
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim()
  if (!serviceRoleKey) {
    return jsonError(500, "Chybí SUPABASE_SERVICE_ROLE_KEY")
  }
  const authHeader = (req.headers.get("Authorization") ?? "").trim()
  const expected = `Bearer ${serviceRoleKey}`
  if (!authHeader || authHeader !== expected) {
    console.warn("[edge_auth] 401 – Neplatný nebo chybějící service-role Authorization")
    return jsonError(401, "Unauthorized")
  }
  return null
}

/**
 * Ověří uživatelský JWT a načte profil (auth_id = auth.uid()).
 * Vrací buď { client, profile }, nebo Response s chybou.
 */
export async function requireUserProfile(
  req: Request,
): Promise<
  | { ok: true; client: SupabaseClient; profile: AuthedProfile; accessToken: string }
  | { ok: false; response: Response }
> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL")
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")
  if (!supabaseUrl || !anonKey) {
    return { ok: false, response: jsonError(500, "Chybí SUPABASE_URL nebo SUPABASE_ANON_KEY") }
  }

  const authHeader = (req.headers.get("Authorization") ?? "").trim()
  if (!authHeader.toLowerCase().startsWith("bearer ")) {
    return { ok: false, response: jsonError(401, "Chybí Authorization Bearer token") }
  }
  const accessToken = authHeader.slice(7).trim()
  if (!accessToken) {
    return { ok: false, response: jsonError(401, "Prázdný access token") }
  }

  // Uživatelský klient – respektuje RLS volajícího.
  const client = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${accessToken}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  })

  const { data: userData, error: userErr } = await client.auth.getUser(accessToken)
  if (userErr || !userData?.user?.id) {
    return { ok: false, response: jsonError(401, "Neplatný nebo vypršený JWT") }
  }

  const authId = userData.user.id
  const { data: profileRow, error: profileErr } = await client
    .from("profiles")
    .select("id, auth_id, tenant_id, role")
    .eq("auth_id", authId)
    .maybeSingle()

  if (profileErr || !profileRow) {
    console.error("[edge_auth] profil nenalezen:", profileErr?.message)
    return { ok: false, response: jsonError(403, "Profil uživatele nenalezen") }
  }

  const role = String(profileRow.role ?? "").trim()
  const tenantId =
    profileRow.tenant_id == null ? null : String(profileRow.tenant_id).trim() || null

  return {
    ok: true,
    client,
    accessToken,
    profile: {
      id: String(profileRow.id),
      authId: String(profileRow.auth_id ?? authId),
      tenantId,
      role,
    },
  }
}

export function isSuperAdminRole(role: string): boolean {
  return role === "super_admin"
}

export function isTenantAdminOrManager(role: string): boolean {
  return role === "admin" || role === "manager"
}

export function jsonError(status: number, error: string): Response {
  return new Response(JSON.stringify({ error }), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers":
        "authorization, x-client-info, apikey, content-type",
    },
  })
}

export const edgeCorsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
}
