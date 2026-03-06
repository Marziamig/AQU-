declare const Deno: any;

const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY")!;

Deno.serve(async (req: Request) => {
  try {
    const body = await req.json();
    const customerId = body.customer_id;

    if (!customerId) {
      return new Response(
        JSON.stringify({ error: "Missing customer_id" }),
        { status: 400 }
      );
    }

    const params = new URLSearchParams();
    params.append("customer", customerId);
    params.append("return_url", "https://aqui.app/home");

    const stripeResponse = await fetch(
      "https://api.stripe.com/v1/billing_portal/sessions",
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
    return new Response(JSON.stringify({ error }), { status: 500 });
  }
});