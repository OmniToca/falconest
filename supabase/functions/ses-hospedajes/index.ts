// =============================================================================
// FalcoNest – Edge ses-hospedajes (SOAP SES + poll lote + SLA alert)
// =============================================================================
// Volání: pg_cron každých 15 min přes invoke_ses_hospedajes()
//   Authorization: Bearer SUPABASE_SERVICE_ROLE_KEY
//
// Tok:
//   1) queued PV/RH → SOAP alta (ZIP+Base64) → lote_id → status accepted
//   2) accepted s lote_id → consultaLote → reported | rejected
//   3) timeout pokud lote visí > 6 h; SLA 22:00 Madrid dne příjezdu
//   4) rejected/timeout/draft po deadlinu → notifications adminům (a majitelům)
//
// Env:
//   SES_HOSPEDAJES_URL – default pre-prod
// =============================================================================

import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2"
import JSZip from "npm:jszip@3.10.1"
import { DateTime } from "npm:luxon@3.5.0"
import { requireServiceRoleBearer, jsonError, edgeCorsHeaders } from "../_shared/edge_auth.ts"

const BUSINESS_TZ = "Europe/Madrid"
const DEFAULT_SES_URL =
  "https://hospedajes.pre-ses.mir.es/hospedajes-web/ws/v1/comunicacion"

type GuestRow = {
  id: string
  first_name: string
  last_name: string
  second_last_name: string | null
  birth_date: string | null
  nationality: string | null
  sex: string | null
  document_type: string | null
  document_number: string | null
  document_support: string | null
  address_line: string | null
  address_city: string | null
  address_country: string | null
  phone: string | null
  email: string | null
  is_minor_under_14: boolean
  signed_at: string | null
}

type CommRow = {
  id: string
  tenant_id: string
  reservation_id: string
  guest_checkin_id: string | null
  communication_type: "PV" | "RH"
  operation_type: "A" | "C" | "B"
  lote_id: string | null
  status: string
  attempt_count: number
  created_at: string
}

function xmlEscape(s: string): string {
  return s
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;")
}

function tag(name: string, value: string | null | undefined): string {
  if (value == null || String(value).trim() === "") return ""
  return `<${name}>${xmlEscape(String(value).trim())}</${name}>`
}

function buildPvXml(opts: {
  establishmentCode: string
  referencia: string
  startDate: string
  endDate: string
  paymentType: string
  guests: GuestRow[]
}): string {
  const personas = opts.guests
    .map((g) => {
      const rol = g.is_minor_under_14 ? "ME" : "VI"
      return `<persona>
        ${tag("rol", rol)}
        ${tag("nombre", g.first_name)}
        ${tag("apellido1", g.last_name)}
        ${tag("apellido2", g.second_last_name)}
        ${tag("tipoDocumento", g.document_type)}
        ${tag("numeroDocumento", g.document_number)}
        ${tag("soporteDocumento", g.document_support)}
        ${tag("fechaNacimiento", g.birth_date)}
        ${tag("nacionalidad", g.nationality)}
        ${tag("sexo", g.sex)}
        ${tag("direccion", [g.address_line, g.address_city, g.address_country].filter(Boolean).join(", "))}
        ${tag("telefono", g.phone)}
        ${tag("correo", g.email)}
      </persona>`
    })
    .join("\n")

  return `<?xml version="1.0" encoding="UTF-8"?>
<solicitud>
  ${tag("codigoEstablecimiento", opts.establishmentCode)}
  <comunicacion>
    <contrato>
      ${tag("referencia", opts.referencia)}
      ${tag("fechaContrato", opts.startDate)}
      ${tag("fechaEntrada", opts.startDate)}
      ${tag("fechaSalida", opts.endDate)}
      ${tag("numPersonas", String(opts.guests.length))}
      <pago>${tag("tipo", opts.paymentType)}</pago>
    </contrato>
    ${personas}
  </comunicacion>
</solicitud>`
}

function soapEnvelope(opts: {
  landlordCode: string
  tipoOperacion: string
  tipoComunicacion: string
  payloadB64: string
  action: "comunicacion" | "consultaLote"
  loteId?: string
}): string {
  if (opts.action === "consultaLote") {
    return `<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
  <soapenv:Body>
    <consultaLote>
      <solicitud>
        <cabecera>
          ${tag("arrendador", opts.landlordCode)}
          ${tag("aplicacion", "FALCONEST")}
        </cabecera>
        ${tag("lote", opts.loteId ?? "")}
      </solicitud>
    </consultaLote>
  </soapenv:Body>
</soapenv:Envelope>`
  }
  return `<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
  <soapenv:Body>
    <comunicacion>
      <solicitud>
        <cabecera>
          ${tag("arrendador", opts.landlordCode)}
          ${tag("aplicacion", "FALCONEST")}
          ${tag("tipoOperacion", opts.tipoOperacion)}
          ${tag("tipoComunicacion", opts.tipoComunicacion)}
        </cabecera>
        <cuerpo>
          ${tag("datos", opts.payloadB64)}
        </cuerpo>
      </solicitud>
    </comunicacion>
  </soapenv:Body>
</soapenv:Envelope>`
}

function parseTag(xml: string, name: string): string | null {
  const re = new RegExp(`<(?:[\\w-]+:)?${name}[^>]*>([^<]*)</(?:[\\w-]+:)?${name}>`, "i")
  const m = xml.match(re)
  return m ? m[1].trim() : null
}

async function zipBase64(xml: string): Promise<string> {
  const zip = new JSZip()
  zip.file("comunicacion.xml", xml)
  const buf = await zip.generateAsync({ type: "uint8array", compression: "DEFLATE" })
  let binary = ""
  for (const b of buf) binary += String.fromCharCode(b)
  return btoa(binary)
}

async function soapCall(
  url: string,
  username: string,
  password: string,
  envelope: string,
): Promise<string> {
  const auth = btoa(`${username}:${password}`)
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "text/xml; charset=utf-8",
      SOAPAction: '""',
      Authorization: `Basic ${auth}`,
    },
    body: envelope,
  })
  const text = await res.text()
  if (!res.ok) {
    throw new Error(`SES HTTP ${res.status}: ${text.slice(0, 500)}`)
  }
  return text
}

async function notifyTenant(
  supabase: SupabaseClient,
  tenantId: string,
  apartmentId: string,
  title: string,
  message: string,
  metadata: Record<string, unknown>,
) {
  const ownerIds: string[] = []
  const { data: owners } = await supabase
    .from("apartment_owners")
    .select("owner_id")
    .eq("apartment_id", apartmentId)
    .is("deleted_at", null)
  for (const row of owners ?? []) {
    const oid = (row as { owner_id?: string }).owner_id
    if (oid) ownerIds.push(oid)
  }
  const { data: admins } = await supabase
    .from("profiles")
    .select("id")
    .eq("tenant_id", tenantId)
    .in("role", ["admin", "manager"])
    .is("deleted_at", null)
  const adminIds: string[] = []
  for (const row of admins ?? []) {
    const pid = (row as { id?: string }).id
    if (pid) adminIds.push(pid)
  }
  const targetIds = [...new Set([...ownerIds, ...adminIds])]
  if (targetIds.length === 0) return
  await supabase.from("notifications").insert(
    targetIds.map((profile_id) => ({
      tenant_id: tenantId,
      profile_id,
      title,
      message,
      type: "legal_spain_ses",
      is_read: false,
      metadata,
    })),
  )
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: edgeCorsHeaders })
  }
  const denied = requireServiceRoleBearer(req)
  if (denied) return denied

  const supabaseUrl = Deno.env.get("SUPABASE_URL")
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
  if (!supabaseUrl || !serviceKey) {
    return jsonError(500, "Chybí SUPABASE_URL / SERVICE_ROLE_KEY")
  }
  const sesUrl = (Deno.env.get("SES_HOSPEDAJES_URL") ?? DEFAULT_SES_URL).trim()
  const supabase = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })

  const nowMadrid = DateTime.now().setZone(BUSINESS_TZ)
  const today = nowMadrid.toISODate()!
  let dispatched = 0
  let polled = 0
  let alerted = 0

  try {
    // --- 1) queued → SOAP ---
    const { data: queued, error: qErr } = await supabase
      .from("ses_communications")
      .select("*")
      .eq("status", "queued")
      .limit(40)
    if (qErr) throw qErr

    for (const raw of queued ?? []) {
      const comm = raw as CommRow
      const { data: active } = await supabase.rpc("is_legal_spain_module_active", {
        p_tenant_id: comm.tenant_id,
      })
      if (active !== true) continue

      const { data: resv } = await supabase
        .from("reservations")
        .select("id, apartment_id, start_date, end_date, guest_name, reference_number")
        .eq("id", comm.reservation_id)
        .maybeSingle()
      if (!resv) continue
      const apartmentId = String(resv.apartment_id)

      // PV večer dne příjezdu (od 22:00 Madrid) nebo po dni příjezdu
      if (comm.communication_type === "PV") {
        const start = String(resv.start_date ?? "")
        if (start > today) continue
        if (start === today && nowMadrid.hour < 22) continue
      }

      const { data: settings } = await supabase
        .from("apartment_legal_settings")
        .select("*")
        .eq("apartment_id", apartmentId)
        .maybeSingle()
      const { data: creds } = await supabase
        .from("ses_ws_credentials")
        .select("ws_username, ws_password")
        .eq("apartment_id", apartmentId)
        .maybeSingle()

      const establishment = String(settings?.ses_establishment_code ?? "").trim()
      const landlord = String(settings?.ses_landlord_code ?? "").trim()
      const user = String(creds?.ws_username ?? "").trim()
      const pass = String(creds?.ws_password ?? "")
      if (!establishment || !landlord || !user || !pass) {
        await supabase
          .from("ses_communications")
          .update({
            last_error: "Chybí SES kódy nebo WS heslo u bytu",
            attempt_count: (comm.attempt_count ?? 0) + 1,
            updated_at: new Date().toISOString(),
          })
          .eq("id", comm.id)
        continue
      }

      const { data: guests } = await supabase
        .from("reservation_guests")
        .select("*")
        .eq("reservation_id", comm.reservation_id)

      const guestRows = (guests ?? []) as GuestRow[]
      if (comm.communication_type === "PV") {
        const unsigned = guestRows.filter((g) => !g.is_minor_under_14 && !g.signed_at)
        if (guestRows.length === 0 || unsigned.length > 0) continue
      }

      try {
        const inner = buildPvXml({
          establishmentCode: establishment,
          referencia: String(resv.reference_number ?? resv.id),
          startDate: String(resv.start_date),
          endDate: String(resv.end_date),
          paymentType: String(settings?.default_payment_type ?? "EFECTIVO"),
          guests: guestRows,
        })
        const b64 = await zipBase64(inner)
        const envelope = soapEnvelope({
          landlordCode: landlord,
          tipoOperacion: comm.operation_type,
          tipoComunicacion: comm.communication_type,
          payloadB64: b64,
          action: "comunicacion",
        })
        const responseXml = await soapCall(sesUrl, user, pass, envelope)
        const lote = parseTag(responseXml, "lote") ?? parseTag(responseXml, "loteId")
        const codigo = parseTag(responseXml, "codigo") ?? parseTag(responseXml, "codigoError")
        if (lote && (codigo == null || codigo === "0")) {
          await supabase
            .from("ses_communications")
            .update({
              status: "accepted",
              lote_id: lote,
              request_xml: inner,
              response_xml: responseXml.slice(0, 8000),
              last_error: null,
              attempt_count: (comm.attempt_count ?? 0) + 1,
              updated_at: new Date().toISOString(),
            })
            .eq("id", comm.id)
          if (comm.guest_checkin_id) {
            await supabase
              .from("guest_checkins")
              .update({ status: "accepted", last_error: null, updated_at: new Date().toISOString() })
              .eq("id", comm.guest_checkin_id)
          }
          dispatched++
        } else {
          const err = parseTag(responseXml, "descripcion") ?? responseXml.slice(0, 400)
          await supabase
            .from("ses_communications")
            .update({
              status: "rejected",
              last_error: err,
              response_xml: responseXml.slice(0, 8000),
              attempt_count: (comm.attempt_count ?? 0) + 1,
              updated_at: new Date().toISOString(),
            })
            .eq("id", comm.id)
          if (comm.guest_checkin_id) {
            await supabase
              .from("guest_checkins")
              .update({ status: "rejected", last_error: err, updated_at: new Date().toISOString() })
              .eq("id", comm.guest_checkin_id)
          }
        }
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e)
        await supabase
          .from("ses_communications")
          .update({
            last_error: msg.slice(0, 500),
            attempt_count: (comm.attempt_count ?? 0) + 1,
            updated_at: new Date().toISOString(),
          })
          .eq("id", comm.id)
      }
    }

    // --- 2) poll lote ---
    const { data: accepted } = await supabase
      .from("ses_communications")
      .select("*")
      .eq("status", "accepted")
      .not("lote_id", "is", null)
      .limit(40)

    for (const raw of accepted ?? []) {
      const comm = raw as CommRow
      const { data: resv } = await supabase
        .from("reservations")
        .select("apartment_id")
        .eq("id", comm.reservation_id)
        .maybeSingle()
      if (!resv) continue
      const { data: settings } = await supabase
        .from("apartment_legal_settings")
        .select("ses_landlord_code")
        .eq("apartment_id", resv.apartment_id)
        .maybeSingle()
      const { data: creds } = await supabase
        .from("ses_ws_credentials")
        .select("ws_username, ws_password")
        .eq("apartment_id", resv.apartment_id)
        .maybeSingle()
      const landlord = String(settings?.ses_landlord_code ?? "")
      const user = String(creds?.ws_username ?? "")
      const pass = String(creds?.ws_password ?? "")
      if (!landlord || !user || !pass || !comm.lote_id) continue

      const createdAt = DateTime.fromISO(comm.created_at)
      try {
        const envelope = soapEnvelope({
          landlordCode: landlord,
          tipoOperacion: comm.operation_type,
          tipoComunicacion: comm.communication_type,
          payloadB64: "",
          action: "consultaLote",
          loteId: comm.lote_id,
        })
        const responseXml = await soapCall(sesUrl, user, pass, envelope)
        const estado = (parseTag(responseXml, "estado") ?? parseTag(responseXml, "resultado") ?? "").toLowerCase()
        const commCode = parseTag(responseXml, "codigoComunicacion") ??
          parseTag(responseXml, "codigo")
        const errText = parseTag(responseXml, "descripcion") ?? parseTag(responseXml, "error")

        let next: string | null = null
        if (estado.includes("error") || errText) next = "rejected"
        else if (estado.includes("creat") || estado.includes("ok") || commCode) next = "reported"

        if (!next && createdAt.isValid && DateTime.now().diff(createdAt, "hours").hours >= 6) {
          next = "timeout"
        }
        if (!next) continue

        await supabase
          .from("ses_communications")
          .update({
            status: next,
            communication_code: next === "reported" ? commCode : null,
            last_error: next === "reported" ? null : (errText ?? next),
            response_xml: responseXml.slice(0, 8000),
            processed_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          })
          .eq("id", comm.id)
        if (comm.guest_checkin_id) {
          await supabase
            .from("guest_checkins")
            .update({
              status: next,
              last_error: next === "reported" ? null : (errText ?? next),
              updated_at: new Date().toISOString(),
            })
            .eq("id", comm.guest_checkin_id)
        }
        polled++
      } catch (e) {
        console.error("[ses-hospedajes] poll", comm.id, e)
      }
    }

    // --- 3) SLA + alerty ---
    const { data: checkins } = await supabase
      .from("guest_checkins")
      .select("id, tenant_id, reservation_id, status, last_error, sla_alerted_at, reservations!inner(apartment_id, start_date, guest_name)")
      .in("status", ["draft", "queued", "rejected", "timeout"])
      .limit(100)

    for (const raw of checkins ?? []) {
      const row = raw as {
        id: string
        tenant_id: string
        reservation_id: string
        status: string
        last_error: string | null
        sla_alerted_at: string | null
        reservations?: { apartment_id?: string; start_date?: string; guest_name?: string }
      }
      if (row.sla_alerted_at) continue
      const start = String(row.reservations?.start_date ?? "")
      const needsSla =
        (start === today && nowMadrid.hour >= 22 && (row.status === "draft" || row.status === "queued")) ||
        row.status === "rejected" ||
        row.status === "timeout"
      if (!needsSla) continue

      const aptId = String(row.reservations?.apartment_id ?? "")
      const guest = String(row.reservations?.guest_name ?? "")
      const reason = row.last_error ?? row.status
      await notifyTenant(
        supabase,
        row.tenant_id,
        aptId,
        "SES Hospedajes – akce nutná",
        `Pobyt ${guest}: stav ${row.status}. ${reason}`,
        { reservation_id: row.reservation_id, guest_checkin_id: row.id, status: row.status },
      )
      await supabase
        .from("guest_checkins")
        .update({ sla_alerted_at: new Date().toISOString(), updated_at: new Date().toISOString() })
        .eq("id", row.id)
      alerted++
    }

    return new Response(
      JSON.stringify({ ok: true, dispatched, polled, alerted }),
      { headers: { ...edgeCorsHeaders, "Content-Type": "application/json" } },
    )
  } catch (e) {
    console.error("[ses-hospedajes]", e)
    return jsonError(500, e instanceof Error ? e.message : String(e))
  }
})
