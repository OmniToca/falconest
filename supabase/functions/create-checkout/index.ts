// Setup type definitions for built-in Supabase Runtime APIs
import "@supabase/functions-js/edge-runtime.d.ts"
import Stripe from "npm:stripe"
import {
  edgeCorsHeaders as corsHeaders,
  isSuperAdminRole,
  isTenantAdminOrManager,
  requireUserProfile,
} from "../_shared/edge_auth.ts"

/**
 * Edge funkce pro vytvoření Stripe Checkout Session (předplatné).
 *
 * P0 bezpečnost: vyžaduje JWT admin/manager vlastního tenanta (nebo super_admin).
 * tenant_id z body musí sedět s profilem – nelze vytvořit session pro cizí agenturu.
 *
 * DŮLEŽITÉ: tenant_id se ukládá do subscription_data.metadata – Stripe ho
 * předá do webhooku při úspěšné platbě (webhook musí být ověřený samostatně).
 */
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const auth = await requireUserProfile(req)
    if (!auth.ok) return auth.response

    const { profile } = auth
    const body = await req.json() as {
      tenant_id?: string
      email?: string
      price_id?: string
      success_url?: string
      cancel_url?: string
    }

    const { tenant_id, email, price_id, success_url, cancel_url } = body

    if (
      !tenant_id ||
      !email ||
      !price_id ||
      !success_url ||
      !cancel_url
    ) {
      return new Response(
        JSON.stringify({
          error:
            "Chybí povinná pole: tenant_id, email, price_id, success_url, cancel_url",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      )
    }

    const tid = tenant_id.trim()
    const priceId = price_id.trim()

    // Whitelist formátu Stripe Price ID (price_…).
    if (!/^price_[A-Za-z0-9]+$/.test(priceId)) {
      return new Response(
        JSON.stringify({ error: "Neplatný price_id" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      )
    }

    // Autorizace: super_admin libovolný tenant; admin/manager jen svůj tenant_id.
    if (isSuperAdminRole(profile.role)) {
      // OK
    } else if (
      isTenantAdminOrManager(profile.role) &&
      profile.tenantId != null &&
      profile.tenantId === tid
    ) {
      // OK
    } else {
      return new Response(
        JSON.stringify({
          error: "Nemáte oprávnění vytvořit Checkout pro tuto agenturu",
        }),
        {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      )
    }

    // Volitelný allowlist z env (čárkou oddělené price_…); prázdné = jen formátová kontrola.
    const allowlistRaw = Deno.env.get("STRIPE_ALLOWED_PRICE_IDS")?.trim() ?? ""
    if (allowlistRaw.length > 0) {
      const allowed = new Set(
        allowlistRaw.split(",").map((s) => s.trim()).filter(Boolean),
      )
      if (!allowed.has(priceId)) {
        return new Response(
          JSON.stringify({ error: "price_id není na allowlistu" }),
          {
            status: 403,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        )
      }
    }

    const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY")
    if (!stripeSecretKey) {
      return new Response(
        JSON.stringify({ error: "STRIPE_SECRET_KEY není nastaven" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      )
    }

    const stripe = new Stripe(stripeSecretKey)

    const session = await stripe.checkout.sessions.create({
      mode: "subscription",
      customer_email: email.trim(),
      line_items: [{ price: priceId, quantity: 1 }],
      success_url: success_url.trim(),
      cancel_url: cancel_url.trim(),
      subscription_data: {
        metadata: { tenant_id: tid },
      },
      metadata: {
        tenant_id: tid,
        requested_by_profile_id: profile.id,
      },
    })

    return new Response(
      JSON.stringify({ url: session.url }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    )
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err)
    return new Response(
      JSON.stringify({ error: message }),
      {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    )
  }
})
