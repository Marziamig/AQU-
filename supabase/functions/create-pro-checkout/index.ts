declare const Deno: any;

const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY")!;
const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SERVICE_ROLE_KEY")!;

Deno.serve(async (req: Request) => {
  try {
    if (req.method === "OPTIONS") {
      return new Response("ok", {
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Headers":
            "authorization, x-client-info, apikey, content-type",
        },
      });
    }

    if (req.method !== "POST") {
      return new Response(
        JSON.stringify({ error: "Method not allowed" }),
        { status: 405 }
      );
    }

    const body = await req.json();

    const userId = body.user_id;
    const email = body.email;

    if (!userId || !email) {
      return new Response(
        JSON.stringify({ error: "Missing user data" }),
        { status: 400 }
      );
    }

    // CREAZIONE CUSTOMER STRIPE
    const customerParams = new URLSearchParams();
    customerParams.append("email", email);

    const customerRes = await fetch(
      "https://api.stripe.com/v1/customers",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${stripeSecretKey}`,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: customerParams,
      }
    );

    const customer = await customerRes.json();

    if (!customerRes.ok) {
      return new Response(JSON.stringify(customer), { status: 400 });
    }

    const stripeCustomerId = customer.id;

    // SALVATAGGIO CUSTOMER ID IN PROFILES
    await fetch(
      `${supabaseUrl}/rest/v1/profiles?id=eq.${userId}`,
      {
        method: "PATCH",
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          stripe_customer_id: stripeCustomerId,
        }),
      }
    );

    const params = new URLSearchParams();

    params.append("mode", "payment");

    params.append("success_url", "aqui://pro-success");
    params.append("cancel_url", "aqui://pro-cancel");

    params.append("line_items[0][price_data][currency]", "eur");
    params.append("line_items[0][price_data][product_data][name]", "AQUI PRO");
    params.append("line_items[0][price_data][unit_amount]", "699");
    params.append("line_items[0][quantity]", "1");

    params.append("customer", stripeCustomerId);

    params.append("metadata[user_id]", userId);

    const stripeResponse = await fetch(
      "https://api.stripe.com/v1/checkout/sessions",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${stripeSecretKey}`,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: params,
      }
    );

    const session = await stripeResponse.json();

    if (!stripeResponse.ok) {
      return new Response(JSON.stringify(session), { status: 400 });
    }

    return new Response(
      JSON.stringify({
        url: session.url,
      }),
      {
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
      }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error }),
      { status: 500 }
    );
  }
});