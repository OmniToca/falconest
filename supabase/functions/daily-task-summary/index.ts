// Supabase Edge Function – Ranní souhrn úkolů (Daily Task Summary)
// Volá se z cron jobu každé ráno. Najde úkoly na dnešní den, seskupí podle zaměstnanců
// a rozešle FCM push notifikace s počtem úkolů.
//
// SECURITY: Běží se Service Role (obejde RLS), ale zprávy posílá POUZE na tokeny
// vlastněné daným profilem – nikdy ne na cizí zařízení.
//
// i18n: Text notifikace se neskladá v češtině na serveru – posílají se klíče
// (title_loc_key / body_loc_key + args), které OS přeloží podle jazyka zařízení.
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from "npm:@supabase/supabase-js@2"
import { DateTime } from "npm:luxon@3.5.0"
import { getToken } from "https://deno.land/x/google_jwt_sa@v0.2.5/mod.ts"

const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"

/** Kalendářní den pro výběr úkolů – španělská provozní zóna (ne čisté UTC). */
const BUSINESS_TIMEZONE = "Europe/Madrid"

const TITLE_LOC_KEY = "push_daily_summary_title"
const BODY_LOC_KEY_SINGULAR = "push_daily_summary_body_singular"
const BODY_LOC_KEY_FEW = "push_daily_summary_body_few"
const BODY_LOC_KEY_MANY = "push_daily_summary_body_many"

/**
 * Hlavičky CORS – funkce může být volána z cron (Supabase pg_cron) nebo manuálně.
 */
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

/**
 * Začátek a konec „dnešního“ dne v [BUSINESS_TIMEZONE] jako UTC instants pro dotaz na DB.
 * PROČ: Luxon správně řeší DST v Europe/Madrid; čisté UTC půlnoc by posouvalo „dnešek“ pro ES.
 */
function getTodayBoundsUtc(now: Date): { todayStart: Date; todayEnd: Date } {
  const z = DateTime.fromJSDate(now).setZone(BUSINESS_TIMEZONE)
  const todayStart = z.startOf("day").toUTC().toJSDate()
  const todayEnd = z.endOf("day").toUTC().toJSDate()
  return { todayStart, todayEnd }
}

/**
 * Česká (a obecně slovanská) gramatika: 1, 2–4, 5+.
 * PROČ: Ostatní jazyky mají vlastní překlady v nativních souborech; klíč „few“
 * může v angličtině být shodný s „many“, pokud je to v strings.xml/Localizable.strings.
 */
function bodyLocKeyForTaskCount(count: number): string {
  if (count === 1) return BODY_LOC_KEY_SINGULAR
  if (count >= 2 && count <= 4) return BODY_LOC_KEY_FEW
  return BODY_LOC_KEY_MANY
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
 * Odešle FCM zprávu na jeden token přes HTTP v1 API – lokalizované klíče (Android + APNS).
 * @see https://firebase.google.com/docs/cloud-messaging/customize-messages/localize-messages
 */
async function sendFcmLocalizedMessage(
  projectId: string,
  accessToken: string,
  fcmToken: string,
  titleLocKey: string,
  bodyLocKey: string,
  bodyLocArgs: string[],
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
        android: {
          notification: {
            title_loc_key: titleLocKey,
            body_loc_key: bodyLocKey,
            body_loc_args: bodyLocArgs,
          },
        },
        apns: {
          payload: {
            aps: {
              alert: {
                "title-loc-key": titleLocKey,
                "loc-key": bodyLocKey,
                "loc-args": bodyLocArgs,
              },
            },
          },
        },
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
    const { requireServiceRoleBearer } = await import("../_shared/edge_auth.ts")
    const denied = requireServiceRoleBearer(req)
    if (denied) return denied

    const supabaseUrl = Deno.env.get("SUPABASE_URL")
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
    if (!supabaseUrl || !serviceRoleKey) {
      return new Response(
        JSON.stringify({ error: "Chybí SUPABASE_URL nebo SUPABASE_SERVICE_ROLE_KEY" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      )
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey)

    const now = new Date()
    const { todayStart, todayEnd } = getTodayBoundsUtc(now)

    // 2) Stáhnout úkoly: status = 'assigned', scheduled_start dnes, assigned_to není prázdné.
    //    RLS je obcházen díky Service Role – vidíme úkoly všech tenantů.
    const { data: tasks, error: tasksError } = await supabase
      .from("tasks")
      .select("id, assigned_to, scheduled_start, tenant_id")
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

    // 4) FCM token se načte až při prvním push (web/e-mail mohou fungovat bez Firebase).
    const firebaseProjectId = Deno.env.get("FIREBASE_PROJECT_ID")
    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON")
    let fcmAccessToken: string | null = null
    async function ensureFcmAccessToken(): Promise<string | null> {
      if (fcmAccessToken) return fcmAccessToken
      if (!firebaseProjectId?.trim() || !serviceAccountJson?.trim()) {
        console.error("daily-task-summary: FCM push vyžaduje FIREBASE_PROJECT_ID a FIREBASE_SERVICE_ACCOUNT_JSON")
        return null
      }
      try {
        fcmAccessToken = await getFcmAccessToken()
        return fcmAccessToken
      } catch (e) {
        console.error("FCM token error:", e)
        return null
      }
    }

    let totalPushSent = 0
    let totalWebInserted = 0
    let totalEmailQueued = 0

    // 5) Pro každého zaměstnance s úkoly: kanály dle notification_preferences (web / push / e-mail).
    for (const [profileId, taskCount] of tasksByProfile) {
      const { data: prefs } = await supabase
        .from("notification_preferences")
        .select("daily_summary_web, daily_summary_push, daily_summary_email")
        .eq("profile_id", profileId)
        .maybeSingle()

      const webEnabled = prefs?.daily_summary_web ?? true
      const pushEnabled = prefs?.daily_summary_push ?? true
      const emailEnabled = prefs?.daily_summary_email ?? true

      const sampleTask = tasks!.find((t) => (t.assigned_to as string)?.trim() === profileId)
      const tenantId = sampleTask?.tenant_id as string | undefined
      const firstTaskId = sampleTask?.id as string | undefined

      if (!tenantId) continue

      const summaryTitle = "Ranní souhrn úkolů"
      const summaryMessage = taskCount === 1
        ? "Máte 1 úkol naplánovaný na dnešek."
        : `Máte ${taskCount} úkolů naplánovaných na dnešek.`

      if (webEnabled) {
        const { error: notifErr } = await supabase.from("notifications").insert({
          tenant_id: tenantId,
          profile_id: profileId,
          title: summaryTitle,
          message: summaryMessage,
          type: "daily_summary",
          is_read: false,
          metadata: {
            entity: "daily_summary",
            task_count: String(taskCount),
            ...(firstTaskId ? { task_id: firstTaskId } : {}),
          },
        })
        if (notifErr) {
          console.error("notifications insert (daily_summary):", notifErr)
        } else {
          totalWebInserted++
        }
      }

      if (emailEnabled) {
        const { data: prof } = await supabase
          .from("profiles")
          .select("email")
          .eq("id", profileId)
          .eq("tenant_id", tenantId)
          .maybeSingle()
        const workerEmail = (prof?.email as string | undefined)?.trim()
        if (workerEmail) {
          const entityId = firstTaskId ?? profileId
          const { error: qErr } = await supabase.from("automation_message_queue").insert({
            tenant_id: tenantId,
            rule_id: null,
            entity_id: entityId,
            entity_type: "task",
            scheduled_for: new Date().toISOString(),
            channel: "email",
            recipient_contact: workerEmail,
            editable_payload: {
              email_subject: summaryTitle,
              text: `${summaryMessage}\n\n— FalcoNest`,
              source: "daily_summary",
              task_count: String(taskCount),
            },
          })
          if (qErr) {
            console.error("automation_message_queue (daily_summary email):", qErr)
          } else {
            totalEmailQueued++
          }
        }
      }

      if (!pushEnabled) continue

      const accessToken = await ensureFcmAccessToken()
      if (!accessToken || !firebaseProjectId) continue

      const { data: devices } = await supabase
        .from("user_devices")
        .select("fcm_token")
        .eq("profile_id", profileId)

      if (!devices || devices.length === 0) continue

      const bodyLocKey = bodyLocKeyForTaskCount(taskCount)
      const bodyLocArgs = [String(taskCount)]

      for (const d of devices) {
        const token = (d.fcm_token as string)?.trim()
        if (!token) continue
        const ok = await sendFcmLocalizedMessage(
          firebaseProjectId,
          accessToken,
          token,
          TITLE_LOC_KEY,
          bodyLocKey,
          bodyLocArgs,
        )
        if (ok) totalPushSent++
      }
    }

    return new Response(
      JSON.stringify({
        message: "Ranní souhrn odeslán",
        profilesWithTasks: tasksByProfile.size,
        totalTasks: tasks.length,
        totalPushSent,
        totalWebInserted,
        totalEmailQueued,
        timezone: BUSINESS_TIMEZONE,
        dayStartUtc: todayStart.toISOString(),
        dayEndUtc: todayEnd.toISOString(),
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
