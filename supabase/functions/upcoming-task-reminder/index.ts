// Supabase Edge – upozornění „blížící se termín“ úkolu (cca 1 h před začátkem).
// Volá pg_cron každých 15 minut. Vybírá úkoly se scheduled_start v okně [now+50m, now+70m] UTC,
// aby každý úkol spadl přesně do jednoho běhu. Kanály: upcoming_task_web / push / email.
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from "npm:@supabase/supabase-js@2"
import { getToken } from "https://deno.land/x/google_jwt_sa@v0.2.5/mod.ts"

const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
const BUSINESS_TIMEZONE = "Europe/Madrid"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

async function getFcmAccessToken(): Promise<string> {
  const json = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON")
  if (!json) throw new Error("FIREBASE_SERVICE_ACCOUNT_JSON není nastaven")
  const token = await getToken(json, { scope: [FCM_SCOPE] })
  return token.access_token
}

async function sendFcmPlainPush(args: {
  projectId: string
  accessToken: string
  fcmToken: string
  title: string
  body: string
  data: Record<string, string>
}): Promise<boolean> {
  const url = `https://fcm.googleapis.com/v1/projects/${args.projectId}/messages:send`
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${args.accessToken}`,
    },
    body: JSON.stringify({
      message: {
        token: args.fcmToken,
        notification: { title: args.title, body: args.body },
        data: args.data,
        android: { priority: "HIGH" },
        apns: {
          payload: {
            aps: {
              alert: { title: args.title, body: args.body },
              sound: "default",
            },
          },
        },
      },
    }),
  })
  if (!res.ok) {
    const text = await res.text()
    console.error(`FCM upcoming_task failed ${res.status} ${text}`)
    return false
  }
  return true
}

function taskDisplayTitle(task: Record<string, unknown>): string {
  const custom = typeof task.custom_title === "string" ? task.custom_title.trim() : ""
  if (custom) return custom
  const title = typeof task.title === "string" ? task.title.trim() : ""
  if (title) return title
  return "Úkol"
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
    const now = Date.now()
    const windowStart = new Date(now + 50 * 60 * 1000)
    const windowEnd = new Date(now + 70 * 60 * 1000)
    const { data: tasks, error: tasksErr } = await supabase
      .from("tasks")
      .select(
        "id, tenant_id, assigned_to, scheduled_start, title, custom_title, task_type",
      )
      .eq("status", "assigned")
      .not("assigned_to", "is", null)
      .gte("scheduled_start", windowStart.toISOString())
      .lte("scheduled_start", windowEnd.toISOString())
      .is("deleted_at", null)
      .is("invoiced_at", null)

    if (tasksErr) {
      console.error("tasks query:", tasksErr)
      return new Response(
        JSON.stringify({ error: tasksErr.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      )
    }

    if (!tasks || tasks.length === 0) {
      return new Response(
        JSON.stringify({
          message: "Žádné úkoly v okně 50–70 min",
          window: { start: windowStart.toISOString(), end: windowEnd.toISOString() },
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      )
    }

    const firebaseProjectId = Deno.env.get("FIREBASE_PROJECT_ID")
    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON")
    let fcmAccessToken: string | null = null
    async function ensureFcmAccessToken(): Promise<string | null> {
      if (fcmAccessToken) return fcmAccessToken
      if (!firebaseProjectId?.trim() || !serviceAccountJson?.trim()) {
        console.error("upcoming-task-reminder: FCM vyžaduje FIREBASE_PROJECT_ID a FIREBASE_SERVICE_ACCOUNT_JSON")
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
    let skippedDuplicate = 0

    for (const task of tasks) {
      const profileId = (task.assigned_to as string)?.trim()
      if (!profileId) continue
      const tenantId = task.tenant_id as string
      const taskId = task.id as string
      const schedIso = String(task.scheduled_start ?? "").trim()

      const { error: logInsErr } = await supabase.from("upcoming_task_reminder_log").insert({
        task_id: taskId,
        scheduled_start: schedIso,
      })
      if (logInsErr) {
        const code = (logInsErr as { code?: string }).code
        const msg = String((logInsErr as { message?: string }).message ?? "")
        const isDup = code === "23505" || /duplicate key|already exists/i.test(msg)
        if (isDup) {
          skippedDuplicate++
          continue
        }
        console.error("upcoming_task_reminder_log insert:", logInsErr)
        continue
      }

      const { data: prefs } = await supabase
        .from("notification_preferences")
        .select("upcoming_task_web, upcoming_task_push, upcoming_task_email")
        .eq("profile_id", profileId)
        .maybeSingle()

      const webEnabled = prefs?.upcoming_task_web ?? true
      const pushEnabled = prefs?.upcoming_task_push ?? true
      const emailEnabled = prefs?.upcoming_task_email ?? true

      const label = taskDisplayTitle(task)
      const start = new Date(task.scheduled_start as string)
      const timeStr = start.toLocaleTimeString("cs-CZ", {
        hour: "2-digit",
        minute: "2-digit",
        timeZone: BUSINESS_TIMEZONE,
      })
      const inAppTitle = "Blížící se termín úkolu"
      const inAppMessage = `${label} · start ${timeStr} (${BUSINESS_TIMEZONE})`

      if (webEnabled) {
        const { error: notifErr } = await supabase.from("notifications").insert({
          tenant_id: tenantId,
          profile_id: profileId,
          title: inAppTitle,
          message: inAppMessage,
          type: "upcoming_task",
          is_read: false,
          metadata: {
            entity: "task",
            task_id: taskId,
            scheduled_start: schedIso,
          },
        })
        if (notifErr) console.error("notifications (upcoming_task):", notifErr)
        else totalWebInserted++
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
          const { error: qErr } = await supabase.from("automation_message_queue").insert({
            tenant_id: tenantId,
            rule_id: null,
            entity_id: taskId,
            entity_type: "task",
            scheduled_for: new Date().toISOString(),
            channel: "email",
            recipient_contact: workerEmail,
            editable_payload: {
              email_subject: inAppTitle,
              text: `${inAppMessage}\n\n— FalcoNest`,
              task_id: taskId,
              source: "upcoming_task",
            },
          })
          if (qErr) console.error("automation_message_queue (upcoming_task email):", qErr)
          else totalEmailQueued++
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

      for (const d of devices) {
        const token = (d.fcm_token as string)?.trim()
        if (!token) continue
        const ok = await sendFcmPlainPush({
          projectId: firebaseProjectId,
          accessToken,
          fcmToken: token,
          title: inAppTitle,
          body: inAppMessage,
          data: {
            route: `/worker/task/${taskId}`,
            task_id: taskId,
          },
        })
        if (ok) totalPushSent++
      }
    }

    return new Response(
      JSON.stringify({
        message: "upcoming_task reminder dokončeno",
        window: { start: windowStart.toISOString(), end: windowEnd.toISOString() },
        tasksMatched: tasks.length,
        skippedDuplicate,
        totalPushSent,
        totalWebInserted,
        totalEmailQueued,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err)
    console.error("upcoming-task-reminder error:", msg)
    return new Response(
      JSON.stringify({ error: msg }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  }
})
