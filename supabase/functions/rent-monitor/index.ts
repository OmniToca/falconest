// =============================================================================
// FalcoNest – Edge funkce rent-monitor (denní splatnost nájmu u long_term bytů)
// =============================================================================
// Volání: POST z pg_cron přes invoke_rent_monitor() s Authorization: Bearer
// SUPABASE_SERVICE_ROLE_KEY (stejný token jako ostatní automation).
//
// Tok: 1) Najdi byty long_term se shodným rent_due_day (kalendář Europe/Madrid).
//      2) U každého ověř, že v apartment_rent_due_runs ještě není řádek pro
//         (apartment_id, billing_month, run_kind) → jinak přeskoč.
//      3) notification → insert notifications (majitelé + admin/manager).
//         task → insert tasks (rent_collection, pending, assigned_to z bytu),
//         metadata vč. transit_amount_to_collect (nativní blok „Celkem vybrat“ v mobilu);
//         Dual-path: má-li byt apartment_services řádek pro katalogovou službu rent_collection,
//         nastaví se tasks.service_id a do metadata amount_to_collect (fee) + payer_type;
//         jinak fallback bez service_id a bez těchto klíčů v metadatech. transit_amount_to_collect
//         = nájem majitele (vždy v metadata).
//         rent_amount / rent_due_day vždy z apartments.
//         krátký description; poté task_checklists + 2 položky task_checklist_items.
//      4) Úspěch → insert apartment_rent_due_runs (idempotence pro příště).
//
// metadata.rent_cycle_key = `${apartment_id}:${billing_month}` (první den měsíce
// ISO) – očekává SQL trigger P&L u dokončeného úkolu rent_collection.
// metadata.transit_amount_to_collect = stejné jako rent_amount – částka pro worker UI.
//
// NASAZENÍ (produkce):
//   supabase functions deploy rent-monitor --project-ref <VÁŠ_PROJECT_REF>
//   # nebo z kořene projektu, pokud je CLI přihlášené:
//   supabase functions deploy rent-monitor
// =============================================================================

import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2"
import { DateTime } from "npm:luxon@3.5.0"

const BUSINESS_TIMEZONE = "Europe/Madrid"

/** Systémový kód kategorie v task_categories; u tenant_services odpovídá sloupci service_type (vazba typu kategorie, ne název služby). */
const RENT_COLLECTION_CATEGORY_CODE = "rent_collection"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

/** Vnořený řádek apartment_services z PostgREST (1:N od bytu). */
type ApartmentServiceEmbed = {
  service_id?: string
  custom_price?: number | string | null
  /** V DB je na apartment_services (ne na tenant_services). */
  payer_type?: string | null
  /** Až bude v DB sloupec assigned_profile_id, doplnit ho i do select dotazu. */
  assigned_profile_id?: string | null
}

type ApartmentRow = {
  id: string
  tenant_id: string
  name: string
  rental_mode: string
  rent_due_day: number
  rent_amount: number | string | null
  rent_collection_mode: string
  rent_task_assignee_id: string | null
  lease_start_date: string | null
  lease_end_date: string | null
  /** Vnořený tenants z dotazu apartments(..., tenants(currency)) – měna fakturace tenantu. */
  tenants?: { currency?: string | null } | { currency?: string | null }[] | null
  /** Služby přiřazené bytu; PostgREST může vrátit null, pole nebo výjimečně jeden objekt. */
  apartment_services?: ApartmentServiceEmbed[] | ApartmentServiceEmbed | null
}

function todayDateStringMadrid(): string {
  return DateTime.now().setZone(BUSINESS_TIMEZONE).toISODate()!
}

function billingMonthFirstDayMadrid(): string {
  return DateTime.now().setZone(BUSINESS_TIMEZONE).startOf("month").toISODate()!
}

function dayOfMonthMadrid(): number {
  return DateTime.now().setZone(BUSINESS_TIMEZONE).day
}

function nowIsoUtc(): string {
  return new Date().toISOString()
}

function parseNum(v: number | string | null | undefined): number {
  if (v == null) return 0
  if (typeof v === "number") return v
  const n = parseFloat(String(v).replace(",", "."))
  return Number.isFinite(n) ? n : 0
}

/** Měna z řádku bytu (join tenants); prázdné → EUR jako bezpečný default pro metadata/UI. */
function rentCurrencyFromApartment(apt: ApartmentRow): string {
  const raw = apt.tenants
  let cur: string | null | undefined
  if (raw == null) cur = undefined
  else if (Array.isArray(raw)) cur = raw[0]?.currency
  else cur = raw.currency
  const s = (cur ?? "").trim().toUpperCase()
  return s.length > 0 ? s : "EUR"
}

/** Krátký textová částka pro popis/checklist (bez locale formátování – spolehlivé v Edge). */
function formatRentAmountForUi(amount: number): string {
  if (!Number.isFinite(amount)) return "0"
  if (Number.isInteger(amount)) return String(amount)
  const t = amount.toFixed(2)
  return t.replace(/\.?0+$/, "")
}

/** Katalogová služba rent_collection pro tenant (id + výchozí cena). payer_type je jen u apartment_services. */
type RentCollectionCatalogInfo = {
  serviceId: string | null
  defaultPrice: number
}

const EMPTY_RENT_CATALOG: RentCollectionCatalogInfo = { serviceId: null, defaultPrice: 0 }

/**
 * Načte katalogovou službu tenanta pro rent_collection (id + default_price).
 *
 * PROČ: Název služby je lokalizovatelný; vazba je tenant_services.service_type = task_categories.code.
 * default_price vstupuje do final_service_price spolu s apartment_services.custom_price.
 */
async function resolveRentCollectionCatalogInfo(
  supabase: SupabaseClient,
  tenantId: string,
  rentCategoryId: string | null,
  cache: Map<string, RentCollectionCatalogInfo>,
): Promise<RentCollectionCatalogInfo> {
  const cached = cache.get(tenantId)
  if (cached !== undefined) return cached

  if (!rentCategoryId) {
    cache.set(tenantId, EMPTY_RENT_CATALOG)
    return EMPTY_RENT_CATALOG
  }

  const { data: svc, error: sErr } = await supabase
    .from("tenant_services")
    .select("id, default_price")
    .eq("tenant_id", tenantId)
    .eq("service_type", RENT_COLLECTION_CATEGORY_CODE)
    .eq("is_active", true)
    .is("deleted_at", null)
    .order("order_index", { ascending: true })
    .limit(1)
    .maybeSingle()

  if (sErr) {
    console.warn(
      `[rent-monitor] tenant_services (kód kategorie=${RENT_COLLECTION_CATEGORY_CODE}) tenant_id=${tenantId}:`,
      sErr,
    )
    cache.set(tenantId, EMPTY_RENT_CATALOG)
    return EMPTY_RENT_CATALOG
  }

  const row = svc as { id?: string; default_price?: number | string | null } | null
  const id = row?.id ?? null
  const defaultPrice = parseNum(row?.default_price)
  if (!id) {
    console.log(
      `[rent-monitor] Žádná aktivní služba s kategorií ${RENT_COLLECTION_CATEGORY_CODE} pro tenant_id=${tenantId} – bez katalogové vazby`,
    )
  }
  const info: RentCollectionCatalogInfo = { serviceId: id, defaultPrice }
  cache.set(tenantId, info)
  return info
}

/** Cena práce agentury: custom_price z bytu, jinak default z katalogu, jinak 0. */
function finalRentCollectionServicePrice(
  customPriceRaw: number | string | null | undefined,
  defaultPrice: number,
): number {
  if (customPriceRaw != null && String(customPriceRaw).trim() !== "") {
    return parseNum(customPriceRaw)
  }
  return Number.isFinite(defaultPrice) ? defaultPrice : 0
}

/** Platný plátce pro metadata.payer_type; neznámá hodnota → owner (požadavek klienta). */
function taskPayerTypeOrOwner(raw: string | null | undefined): "owner" | "guest" {
  const s = (raw ?? "").trim().toLowerCase()
  if (s === "guest") return "guest"
  return "owner"
}

/**
 * Normalizace embedu apartment_services – bezpečně pro null / [] / jeden objekt.
 * PROČ: PostgREST u 1:N někdy vrací pole, při 0 řádcích prázdné pole nebo null; nesmíme spadnout.
 */
function normalizeApartmentServicesEmbed(
  raw: ApartmentRow["apartment_services"],
): ApartmentServiceEmbed[] {
  if (raw == null) return []
  if (Array.isArray(raw)) return raw
  return [raw as ApartmentServiceEmbed]
}

/**
 * Najde řádek apartment_services pro katalogovou službu rent_collection (stejné service_id).
 */
function findApartmentServiceForCatalogId(
  rows: ApartmentServiceEmbed[],
  catalogServiceId: string | null,
): ApartmentServiceEmbed | null {
  if (catalogServiceId == null || catalogServiceId.length === 0) return null
  for (const r of rows) {
    const sid = (r.service_id ?? "").trim()
    if (sid === catalogServiceId) return r
  }
  return null
}

/** NULL / prázdné datum smlouvy = bez omezení (nájem neurčitě). */
function isLeaseActiveToday(
  today: string,
  leaseStart: string | null,
  leaseEnd: string | null,
): boolean {
  const start = (leaseStart ?? "").trim()
  const end = (leaseEnd ?? "").trim()
  if (start.length > 0 && today < start) return false
  if (end.length > 0 && today > end) return false
  return true
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
  if (!supabaseUrl || !serviceRoleKey) {
    console.error("[rent-monitor] Chybí SUPABASE_URL nebo SUPABASE_SERVICE_ROLE_KEY")
    return new Response(
      JSON.stringify({ error: "Chybí SUPABASE_URL nebo SUPABASE_SERVICE_ROLE_KEY" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  }

  // Ověření: hlavička musí přesně odpovídat Bearer + klíč z prostředí funkce (pg_cron ukládá stejný JWT do cron_edge_config.automation_edge_auth_token).
  const authHeaderGet = req.headers.get("Authorization")
  const authHeader = (authHeaderGet ?? "").trim()
  const expectedAuth = `Bearer ${serviceRoleKey}`

  if (!authHeader || authHeader !== expectedAuth) {
    console.warn("[rent-monitor] 401 – Neplatný nebo chybějící Authorization token.")
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey)
  const today = todayDateStringMadrid()
  const billingMonth = billingMonthFirstDayMadrid()
  const dom = dayOfMonthMadrid()

  console.log(
    `[rent-monitor] === START === zóna=${BUSINESS_TIMEZONE} today=${today} den_měsíce=${dom} billing_month=${billingMonth}`,
  )

  let processed = 0
  let skipped = 0
  let errors = 0

  try {
    const { data: apartments, error: aptErr } = await supabase
      .from("apartments")
      .select(
        "id, tenant_id, name, rental_mode, rent_due_day, rent_amount, rent_collection_mode, rent_task_assignee_id, lease_start_date, lease_end_date, tenants ( currency ), apartment_services ( service_id, custom_price, payer_type )",
      )
      .eq("rental_mode", "long_term")
      .eq("rent_due_day", dom)
      .is("deleted_at", null)

    if (aptErr) {
      console.error("[rent-monitor] CHYBA dotazu apartments:", aptErr)
      return new Response(JSON.stringify({ error: aptErr.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    const list = (apartments ?? []) as ApartmentRow[]
    console.log(`[rent-monitor] Nalezeno kandidátů (long_term, splatnost=${dom}): ${list.length}`)

    const { data: rentCatRow, error: rentCatErr } = await supabase
      .from("task_categories")
      .select("id")
      .eq("code", RENT_COLLECTION_CATEGORY_CODE)
      .maybeSingle()

    if (rentCatErr) {
      console.warn("[rent-monitor] CHYBA čtení task_categories (rent_collection):", rentCatErr)
    }
    const rentCollectionCategoryId = (rentCatRow as { id?: string } | null)?.id ?? null
    if (!rentCollectionCategoryId) {
      console.log(
        `[rent-monitor] V task_categories chybí code=${RENT_COLLECTION_CATEGORY_CODE} – service_id u úkolů zůstane null.`,
      )
    }

    const rentCollectionCatalogByTenant = new Map<string, RentCollectionCatalogInfo>()

    for (const apt of list) {
      const aptLabel = `apartment_id=${apt.id} name="${(apt.name ?? "").trim()}"`

      if (!isLeaseActiveToday(today, apt.lease_start_date, apt.lease_end_date)) {
        console.log(`[rent-monitor] SKIP smlouva mimo platnost: ${aptLabel} today=${today}`)
        skipped++
        continue
      }

      const mode = (apt.rent_collection_mode ?? "notification").trim().toLowerCase()
      const runKind = mode === "task" ? "task" : "notification"

      // --- Idempotence: už proběhlo tento měsíc pro tento druh? ---
      const { data: existingRun, error: runSelectErr } = await supabase
        .from("apartment_rent_due_runs")
        .select("id")
        .eq("apartment_id", apt.id)
        .eq("billing_month", billingMonth)
        .eq("run_kind", runKind)
        .maybeSingle()

      if (runSelectErr) {
        console.error(`[rent-monitor] CHYBA čtení apartment_rent_due_runs ${aptLabel}:`, runSelectErr)
        errors++
        continue
      }

      if (existingRun?.id) {
        console.log(
          `[rent-monitor] SKIP již zpracováno (run exists) ${aptLabel} month=${billingMonth} kind=${runKind}`,
        )
        skipped++
        continue
      }

      const amount = parseNum(apt.rent_amount)
      const aptName = (apt.name ?? "").trim() || "Byt"
      /** Formát pro trigger P&L: uuid + ':' + první den měsíce (YYYY-MM-DD). */
      const rentCycleKey = `${apt.id}:${billingMonth}`

      try {
        let createdTaskId: string | null = null

        if (runKind === "notification") {
          const title = "Nájem – kontrola platby"
          const message =
            `Byt „${aptName}“: dnes je den splatnosti nájmu.` +
            (amount > 0 ? ` Částka: ${amount}.` : "") +
            " Zkontrolujte přijatou platbu."

          const ownerIds: string[] = []
          const { data: owners, error: oErr } = await supabase
            .from("apartment_owners")
            .select("owner_id")
            .eq("apartment_id", apt.id)
            .is("deleted_at", null)
          if (oErr) throw oErr
          for (const row of owners ?? []) {
            const oid = (row as { owner_id?: string }).owner_id
            if (oid) ownerIds.push(oid)
          }

          const adminIds: string[] = []
          const { data: admins, error: aErr } = await supabase
            .from("profiles")
            .select("id")
            .eq("tenant_id", apt.tenant_id)
            .in("role", ["admin", "manager"])
            .is("deleted_at", null)
          if (aErr) throw aErr
          for (const row of admins ?? []) {
            const pid = (row as { id?: string }).id
            if (pid) adminIds.push(pid)
          }

          const targetIds = [...new Set([...ownerIds, ...adminIds])]
          console.log(
            `[rent-monitor] Notifikace ${aptLabel} → majitelé=${ownerIds.length} admin/manager=${adminIds.length} cílů=${targetIds.length}`,
          )

          if (targetIds.length === 0) {
            console.log(`[rent-monitor] SKIP notifikace – žádní příjemci ${aptLabel}`)
            skipped++
            continue
          }

          const notifRows = targetIds.map((profile_id) => ({
            tenant_id: apt.tenant_id,
            profile_id,
            title,
            message,
            type: "long_term_rent_due",
            is_read: false,
            metadata: {
              apartment_id: apt.id,
              billing_month: billingMonth,
              kind: "long_term_rent_due",
            },
          }))

          const { error: nErr } = await supabase.from("notifications").insert(notifRows)
          if (nErr) throw nErr
          console.log(`[rent-monitor] OK notifikace zapsány: ${notifRows.length} řádků ${aptLabel}`)
        } else {
          const scheduledStart = nowIsoUtc()
          const taskTitle = `Výběr nájmu – ${aptName}`
          const rentCurrency = rentCurrencyFromApartment(apt)
          const amountLabel = formatRentAmountForUi(amount)
          const taskDescription = "Úkol pro fyzický výběr hotovosti."

          const catalog = await resolveRentCollectionCatalogInfo(
            supabase,
            apt.tenant_id,
            rentCollectionCategoryId,
            rentCollectionCatalogByTenant,
          )
          const catalogRentServiceId = catalog.serviceId

          const apsRows = normalizeApartmentServicesEmbed(apt.apartment_services)
          const rentAps = findApartmentServiceForCatalogId(apsRows, catalogRentServiceId)
          const viaApartmentService = rentAps != null

          const fromAps = (rentAps?.assigned_profile_id ?? "").trim()
          const fromApartment = (apt.rent_task_assignee_id ?? "").trim()
          const assignee = fromAps.length > 0 ? fromAps : fromApartment

          if (!assignee) {
            console.log(
              `[rent-monitor] SKIP task – chybí přiřazení (rent_task_assignee_id${viaApartmentService ? " / apartment_services" : ""}) ${aptLabel}`,
            )
            skipped++
            continue
          }

          const taskServiceId = viaApartmentService ? catalogRentServiceId : null

          const finalServicePrice = viaApartmentService && rentAps != null
            ? finalRentCollectionServicePrice(rentAps.custom_price, catalog.defaultPrice)
            : null
          const taskPayerType = viaApartmentService && rentAps != null
            ? taskPayerTypeOrOwner(rentAps.payer_type ?? undefined)
            : null

          if (viaApartmentService) {
            console.log(
              `[rent-monitor] Úkol rent_collection přes apartment_services service_id=${taskServiceId} amount_to_collect=${finalServicePrice} payer_type=${taskPayerType} ${aptLabel}`,
            )
          } else {
            console.log(
              `[rent-monitor] Úkol rent_collection fallback (bez tasks.service_id) ${aptLabel} aps_rows=${apsRows.length} catalog_id=${catalogRentServiceId ?? "null"}`,
            )
          }

          const metadataObj: Record<string, unknown> = {
            rent_cycle_key: rentCycleKey,
            billing_month: billingMonth,
            long_term_rent_due: true,
            rent_amount: amount,
            transit_amount_to_collect: amount,
            rent_currency: rentCurrency,
            rent_cash_flow: "agency_float",
          }
          if (viaApartmentService && finalServicePrice != null && taskPayerType != null) {
            metadataObj.amount_to_collect = finalServicePrice
            metadataObj.payer_type = taskPayerType
          }

          const payload = {
            tenant_id: apt.tenant_id,
            apartment_id: apt.id,
            assigned_to: assignee,
            task_type: "rent_collection",
            service_id: taskServiceId,
            title: taskTitle,
            description: taskDescription,
            status: "pending",
            scheduled_start: scheduledStart,
            due_date: scheduledStart,
            local_updated_at: scheduledStart,
            metadata: metadataObj,
          }

          const { data: insTask, error: tErr } = await supabase
            .from("tasks")
            .insert(payload)
            .select("id")
            .single()

          if (tErr) throw tErr
          createdTaskId = (insTask as { id?: string })?.id ?? null
          console.log(
            `[rent-monitor] OK úkol rent_collection task_id=${createdTaskId} assignee=${assignee} ${aptLabel} rent_cycle_key=${rentCycleKey}`,
          )

          if (createdTaskId) {
            const { data: insCl, error: clErr } = await supabase
              .from("task_checklists")
              .insert({
                tenant_id: apt.tenant_id,
                task_id: createdTaskId,
                template_id: null,
              })
              .select("id")
              .single()

            if (clErr) {
              await supabase.from("tasks").delete().eq("id", createdTaskId)
              throw clErr
            }
            const checklistId = (insCl as { id?: string })?.id
            if (!checklistId) {
              await supabase.from("tasks").delete().eq("id", createdTaskId)
              throw new Error("task_checklists insert bez id")
            }

            const item1 =
              `Nájem (${amountLabel} ${rentCurrency}) byl úspěšně vybrán od nájemníka.`
            const item2 = "Hotovost uložena do agenturní pokladny / předána."

            const { error: itemsErr } = await supabase.from("task_checklist_items").insert([
              {
                tenant_id: apt.tenant_id,
                task_checklist_id: checklistId,
                title: item1,
                is_photo_required: false,
                sort_order: 0,
              },
              {
                tenant_id: apt.tenant_id,
                task_checklist_id: checklistId,
                title: item2,
                is_photo_required: false,
                sort_order: 1,
              },
            ])

            if (itemsErr) {
              await supabase.from("tasks").delete().eq("id", createdTaskId)
              throw itemsErr
            }
            console.log(
              `[rent-monitor] OK checklist pro task_id=${createdTaskId} checklist_id=${checklistId} (2 položky)`,
            )
          }
        }

        // --- Potvrzení běhu (idempotence) ---
        const runPayload: Record<string, unknown> = {
          tenant_id: apt.tenant_id,
          apartment_id: apt.id,
          billing_month: billingMonth,
          run_kind: runKind,
        }
        if (createdTaskId) runPayload.created_task_id = createdTaskId

        const { error: insRunErr } = await supabase.from("apartment_rent_due_runs").insert(runPayload)

        if (insRunErr) {
          if (insRunErr.code === "23505") {
            console.log(`[rent-monitor] Konflikt UNIQUE při zápisu run (souběh) ${aptLabel} – ignoruji`)
            skipped++
            continue
          }
          throw insRunErr
        }
        console.log(`[rent-monitor] OK záznam apartment_rent_due_runs ${aptLabel} kind=${runKind}`)

        processed++
      } catch (e) {
        console.error(`[rent-monitor] CHYBA zpracování ${aptLabel}:`, e)
        errors++
      }
    }

    console.log(
      `[rent-monitor] === KONEC === processed=${processed} skipped=${skipped} errors=${errors}`,
    )

    return new Response(
      JSON.stringify({
        ok: true,
        today,
        billing_month: billingMonth,
        day_of_month: dom,
        apartments_candidates: list.length,
        processed,
        skipped,
        errors,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  } catch (e) {
    console.error("[rent-monitor] FATÁLNÍ:", e)
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  }
})
