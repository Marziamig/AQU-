declare const Deno: any;

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SERVICE_ROLE_KEY")!;
const stripeWebhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET")!;

function timingSafeEqual(a: string, b: string) {
  if (a.length !== b.length) return false;
  let result = 0;
  for (let i = 0; i < a.length; i++) {
    result |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return result === 0;
}

async function verifyStripeSignature(
  payload: string,
  header: string,
  secret: string
) {
  const elements = header.split(",");
  const timestamp = elements.find((e) => e.startsWith("t="))?.split("=")[1];
  const signature = elements.find((e) => e.startsWith("v1="))?.split("=")[1];

  if (!timestamp || !signature) return false;

  const encoder = new TextEncoder();
  const signedPayload = `${timestamp}.${payload}`;

  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signatureBuffer = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(signedPayload)
  );

  const expectedSignature = Array.from(new Uint8Array(signatureBuffer))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");

  return timingSafeEqual(expectedSignature, signature);
}

Deno.serve(async (req: Request): Promise<Response> => {
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
      return new Response("Method not allowed", { status: 405 });
    }

    if (!serviceRoleKey || !stripeWebhookSecret) {
      return new Response("Environment variables not configured", {
        status: 500,
      });
    }

    const signatureHeader = req.headers.get("stripe-signature");
    if (!signatureHeader) {
      return new Response("Missing Stripe signature", { status: 400 });
    }

    const body = await req.text();

    const isValid = await verifyStripeSignature(
      body,
      signatureHeader,
      stripeWebhookSecret
    );

    if (!isValid) {
      return new Response("Invalid signature", { status: 400 });
    }

    const event = JSON.parse(body);

    // PAGAMENTO SERVIZI
    if (event.type === "payment_intent.succeeded") {
      const paymentIntentId = event.data.object.id;

      const paymentRes = await fetch(
        `${supabaseUrl}/rest/v1/payments?stripe_payment_intent_id=eq.${paymentIntentId}&select=request_id`,
        {
          headers: {
            apikey: serviceRoleKey,
            Authorization: `Bearer ${serviceRoleKey}`,
          },
        }
      );

      const payments = await paymentRes.json();

      if (!payments.length) {
        return new Response("Payment not found", { status: 400 });
      }

      const requestId = payments[0].request_id;

      await fetch(
        `${supabaseUrl}/rest/v1/payments?stripe_payment_intent_id=eq.${paymentIntentId}`,
        {
          method: "PATCH",
          headers: {
            apikey: serviceRoleKey,
            Authorization: `Bearer ${serviceRoleKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            status: "paid",
          }),
        }
      );

      await fetch(
        `${supabaseUrl}/rest/v1/ads?id=eq.${requestId}`,
        {
          method: "PATCH",
          headers: {
            apikey: serviceRoleKey,
            Authorization: `Bearer ${serviceRoleKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            status: "paid",
          }),
        }
      );
    }

    // ABBONAMENTO PRO
    if (event.type === "checkout.session.completed") {
      const session = event.data.object;

      const userId = session.metadata?.user_id;

      if (!userId) {
        console.log("user_id mancante nei metadata Stripe");
        return new Response("No user id", { status: 200 });
      }

      const expirationDate = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);

      const res = await fetch(
        `${supabaseUrl}/rest/v1/profiles?id=eq.${userId}`,
        {
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
            subscription_expires_at: expirationDate.toISOString(),
          }),
        }
      );

      if (!res.ok) {
        const errorText = await res.text();
        console.error("Errore aggiornamento PRO:", errorText);
      } else {
        console.log("Utente aggiornato a PRO:", userId);
      }
    }

    return new Response("OK", {
      status: 200,
      headers: {
        "Access-Control-Allow-Origin": "*",
      },
    });
  } catch (err) {
    return new Response(`Webhook error: ${err}`, { status: 400 });
  }
});