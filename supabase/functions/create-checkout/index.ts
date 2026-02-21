// Setup type definitions for built-in Supabase Runtime APIs
import "@supabase/functions-js/edge-runtime.d.ts"
import Stripe from "npm:stripe"

/**
 * CORS hlavičky pro volání z prohlížeče.
 * Access-Control-Allow-Origin: * umožňuje požadavky z jakékoliv domény.
 * Preflight (OPTIONS) musí vrátit tyto hlavičky, jinak prohlížeč požadavek zablokuje.
 */
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
}

/**
 * Edge funkce pro vytvoření Stripe Checkout Session (předplatné).
 *
 * Prohlížeč pošle POST s JSON tělem obsahujícím tenant_id, email, price_id,
 * success_url a cancel_url. Funkce vytvoří Stripe session a vrátí URL pro přesměrování.
 *
 * DŮLEŽITÉ: tenant_id se ukládá do subscription_data.metadata – Stripe ho
 * předá do webhooku při úspěšné platbě, takže můžeme propojit předplatné s agenturou.
 */
Deno.serve(async (req) => {
  // CORS preflight – prohlížeč posílá OPTIONS před vlastním POST
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
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

    // Inicializace Stripe klienta – v Deno používáme npm: prefix
    const stripe = new Stripe(stripeSecretKey)

    /**
     * Vytvoření Checkout Session v režimu předplatného.
     * - mode: 'subscription' – Stripe vytvoří recurring payment
     * - customer_email – Stripe pošle fakturační e-mail na tuto adresu
     * - line_items – ceníková položka (price_id z Stripe Dashboard)
     * - subscription_data.metadata – KRITICKÉ: tenant_id se propíše do
     *   eventu checkout.session.completed a customer.subscription.created,
     *   takže webhook může přiřadit předplatné ke konkrétní agentuře.
     */
    const session = await stripe.checkout.sessions.create({
      mode: "subscription",
      customer_email: email,
      line_items: [{ price: price_id, quantity: 1 }],
      success_url,
      cancel_url,
      subscription_data: {
        metadata: { tenant_id },
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
