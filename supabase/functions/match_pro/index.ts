import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

Deno.serve(async (req) => {
  try {
    const body = await req.json()
    const ad_id = body?.ad_id

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

    const { data: requestAd, error: requestError } = await supabase
      .from("ads")
      .select("*")
      .eq("id", ad_id)
      .single()

    if (requestError || !requestAd) {
      console.log("REQUEST NOT FOUND", requestError)
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

    const serviceType = requestAd.service_type?.toLowerCase() || ""
    const zone = requestAd.from_location?.toLowerCase() || ""

    let query = supabase
      .from("profiles")
      .select("id, full_name")
      .eq("is_pro", true)
      .eq("is_deleted", false)

    if (serviceType) {
      query = query.ilike("pro_service_type", serviceType)
    }

    if (zone) {
      query = query.ilike("zone", zone)
    }

    const { data: matchingPros, error: matchError } = await query

    if (matchError) {
      console.log("MATCH ERROR", matchError)
      return new Response(
        JSON.stringify({ error: "Match error" }),
        { status: 500 }
      )
    }

    if (!matchingPros || matchingPros.length === 0) {
      console.log("NO PRO FOUND")
      return new Response(
        JSON.stringify({
          success: true,
          matches_found: 0
        }),
        { headers: { "Content-Type": "application/json" } }
      )
    }

    const notificationsToInsert: any[] = []

    for (const pro of matchingPros) {

      const { data: existing } = await supabase
        .from("notifications")
        .select("id")
        .eq("user_id", pro.id)
        .eq("reference_id", requestAd.id)
        .limit(1)

      if (!existing || existing.length === 0) {
        notificationsToInsert.push({
          user_id: pro.id,
          title: "Nuova richiesta vicino a te",
          body: `Nuova richiesta di ${requestAd.service_type}`,
          reference_id: requestAd.id,
          is_read: false
        })
      }
    }

    if (notificationsToInsert.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          matches_found: matchingPros.length,
          notifications_created: 0
        }),
        { headers: { "Content-Type": "application/json" } }
      )
    }

    const { error: insertError } = await supabase
      .from("notifications")
      .insert(notificationsToInsert)

    if (insertError) {
      console.log("INSERT ERROR", insertError)
      return new Response(
        JSON.stringify({ error: "Notification insert error" }),
        { status: 500 }
      )
    }

    return new Response(
      JSON.stringify({
        success: true,
        matches_found: matchingPros.length,
        notifications_created: notificationsToInsert.length
      }),
      { headers: { "Content-Type": "application/json" } }
    )

  } catch (err: any) {
    console.log("SERVER ERROR", err)

    return new Response(
      JSON.stringify({
        error: "Server error",
        details: err?.message || "unknown"
      }),
      { status: 500 }
    )
  }
})