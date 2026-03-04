// Supabase Edge Function - Create Stripe Payment

import "@supabase/functions-js/edge-runtime.d.ts";

declare const Deno: any;

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SERVICE_ROLE_KEY")!;

Deno.serve(async (req: Request): Promise<Response> => {
  try {
    if (req.method !== "POST") {
      return new Response(
        JSON.stringify({ error: "Method not allowed" }),
        { status: 405 }
      );
    }

    const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY");
    if (!stripeSecretKey) {
      return new Response(
        JSON.stringify({ error: "Stripe secret key not configured" }),
        { status: 500 }
      );
    }

    if (!serviceRoleKey) {
      return new Response(
        JSON.stringify({ error: "Service role key not configured" }),
        { status: 500 }
      );
    }

    const body = await req.json();

    const amount = body.amount;
    const currency = body.currency ?? "eur";
    const requestId = body.request_id;
    const requestType = body.request_type; // "service" o "transport"

    if (!amount || typeof amount !== "number" || amount <= 0) {
      return new Response(
        JSON.stringify({ error: "Invalid amount" }),
        { status: 400 }
      );
    }

    if (!requestId || !requestType) {
      return new Response(
        JSON.stringify({ error: "Missing request_id or request_type" }),
        { status: 400 }
      );
    }

    // 🔒 Controllo se esiste già un pagamento completato
    const existingPaymentRes = await fetch(
      `${supabaseUrl}/rest/v1/payments?request_id=eq.${requestId}&status=eq.paid`,
      {
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
        },
      }
    );

    const existingPayments = await existingPaymentRes.json();

    if (existingPayments.length > 0) {
      return new Response(
        JSON.stringify({ error: "Payment already completed" }),
        { status: 400 }
      );
    }

    const params = new URLSearchParams();
    params.append("amount", amount.toString());
    params.append("currency", currency);
    params.append("automatic_payment_methods[enabled]", "true");

    const stripeResponse = await fetch(
      "https://api.stripe.com/v1/payment_intents",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${stripeSecretKey}`,
          "Content-Type": "application/x-www-form-urlencoded",
          "Stripe-Version": "2023-10-16",
        },
        body: params,
      }
    );

    const paymentIntent = await stripeResponse.json();

    if (!stripeResponse.ok) {
      return new Response(
        JSON.stringify({ error: paymentIntent }),
        { status: stripeResponse.status }
      );
    }

    // 🔐 Salvataggio pagamento in tabella payments (status = pending)
    await fetch(`${supabaseUrl}/rest/v1/payments`, {
      method: "POST",
      headers: {
        apikey: serviceRoleKey,
        Authorization: `Bearer ${serviceRoleKey}`,
        "Content-Type": "application/json",
        Prefer: "return=minimal",
      },
      body: JSON.stringify({
        request_id: requestId,
        request_type: requestType,
        amount: amount / 100,
        stripe_payment_intent_id: paymentIntent.id,
        status: "pending",
      }),
    });

    return new Response(
      JSON.stringify({
        clientSecret: paymentIntent.client_secret,
      }),
      {
        headers: { "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error }),
      { status: 500 }
    );
  }
});
