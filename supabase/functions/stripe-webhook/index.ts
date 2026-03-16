declare const Deno: any;

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SERVICE_ROLE_KEY")!;
const stripeWebhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET")!;
const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY")!;

async function verifyStripeSignature(payload: string, sigHeader: string) {
  const elements = sigHeader.split(",");
  const timestamp = elements.find((e) => e.startsWith("t="))?.split("=")[1];
  const signature = elements.find((e) => e.startsWith("v1="))?.split("=")[1];

  if (!timestamp || !signature) return false;

  const signedPayload = `${timestamp}.${payload}`;

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(stripeWebhookSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const digest = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(signedPayload)
  );

  const expected = Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");

  return expected === signature;
}

Deno.serve(async (req: Request): Promise<Response> => {
  try {

    if (req.method === "OPTIONS") {
      return new Response("ok", {
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Headers":
            "authorization, x-client-info, apikey, content-type, stripe-signature",
        },
      });
    }

    const signature = req.headers.get("stripe-signature");

    if (!signature) {
      return new Response("Missing Stripe signature", { status: 400 });
    }

    const body = await req.text();

    const isValid = await verifyStripeSignature(body, signature);

    if (!isValid) {
      return new Response("Invalid Stripe signature", { status: 400 });
    }

    const event = JSON.parse(body);

    console.log("Stripe event:", event.type);

    /* =====================================================
       MARKETPLACE PAYMENT
    ====================================================== */

    if (event.type === "payment_intent.succeeded") {

      try {

        const paymentIntentId = event.data.object.id;

        const paymentRes = await fetch(
          `${supabaseUrl}/rest/v1/payments?stripe_payment_intent_id=eq.${paymentIntentId}&select=request_id,status`,
          {
            headers: {
              apikey: serviceRoleKey,
              Authorization: `Bearer ${serviceRoleKey}`,
            },
          }
        );

        const payments = await paymentRes.json();

        if (payments && payments.length > 0) {

          const payment = payments[0];

          if (payment.status === "paid") {
            return new Response("OK", { status: 200 });
          }

          const requestId = payment.request_id;

          await fetch(
            `${supabaseUrl}/rest/v1/payments?stripe_payment_intent_id=eq.${paymentIntentId}`,
            {
              method: "PATCH",
              headers: {
                apikey: serviceRoleKey,
                Authorization: `Bearer ${serviceRoleKey}`,
                "Content-Type": "application/json",
                Prefer: "return=minimal",
              },
              body: JSON.stringify({
                status: "paid",
              }),
            }
          );

          await fetch(`${supabaseUrl}/rest/v1/ads?id=eq.${requestId}`, {
            method: "PATCH",
            headers: {
              apikey: serviceRoleKey,
              Authorization: `Bearer ${serviceRoleKey}`,
              "Content-Type": "application/json",
              Prefer: "return=minimal",
            },
            body: JSON.stringify({
              status: "paid",
            }),
          });
        }

      } catch (e) {
        console.log("Errore gestione payment_intent:", e);
      }
    }

    /* =====================================================
       PRO SUBSCRIPTION ACTIVATION
    ====================================================== */

    if (event.type === "checkout.session.completed") {

      try {

        const session = event.data.object;

        const userId = session.metadata?.user_id;
        const customerId = session.customer;

        let subscriptionId = session.subscription;

        if (!subscriptionId) {

          const sessionRes = await fetch(
            `https://api.stripe.com/v1/checkout/sessions/${session.id}`,
            {
              headers: {
                Authorization: `Bearer ${stripeSecretKey}`,
              },
            }
          );

          const fullSession = await sessionRes.json();
          subscriptionId = fullSession.subscription;
        }

        if (!userId) {
          return new Response("OK", { status: 200 });
        }

        let expiresAt = null;

        if (subscriptionId) {

          const subscriptionRes = await fetch(
            `https://api.stripe.com/v1/subscriptions/${subscriptionId}`,
            {
              headers: {
                Authorization: `Bearer ${stripeSecretKey}`,
              },
            }
          );

          const subscription = await subscriptionRes.json();

          expiresAt = new Date(
            subscription.current_period_end * 1000
          ).toISOString();
        }

        await fetch(`${supabaseUrl}/rest/v1/profiles?id=eq.${userId}`, {
          method: "PATCH",
          headers: {
            apikey: serviceRoleKey,
            Authorization: `Bearer ${serviceRoleKey}`,
            "Content-Type": "application/json",
            Prefer: "return=minimal",
          },
          body: JSON.stringify({
            is_pro: true,
            subscription_status: "active",
            subscription_expires_at: expiresAt,
            stripe_customer_id: customerId,
          }),
        });

      } catch (e) {
        console.log("Errore gestione PRO checkout:", e);
      }
    }

    /* =====================================================
       SUBSCRIPTION RENEWAL
    ====================================================== */

    if (event.type === "invoice.paid") {

      try {

        const invoice = event.data.object;

        const customerId = invoice.customer;
        const subscriptionId = invoice.subscription;

        if (!customerId) {
          return new Response("OK", { status: 200 });
        }

        let expiresAt = null;

        if (subscriptionId) {

          const subscriptionRes = await fetch(
            `https://api.stripe.com/v1/subscriptions/${subscriptionId}`,
            {
              headers: {
                Authorization: `Bearer ${stripeSecretKey}`,
              },
            }
          );

          const subscription = await subscriptionRes.json();

          expiresAt = new Date(
            subscription.current_period_end * 1000
          ).toISOString();
        }

        const profileRes = await fetch(
          `${supabaseUrl}/rest/v1/profiles?stripe_customer_id=eq.${customerId}&select=id`,
          {
            headers: {
              apikey: serviceRoleKey,
              Authorization: `Bearer ${serviceRoleKey}`,
            },
          }
        );

        const profiles = await profileRes.json();

        if (!profiles || profiles.length === 0) {
          return new Response("OK", { status: 200 });
        }

        const userId = profiles[0].id;

        await fetch(`${supabaseUrl}/rest/v1/profiles?id=eq.${userId}`, {
          method: "PATCH",
          headers: {
            apikey: serviceRoleKey,
            Authorization: `Bearer ${serviceRoleKey}`,
            "Content-Type": "application/json",
            Prefer: "return=minimal",
          },
          body: JSON.stringify({
            is_pro: true,
            subscription_status: "active",
            subscription_expires_at: expiresAt,
          }),
        });

      } catch (e) {
        console.log("Errore rinnovo PRO:", e);
      }
    }

    /* =====================================================
       SUBSCRIPTION CANCEL
    ====================================================== */

    if (event.type === "customer.subscription.deleted") {

      try {

        const subscription = event.data.object;
        const customerId = subscription.customer;

        const profileRes = await fetch(
          `${supabaseUrl}/rest/v1/profiles?stripe_customer_id=eq.${customerId}&select=id`,
          {
            headers: {
              apikey: serviceRoleKey,
              Authorization: `Bearer ${serviceRoleKey}`,
            },
          }
        );

        const profiles = await profileRes.json();

        if (!profiles || profiles.length === 0) {
          return new Response("OK", { status: 200 });
        }

        const userId = profiles[0].id;

        await fetch(`${supabaseUrl}/rest/v1/profiles?id=eq.${userId}`, {
          method: "PATCH",
          headers: {
            apikey: serviceRoleKey,
            Authorization: `Bearer ${serviceRoleKey}`,
            "Content-Type": "application/json",
            Prefer: "return=minimal",
          },
          body: JSON.stringify({
            subscription_status: "canceled",
            is_pro: false,
          }),
        });

      } catch (e) {
        console.log("Errore cancellazione subscription:", e);
      }
    }

    return new Response("OK", {
      status: 200,
      headers: {
        "Access-Control-Allow-Origin": "*",
      },
    });

  } catch (err) {

    console.error("Webhook error:", err);

    return new Response("OK", { status: 200 });

  }
});