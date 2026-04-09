// Supabase Edge Function – připomenutí šablon zpráv (Time-Block systém)
// Volá se z pg_cron v 7:00, 11:00, 15:00 a 19:00 (Europe/Madrid).
// PROČ: Řidiče nesmíme budit v noci – místo přesných 48h/24h odpočtů používáme
// směnové bloky. Každý běh vyhodnotí události pro následující blok.
//
// Události: T1 = scheduled_start - 48h, T2 = -24h, T3 = -1h.
// Filtrujeme pouze úkoly typu transfer (transfer_in, transfer_out, transfer).
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from "npm:@supabase/supabase-js@2"
import { getToken } from "https://deno.land/x/google_jwt_sa@v0.2.5/mod.ts"

const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
const MADRID_TZ = "Europe/Madrid"
/** Plánované hodiny spuštění v Madridu – žádné noční rušení. */
const CRON_HOURS = [7, 11, 15, 19]

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

/** Získá OAuth2 access token pro FCM HTTP v1 API. */
async function getFcmAccessToken(): Promise<string> {
  const json = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON")
  if (!json) throw new Error("FIREBASE_SERVICE_ACCOUNT_JSON není nastaven")
  const token = await getToken(json, { scope: [FCM_SCOPE] })
  return token.access_token
}

/** Klíče pro nativní překlady (Android strings.xml / iOS Localizable.strings). */
const TITLE_LOC_KEY = "fcm_template_reminder_title"
const BODY_LOC_KEY = "fcm_template_reminder_body"

/**
 * Odešle FCM přes HTTP v1 – lokalizované klíče (Android + APNS), bez pevných textů v TS.
 * @see https://firebase.google.com/docs/cloud-messaging/customize-messages/localize-messages
 */
async function sendFcmLocalizedMessage(
  projectId: string,
  accessToken: string,
  fcmToken: string,
  titleLocKey: string,
  titleLocArgs: string[],
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
            title_loc_args: titleLocArgs,
            body_loc_key: bodyLocKey,
            body_loc_args: bodyLocArgs,
          },
        },
        apns: {
          payload: {
            aps: {
              alert: {
                "title-loc-key": titleLocKey,
                "title-loc-args": titleLocArgs,
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
    console.error(`FCM failed for ${fcmToken.slice(0, 20)}...: ${res.status} ${text}`)
    return false
  }
  return true
}

/** Vrátí aktuální hodinu a den v Madridu (pro určení časového okna). */
function getMadridNow(): { year: number; month: number; day: number; hour: number; minute: number } {
  const now = new Date()
  const fmt = new Intl.DateTimeFormat("en-CA", {
    timeZone: MADRID_TZ,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  })
  const parts = fmt.formatToParts(now)
  const get = (t: string) => parts.find(p => p.type === t)?.value ?? "0"
  return {
    year: parseInt(get("year"), 10),
    month: parseInt(get("month"), 10) - 1,
    day: parseInt(get("day"), 10),
    hour: parseInt(get("hour"), 10),
    minute: parseInt(get("minute"), 10),
  }
}

/** Vybere časové okno pro aktuální směnový blok (Madrid). */
function getTimeWindow(): { windowStart: Date; windowEnd: Date } {
  const m = getMadridNow()
  const hours = CRON_HOURS
  let slotIndex = hours.findIndex(h => m.hour < h)
  if (slotIndex === -1) slotIndex = hours.length
  const startHour = slotIndex === 0 ? hours[hours.length - 1] : hours[slotIndex - 1]
  const endHour = hours[slotIndex === hours.length ? 0 : slotIndex] ?? hours[0]
  const nextDay = endHour <= startHour

  const pad = (n: number) => String(n).padStart(2, "0")
  const dateStr = `${m.year}-${pad(m.month + 1)}-${pad(m.day)}`
  const nextDayStr = nextDay
    ? new Date(Date.UTC(m.year, m.month, m.day + 1)).toISOString().slice(0, 10)
    : dateStr

  const windowStart = fromMadridLocal(dateStr, startHour, 0)
  const windowEnd = fromMadridLocal(nextDayStr, endHour, 0)

  return { windowStart, windowEnd }
}

/** Madrid lokální čas (YYYY-MM-DD, hour, min) → UTC Date. */
function fromMadridLocal(dateStr: string, hour: number, min: number): Date {
  const [y, mo, d] = dateStr.split("-").map(Number)
  const offsetMs = getMadridOffsetMs(new Date(Date.UTC(y, mo - 1, d, 12, 0, 0)))
  return new Date(Date.UTC(y, mo - 1, d, hour, min, 0) - offsetMs)
}

/** Vrátí offset Madrid oproti UTC v ms (kladné = Madrid je napřed). */
function getMadridOffsetMs(forDate: Date): number {
  const fmt = new Intl.DateTimeFormat("en-CA", {
    timeZone: MADRID_TZ,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  })
  const parts = fmt.formatToParts(forDate)
  const get = (t: string) => parseInt(parts.find(p => p.type === t)?.value ?? "0", 10)
  const mHour = get("hour")
  const mMin = get("minute")
  const mDay = get("day")
  const utcHour = forDate.getUTCHours()
  const utcMin = forDate.getUTCMinutes()
  const utcDay = forDate.getUTCDate()
  let diffHours = mHour - utcHour + (mMin - utcMin) / 60
  if (mDay !== utcDay) diffHours += mDay > utcDay ? 24 : -24
  return diffHours * 60 * 60 * 1000
}

/** Formátuje čas letu pro placeholder v notifikaci (neutrální 24h, bez pevného locale v TS). */
function formatFlightTime(iso: string | null): string {
  if (!iso) return "—"
  const d = new Date(iso)
  return d.toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit", hour12: false })
}

type EventType = "T1" | "T2" | "T3"

/** Krok šablony jako číslice pro loc-args (1 = 48h, 2 = 24h, 3 = 1h před letem). */
function templateStepForEvent(eventType: EventType): string {
  switch (eventType) {
    case "T1":
      return "1"
    case "T2":
      return "2"
    case "T3":
      return "3"
    default:
      return "1"
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

    const supabase = createClient(supabaseUrl, serviceRoleKey)
    const { windowStart, windowEnd } = getTimeWindow()

    // Transfer úkoly: task_type IN ('transfer_in', 'transfer_out', 'transfer')
    const { data: allTasks, error: tasksErr } = await supabase
      .from("tasks")
      .select(
        "id, tenant_id, assigned_to, scheduled_start, reservation_id, client_id, custom_title, metadata",
      )
      .in("task_type", ["transfer_in", "transfer_out", "transfer"])
      .eq("status", "assigned")
      .not("assigned_to", "is", null)
      .is("deleted_at", null)
      .is("invoiced_at", null)

    if (tasksErr) {
      console.error("tasks query error:", tasksErr)
      return new Response(
        JSON.stringify({ error: tasksErr.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      )
    }

    if (!allTasks || allTasks.length === 0) {
      return new Response(
        JSON.stringify({ message: "Žádné transfer úkoly", sent: 0 }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      )
    }

    const toNotify: Array<{
      task: (typeof allTasks)[0]
      eventType: EventType
      guestName: string
    }> = []

    for (const task of allTasks) {
      const scheduled = new Date(task.scheduled_start)
      const t1 = new Date(scheduled.getTime() - 48 * 60 * 60 * 1000)
      const t2 = new Date(scheduled.getTime() - 24 * 60 * 60 * 1000)
      const t3 = new Date(scheduled.getTime() - 60 * 60 * 1000)

      let eventType: EventType | null = null
      if (t1 >= windowStart && t1 < windowEnd) eventType = "T1"
      else if (t2 >= windowStart && t2 < windowEnd) eventType = "T2"
      else if (t3 >= windowStart && t3 < windowEnd) eventType = "T3"
      if (!eventType) continue

      let guestName = "Host"
      if (task.reservation_id) {
        const { data: res } = await supabase
          .from("reservations")
          .select("guest_name")
          .eq("id", task.reservation_id)
          .single()
        guestName = (res?.guest_name as string)?.trim() || guestName
      } else if (task.client_id) {
        const { data: client } = await supabase
          .from("clients")
          .select("name")
          .eq("id", task.client_id)
          .single()
        guestName = (client?.name as string)?.trim() || guestName
      } else if (task.custom_title) {
        guestName = task.custom_title.trim()
      }

      toNotify.push({ task, eventType, guestName })
    }

    const firebaseProjectId = Deno.env.get("FIREBASE_PROJECT_ID")
    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON")
    let fcmAccessToken: string | null = null
    async function ensureFcmAccessToken(): Promise<string | null> {
      if (fcmAccessToken) return fcmAccessToken
      if (!firebaseProjectId?.trim() || !serviceAccountJson?.trim()) {
        console.error("template-reminders: FCM push vyžaduje FIREBASE_PROJECT_ID a FIREBASE_SERVICE_ACCOUNT_JSON")
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

    for (const { task, eventType, guestName } of toNotify) {
      const profileId = (task.assigned_to as string)?.trim()
      if (!profileId) continue

      const { data: prefs } = await supabase
        .from("notification_preferences")
        .select("template_reminders_web, template_reminders_push, template_reminders_email")
        .eq("profile_id", profileId)
        .maybeSingle()

      const webEnabled = prefs?.template_reminders_web ?? true
      const pushEnabled = prefs?.template_reminders_push ?? true
      const emailEnabled = prefs?.template_reminders_email ?? true

      const flightTime = formatFlightTime(task.scheduled_start)
      const step = templateStepForEvent(eventType)
      const stepCz = eventType === "T1"
        ? "48 h před letem"
        : eventType === "T2"
        ? "24 h před letem"
        : "1 h před letem"
      const titleLocArgs = [guestName]
      const bodyLocArgs = [guestName, flightTime, step]

      const inAppTitle = "Připomenutí transferu"
      const inAppMessage =
        `Host: ${guestName}. Čas letu ${flightTime}. ${stepCz}.`

      const tenantId = task.tenant_id as string

      if (webEnabled) {
        const { error: notifErr } = await supabase.from("notifications").insert({
          tenant_id: tenantId,
          profile_id: profileId,
          title: inAppTitle,
          message: inAppMessage,
          type: "template_reminder",
          is_read: false,
          metadata: {
            entity: "task",
            task_id: String(task.id),
          },
        })
        if (notifErr) {
          console.error("notifications insert (template_reminder):", notifErr)
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
          const { error: qErr } = await supabase.from("automation_message_queue").insert({
            tenant_id: tenantId,
            rule_id: null,
            entity_id: task.id,
            entity_type: "task",
            scheduled_for: new Date().toISOString(),
            channel: "email",
            recipient_contact: workerEmail,
            editable_payload: {
              email_subject: inAppTitle,
              text: `${inAppMessage}\n\n— FalcoNest`,
              task_id: String(task.id),
              source: "template_reminder",
            },
          })
          if (qErr) {
            console.error("automation_message_queue (template_reminder email):", qErr)
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

      for (const d of devices) {
        const token = (d.fcm_token as string)?.trim()
        if (!token) continue
        const ok = await sendFcmLocalizedMessage(
          firebaseProjectId,
          accessToken,
          token,
          TITLE_LOC_KEY,
          titleLocArgs,
          BODY_LOC_KEY,
          bodyLocArgs,
        )
        if (ok) totalPushSent++
      }
    }

    return new Response(
      JSON.stringify({
        message: "Template reminders odeslány",
        window: { start: windowStart.toISOString(), end: windowEnd.toISOString() },
        tasksEvaluated: allTasks.length,
        notificationsQueued: toNotify.length,
        totalPushSent,
        totalWebInserted,
        totalEmailQueued,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err)
    console.error("template-reminders error:", msg)
    return new Response(
      JSON.stringify({ error: msg }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  }
})
