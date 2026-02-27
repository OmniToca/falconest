// Supabase Edge Function – Ranní souhrn úkolů (Daily Task Summary)
// Volá se z cron jobu každé ráno. Najde úkoly na dnešní den, seskupí podle zaměstnanců
// a rozešle FCM push notifikace s počtem úkolů.
//
// SECURITY: Běží se Service Role (obejde RLS), ale zprávy posílá POUZE na tokeny
// vlastněné daným profilem – nikdy ne na cizí zařízení.
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from "npm:@supabase/supabase-js@2"
import { getToken } from "https://deno.land/x/google_jwt_sa@v0.2.5/mod.ts"

const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"

/**
 * Hlavičky CORS – funkce může být volána z cron (Supabase pg_cron) nebo manuálně.
 */
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

/**
 * Získá OAuth2 access token pro FCM HTTP v1 API z Firebase service account.
 * Vyžaduje: FIREBASE_SERVICE_ACCOUNT_JSON (celý JSON jako string).
 */
async function getFcmAccessToken(): Promise<string> {
  const json = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON")
  if (!json) {
    throw new Error("FIREBASE_SERVICE_ACCOUNT_JSON není nastaven v Supabase secrets")
  }
  const token = await getToken(json, { scope: [FCM_SCOPE] })
  return token.access_token
}

/**
 * Odešle FCM zprávu na jeden token přes HTTP v1 API.
 * @see https://firebase.google.com/docs/cloud-messaging/send-v1
 */
async function sendFcmMessage(
  projectId: string,
  accessToken: string,
  fcmToken: string,
  title: string,
  body: string,
): Promise<boolean> {
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${accessToken}`,
    },
    body: JSON.stringify({
      message: {
        token: fcmToken,
        notification: { title, body },
      },
    }),
  })
  if (!res.ok) {
    const text = await res.text()
    console.error(`FCM send failed for token ${fcmToken.slice(0, 20)}...: ${res.status} ${text}`)
    return false
  }
  return true
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

    const supabase = createClient(supabaseUrl, serviceRoleKey)

    // 1) Určení hranic dnešního dne (UTC).
    const now = new Date()
    const todayStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), 0, 0, 0))
    const todayEnd = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), 23, 59, 59))

    // 2) Stáhnout úkoly: status = 'assigned', scheduled_start dnes, assigned_to není prázdné.
    //    RLS je obcházen díky Service Role – vidíme úkoly všech tenantů.
    const { data: tasks, error: tasksError } = await supabase
      .from("tasks")
      .select("id, assigned_to, scheduled_start")
      .eq("status", "assigned") // Zadáno – úkol přiřazen, ještě nezačat
      .not("assigned_to", "is", null)
      .gte("scheduled_start", todayStart.toISOString())
      .lte("scheduled_start", todayEnd.toISOString())
      .is("deleted_at", null)
      .is("invoiced_at", null)

    if (tasksError) {
      console.error("tasks query error:", tasksError)
      return new Response(
        JSON.stringify({ error: tasksError.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      )
    }

    if (!tasks || tasks.length === 0) {
      return new Response(
        JSON.stringify({ message: "Žádné úkoly na dnešní den", sent: 0 }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      )
    }

    // 3) Seskupení úkolů podle assigned_to (profile_id zaměstnance).
    //    Map<profileId, taskCount> – kolik úkolů má každý pracovník dnes.
    const tasksByProfile = new Map<string, number>()
    for (const t of tasks) {
      const profileId = (t.assigned_to as string)?.trim()
      if (!profileId) continue
      tasksByProfile.set(profileId, (tasksByProfile.get(profileId) ?? 0) + 1)
    }

    // 4) Získat FCM credentials (service account JSON → access token).
    const firebaseProjectId = Deno.env.get("FIREBASE_PROJECT_ID")
    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON")
    if (!firebaseProjectId || !serviceAccountJson) {
      return new Response(
        JSON.stringify({ error: "FIREBASE_PROJECT_ID nebo FIREBASE_SERVICE_ACCOUNT_JSON chybí" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      )
    }

    let accessToken: string
    try {
      accessToken = await getFcmAccessToken()
    } catch (e) {
      console.error("FCM token error:", e)
      return new Response(
        JSON.stringify({ error: "Nelze získat FCM access token: " + String(e) }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      )
    }

    let totalSent = 0

    // 5) Pro každého zaměstnance s úkoly: zkontrolovat preference, načíst tokeny, odeslat.
    for (const [profileId, taskCount] of tasksByProfile) {
      // Kontrola notification_preferences – daily_summary_enabled.
      // Pokud záznam neexistuje, výchozí hodnota je true (poslat souhrn).
      const { data: prefs } = await supabase
        .from("notification_preferences")
        .select("daily_summary_enabled")
        .eq("profile_id", profileId)
        .maybeSingle()

      const dailyEnabled = prefs?.daily_summary_enabled ?? true
      if (!dailyEnabled) continue

      // Načíst FCM tokeny tohoto profilu z user_devices.
      const { data: devices } = await supabase
        .from("user_devices")
        .select("fcm_token")
        .eq("profile_id", profileId)

      if (!devices || devices.length === 0) continue

      const title = "Ranní souhrn úkolů"
      const body =
        taskCount === 1
          ? "Dnes tě čeká 1 úkol. Přejeme úspěšný den!"
          : `Dnes tě čeká ${taskCount} úkolů. Přejeme úspěšný den!`

      for (const d of devices) {
        const token = (d.fcm_token as string)?.trim()
        if (!token) continue
        const ok = await sendFcmMessage(firebaseProjectId, accessToken, token, title, body)
        if (ok) totalSent++
      }
    }

    return new Response(
      JSON.stringify({
        message: "Ranní souhrn odeslán",
        profilesWithTasks: tasksByProfile.size,
        totalTasks: tasks.length,
        totalSent,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err)
    console.error("daily-task-summary error:", msg)
    return new Response(
      JSON.stringify({ error: msg }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  }
})
