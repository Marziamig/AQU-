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

    // ✅ FIX: trasporti basati su service_type
    const isTransport =
      serviceType.includes("trasporto") || serviceType.includes("trasporti")

    let query = supabase
      .from("ads")
      .select("id, user_id, service_type, lat, lng")
      .eq("ad_type", "offer")
      .eq("status", "open")

    // ✅ SERVIZI (NON TOCCATI)
    if (!isTransport && serviceType) {
      query = query.ilike("service_type", `%${serviceType}%`)
    }

    // ✅ TRASPORTI (FIX)
    if (isTransport) {
      query = query.or(
        "service_type.ilike.%trasporto%,service_type.ilike.%trasporti%"
      )
    }

    const { data: offers, error: matchError } = await query

    if (matchError) {
      console.log("MATCH ERROR", matchError)
      return new Response(
        JSON.stringify({ error: "Match error" }),
        { status: 500 }
      )
    }

    const requestLat = requestAd.lat
    const requestLng = requestAd.lng

    const nearbyOffers = (offers || []).filter((offer: any) => {

      if (!offer.lat || !offer.lng || !requestLat || !requestLng) {
        return true
      }

      const R = 6371
      const dLat = (offer.lat - requestLat) * Math.PI / 180
      const dLng = (offer.lng - requestLng) * Math.PI / 180

      const a =
        Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(requestLat * Math.PI / 180) *
        Math.cos(offer.lat * Math.PI / 180) *
        Math.sin(dLng / 2) * Math.sin(dLng / 2)

      const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
      const distance = R * c

      return distance <= 10
    })

    console.log("NEARBY OFFERS:", nearbyOffers)

    if (!nearbyOffers || nearbyOffers.length === 0) {
      console.log("NO OFFERS FOUND")
      return new Response(
        JSON.stringify({
          success: true,
          matches_found: 0
        }),
        { headers: { "Content-Type": "application/json" } }
      )
    }

    const notificationsToInsert: any[] = []

    for (const offer of nearbyOffers) {

      const { data: existing } = await supabase
        .from("notifications")
        .select("id")
        .eq("user_id", offer.user_id)
        .eq("reference_id", requestAd.id)
        .limit(1)

      if (!existing || existing.length === 0) {
        notificationsToInsert.push({
          user_id: offer.user_id,
          title: "Nuova richiesta vicino a te",
          body: isTransport
            ? `Nuova richiesta trasporto`
            : `Nuova richiesta di ${requestAd.service_type}`,
          reference_id: requestAd.id,
          is_read: false
        })
      }
    }

    if (notificationsToInsert.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          matches_found: nearbyOffers.length,
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
        matches_found: nearbyOffers.length,
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