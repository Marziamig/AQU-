// Supabase Edge Function - Delete Account + Cancel Stripe Subscription

declare const Deno: any;

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SERVICE_ROLE_KEY")!;
const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY")!;

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
      return new Response(
        JSON.stringify({ error: "Method not allowed" }),
        { status: 405 }
      );
    }

    const body = await req.json();
    const userId = body.user_id;

    if (!userId) {
      return new Response(
        JSON.stringify({ error: "Missing user_id" }),
        { status: 400 }
      );
    }

    // Recuperiamo il customer Stripe
    const profileRes = await fetch(
      `${supabaseUrl}/rest/v1/profiles?id=eq.${userId}&select=stripe_customer_id`,
      {
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
        },
      }
    );

    const profiles = await profileRes.json();

    if (profiles.length > 0) {
      const customerId = profiles[0].stripe_customer_id;

      if (customerId) {
        // Recuperiamo le subscription Stripe
        const subRes = await fetch(
          `https://api.stripe.com/v1/subscriptions?customer=${customerId}`,
          {
            headers: {
              Authorization: `Bearer ${stripeSecretKey}`,
            },
          }
        );

        const subs = await subRes.json();

        if (subs.data && subs.data.length > 0) {
          const subscriptionId = subs.data[0].id;

          await fetch(
            `https://api.stripe.com/v1/subscriptions/${subscriptionId}`,
            {
              method: "DELETE",
              headers: {
                Authorization: `Bearer ${stripeSecretKey}`,
              },
            }
          );
        }
      }
    }

    // Soft delete profilo
    await fetch(`${supabaseUrl}/rest/v1/profiles?id=eq.${userId}`, {
      method: "PATCH",
      headers: {
        apikey: serviceRoleKey,
        Authorization: `Bearer ${serviceRoleKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        is_deleted: true,
        is_pro: false,
        subscription_status: "inactive",
      }),
    });

    // Eliminiamo annunci
    await fetch(`${supabaseUrl}/rest/v1/ads?user_id=eq.${userId}`, {
      method: "DELETE",
      headers: {
        apikey: serviceRoleKey,
        Authorization: `Bearer ${serviceRoleKey}`,
      },
    });

    return new Response(
      JSON.stringify({ success: true }),
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