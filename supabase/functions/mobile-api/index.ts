const supabaseURL = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const headers = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "public, max-age=30, stale-while-revalidate=120",
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, apikey, content-type",
};

function response(data: unknown, status = 200) {
  return new Response(JSON.stringify(status < 400 ? { data } : { error: data }), { status, headers });
}

async function rest(path: string) {
  const result = await fetch(`${supabaseURL}/rest/v1/${path}`, {
    headers: { apikey: serviceKey, authorization: `Bearer ${serviceKey}` },
  });
  if (!result.ok) throw new Error(`database_${result.status}`);
  return result.json();
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers });
  if (request.method !== "GET") return response("METHOD_NOT_ALLOWED", 405);

  const url = new URL(request.url);
  const segments = url.pathname.split("/").filter(Boolean);
  const route = segments.slice(segments.indexOf("mobile-api") + 1).join("/");

  try {
    if (route === "health") return response({ status: "ok", database: "ok", version: "v1" });

    if (route === "rates") {
      const rows = await rest("rates?select=id,buy,sell,fee_fixed,fee_percent,created_at,source_timestamp,version,valid_from,valid_until,rate_routes!inner(name_ar,name_en,source_currency,destination_currency,is_active)&is_active=eq.true&rate_routes.is_active=eq.true&order=source_timestamp.desc");
      return response(rows.map((row: any) => ({
        id: row.id,
        routeNameArabic: row.rate_routes.name_ar,
        routeNameEnglish: row.rate_routes.name_en,
        sourceCurrency: row.rate_routes.source_currency,
        destinationCurrency: row.rate_routes.destination_currency,
        buy: row.buy,
        sell: row.sell,
        feeFixed: row.fee_fixed,
        feePercent: row.fee_percent,
        updatedAt: row.created_at,
        sourceTimestamp: row.source_timestamp,
        version: row.version,
        validFrom: row.valid_from,
        validUntil: row.valid_until,
        staleAfter: new Date(new Date(row.source_timestamp).getTime() + 15 * 60_000).toISOString(),
      })));
    }

    if (route === "offices") {
      const rows = await rest("offices?select=id,public_code,name_ar,name_en,address_ar,address_en,latitude,longitude,phone,whatsapp,working_hours,services,is_verified,countries!inner(name_ar,name_en),cities!inner(name_ar,name_en)&is_active=eq.true&is_verified=eq.true&order=name_en");
      return response(rows.map((row: any) => ({
        id: row.id, publicCode: row.public_code,
        nameArabic: row.name_ar, nameEnglish: row.name_en,
        countryArabic: row.countries.name_ar, countryEnglish: row.countries.name_en,
        cityArabic: row.cities.name_ar, cityEnglish: row.cities.name_en,
        addressArabic: row.address_ar, addressEnglish: row.address_en,
        latitude: row.latitude, longitude: row.longitude,
        phone: row.phone, whatsapp: row.whatsapp,
        workingHours: row.working_hours, services: row.services, verified: row.is_verified,
      })));
    }

    if (route === "countries") return response(await rest("countries?select=id,isoCode:iso_code,nameArabic:name_ar,nameEnglish:name_en&is_active=eq.true&order=name_en"));
    if (route === "cities") return response(await rest("cities?select=id,nameArabic:name_ar,nameEnglish:name_en,countries!inner(isoCode:iso_code)&is_active=eq.true&order=name_en"));
    if (route === "routes") return response(await rest("rate_routes?select=id,nameArabic:name_ar,nameEnglish:name_en,sourceCurrency:source_currency,destinationCurrency:destination_currency&is_active=eq.true&order=name_en"));
    if (route === "notices") return response(await rest("announcements?select=id,titleArabic:title_ar,titleEnglish:title_en,bodyArabic:body_ar,bodyEnglish:body_en,kind,publishedAt:published_at,expiresAt:expires_at&is_active=eq.true&order=published_at.desc"));
    if (route === "app-config") {
      const rows = await rest("app_config?select=key,value&is_public=eq.true&order=key");
      return response(Object.fromEntries(rows.map((row: any) => [row.key, row.value])));
    }
    return response("NOT_FOUND", 404);
  } catch {
    return response("SERVICE_UNAVAILABLE", 503);
  }
});
