declare const Deno: any;

const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY")!;

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

    const params = new URLSearchParams();

    params.append("mode", "payment");
    params.append("success_url", "https://aqui.app/pro-success");
    params.append("cancel_url", "https://aqui.app/pro-cancel");

    params.append("line_items[0][price_data][currency]", "eur");
    params.append("line_items[0][price_data][product_data][name]", "AQUI PRO");
    params.append("line_items[0][price_data][unit_amount]", "699");
    params.append("line_items[0][quantity]", "1");

    params.append("customer_email", email);
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