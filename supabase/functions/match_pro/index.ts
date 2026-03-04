import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import "@supabase/functions-js/edge-runtime.d.ts"

Deno.serve(async (req) => {
  try {
    const { ad_id } = await req.json()

    if (!ad_id) {
      return new Response(
        JSON.stringify({ error: "Missing ad_id" }),
        { status: 400 }
      )
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    )

    // 1️⃣ Recuperiamo la richiesta
    const { data: requestAd, error: requestError } = await supabase
      .from("ads")
      .select("*")
      .eq("id", ad_id)
      .single()

    if (requestError || !requestAd) {
      return new Response(
        JSON.stringify({ error: "Request not found" }),
        { status: 404 }
      )
    }

    if (requestAd.ad_type !== "request") {
      return new Response(
        JSON.stringify({ error: "Not a request" }),
        { status: 400 }
      )
    }

    // Determiniamo tipo servizio
    const serviceType = requestAd.service_type ?? null
    const zone = requestAd.from_location ?? requestAd.zone ?? null

    if (!serviceType || !zone) {
      return new Response(
        JSON.stringify({ error: "Missing matching fields" }),
        { status: 400 }
      )
    }

    // 2️⃣ Troviamo PRO compatibili
    const { data: matchingPros, error: matchError } = await supabase
      .from("profiles")
      .select("id, full_name")
      .eq("is_pro", true)
      .eq("is_deleted", false)
      .eq("pro_service_type", serviceType)
      .ilike("zone", zone)

    if (matchError) {
      return new Response(
        JSON.stringify({ error: "Match error" }),
        { status: 500 }
      )
    }

    if (!matchingPros || matchingPros.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          matches_found: 0
        }),
        { headers: { "Content-Type": "application/json" } }
      )
    }

    // 3️⃣ Evitiamo notifiche duplicate
    const { data: existingNotifications } = await supabase
      .from("notifications")
      .select("user_id")
      .eq("request_id", requestAd.id)

    const alreadyNotifiedIds = existingNotifications?.map(n => n.user_id) || []

    const notificationsToInsert = matchingPros
      .filter(pro => !alreadyNotifiedIds.includes(pro.id))
      .map((pro) => ({
        user_id: pro.id,
        request_id: requestAd.id,
        message: `Nuova richiesta di ${serviceType} in zona ${zone}`,
        is_read: false,
        created_at: new Date().toISOString()
      }))

    if (notificationsToInsert.length > 0) {
      const { error: insertError } = await supabase
        .from("notifications")
        .insert(notificationsToInsert)

      if (insertError) {
        return new Response(
          JSON.stringify({ error: "Notification insert error" }),
          { status: 500 }
        )
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        matches_found: matchingPros.length,
        notifications_created: notificationsToInsert.length
      }),
      { headers: { "Content-Type": "application/json" } }
    )

  } catch (err) {
    return new Response(
      JSON.stringify({ error: "Server error" }),
      { status: 500 }
    )
  }
})
