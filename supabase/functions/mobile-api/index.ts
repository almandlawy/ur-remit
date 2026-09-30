const supabaseURL = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const publicHeaders = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "public, max-age=30, stale-while-revalidate=120",
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, apikey, content-type",
};

const privateHeaders = { ...publicHeaders, "cache-control": "no-store" };

function response(data: unknown, status = 200, isPrivate = false) {
  return new Response(JSON.stringify(status < 400 ? { data } : { error: data }), {
    status,
    headers: isPrivate ? privateHeaders : publicHeaders,
  });
}

async function rest(path: string, init: RequestInit = {}) {
  const result = await fetch(`${supabaseURL}/rest/v1/${path}`, {
    ...init,
    headers: {
      apikey: serviceKey,
      authorization: `Bearer ${serviceKey}`,
      "content-type": "application/json",
      prefer: "return=representation",
      ...init.headers,
    },
  });
  if (!result.ok) throw new Error(`database_${result.status}`);
  if (result.status === 204) return null;
  return result.json();
}

function routeFrom(url: URL) {
  const segments = url.pathname.split("/").filter(Boolean);
  const route = segments.slice(segments.indexOf("mobile-api") + 1).join("/");
  return route.replace(/^api\/v1\/mobile\//, "").replace(/^api\/v1\/admin\//, "admin/");
}

function base64URL(bytes: Uint8Array) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function decodeBase64URL(value: string) {
  const padded = value.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(value.length / 4) * 4, "=");
  return Uint8Array.from(atob(padded), (character) => character.charCodeAt(0));
}

async function sha256(value: string) {
  return Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value))))
    .map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function verifyPassword(password: string, encoded: string) {
  const [algorithm, costText, blockText, parallelText, saltText, expectedText] = encoded.split("$");
  if (algorithm !== "scrypt" || !saltText || !expectedText) return false;
  const { scryptAsync } = await import("npm:@noble/hashes@1.8.0/scrypt");
  const expected = decodeBase64URL(expectedText);
  const actual = await scryptAsync(new TextEncoder().encode(password), decodeBase64URL(saltText), {
    N: Number(costText), r: Number(blockText), p: Number(parallelText), dkLen: expected.length,
  });
  if (actual.length !== expected.length) return false;
  let difference = 0;
  for (let index = 0; index < actual.length; index += 1) difference |= actual[index]! ^ expected[index]!;
  return difference === 0;
}

function bearerToken(request: Request) {
  const value = request.headers.get("authorization");
  const token = value?.startsWith("Bearer ") ? value.slice(7) : "";
  return /^[A-Za-z0-9_-]{32,256}$/.test(token) ? token : null;
}

async function authenticate(request: Request) {
  const token = bearerToken(request);
  if (!token) return null;
  return await rest("rpc/admin_authenticate", {
    method: "POST",
    body: JSON.stringify({ p_token_hash: await sha256(token) }),
  }) as { id?: string; role?: string; permissions?: string[] } | null;
}

async function readJSON(request: Request) {
  try { return await request.json() as Record<string, unknown>; }
  catch { return null; }
}

function validDecimal(value: unknown) {
  return value === null || (typeof value === "string" && /^-?\d{1,16}(\.\d{1,8})?$/.test(value));
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: publicHeaders });

  const url = new URL(request.url);
  const route = routeFrom(url);

  try {
    if (route === "health" && request.method === "GET") return response({ status: "ok", database: "ok", version: "v1" });

    if (route === "admin/auth/login" && request.method === "POST") {
      const body = await readJSON(request);
      const username = typeof body?.username === "string" ? body.username.trim() : "";
      const password = typeof body?.password === "string" ? body.password : "";
      if (!/^[A-Za-z0-9@._-]{4,254}$/.test(username) || password.length < 10 || password.length > 256)
        return response("INVALID_INPUT", 400, true);
      const users = await rest(`admin_users?select=id,password_hash,failed_login_count,locked_until&or=(username.ilike.${encodeURIComponent(username)},email.ilike.${encodeURIComponent(username)})&disabled_at=is.null&limit=1`) as Array<Record<string, unknown>>;
      const user = users[0];
      const isLocked = Boolean(user?.locked_until && Date.parse(String(user.locked_until)) > Date.now());
      if (!user || isLocked || !(await verifyPassword(password, String(user.password_hash)))) {
        if (user?.id && !isLocked) {
          const failedCount = Number(user.failed_login_count ?? 0) + 1;
          await rest(`admin_users?id=eq.${user.id}`, {
            method: "PATCH",
            body: JSON.stringify({
              failed_login_count: failedCount,
              ...(failedCount >= 5 ? { locked_until: new Date(Date.now() + 15 * 60_000).toISOString() } : {}),
            }),
          });
        }
        return response("INVALID_CREDENTIALS", 401, true);
      }
      const token = base64URL(crypto.getRandomValues(new Uint8Array(32)));
      const expiresAt = new Date(Date.now() + 30 * 60_000).toISOString();
      await rest("admin_sessions", { method: "POST", body: JSON.stringify({
        admin_user_id: user.id,
        token_hash: await sha256(token),
        mfa_verified_at: null,
        expires_at: expiresAt,
        user_agent_fingerprint: request.headers.get("user-agent") ? await sha256(request.headers.get("user-agent")!) : null,
      }) });
      await rest(`admin_users?id=eq.${user.id}`, { method: "PATCH", body: JSON.stringify({ failed_login_count: 0, locked_until: null, last_login_at: new Date().toISOString() }) });
      return response({ token, expiresAt }, 200, true);
    }

    if (route === "admin/auth/logout" && request.method === "POST") {
      const token = bearerToken(request);
      const actor = await authenticate(request);
      if (!token || !actor?.id) return response("UNAUTHORIZED", 401, true);
      await rest(`admin_sessions?token_hash=eq.${await sha256(token)}&revoked_at=is.null`, {
        method: "PATCH",
        body: JSON.stringify({ revoked_at: new Date().toISOString() }),
      });
      return response({ success: true }, 200, true);
    }

    if (route === "admin/dashboard" && request.method === "GET") {
      const actor = await authenticate(request);
      if (!actor?.permissions?.includes("dashboard.read")) return response("UNAUTHORIZED", 401, true);
      return response(await rest("rpc/admin_dashboard_metrics", { method: "POST", body: "{}" }), 200, true);
    }

    const rateMatch = route.match(/^admin\/rates\/([0-9a-f-]{36})$/i);
    if (rateMatch && request.method === "PATCH") {
      const actor = await authenticate(request);
      if (!actor?.id) return response("UNAUTHORIZED", 401, true);
      if (!actor.permissions?.includes("rates.write")) return response("FORBIDDEN", 403, true);
      const body = await readJSON(request);
      if (!body || !validDecimal(body.buy) || !validDecimal(body.sell) || !validDecimal(body.feeFixed))
        return response("INVALID_INPUT", 400, true);
      const isValidRequestID = (value: unknown): value is string =>
        typeof value === "string" &&
        /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
      if (body.requestId !== undefined && !isValidRequestID(body.requestId))
        return response("INVALID_INPUT", 400, true);
      const requestID = body.requestId ?? crypto.randomUUID();
      const updated = await rest("rpc/admin_update_rate", { method: "POST", body: JSON.stringify({
        p_actor_id: actor.id,
        p_rate_id: rateMatch[1],
        p_buy: body.buy,
        p_sell: body.sell,
        p_fee_fixed: body.feeFixed,
        p_request_id: requestID,
      }) });
      return updated ? response(updated, 200, true) : response("RATE_UNAVAILABLE", 404, true);
    }

    if (route === "rates" && request.method === "GET") {
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

    if (route === "offices" && request.method === "GET") {
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

    if (route === "countries" && request.method === "GET") return response(await rest("countries?select=id,isoCode:iso_code,nameArabic:name_ar,nameEnglish:name_en&is_active=eq.true&order=name_en"));
    if (route === "cities" && request.method === "GET") return response(await rest("cities?select=id,nameArabic:name_ar,nameEnglish:name_en,countries!inner(isoCode:iso_code)&is_active=eq.true&order=name_en"));
    if (route === "routes" && request.method === "GET") return response(await rest("rate_routes?select=id,nameArabic:name_ar,nameEnglish:name_en,sourceCurrency:source_currency,destinationCurrency:destination_currency&is_active=eq.true&order=name_en"));
    if (route === "notices" && request.method === "GET") return response(await rest("announcements?select=id,titleArabic:title_ar,titleEnglish:title_en,bodyArabic:body_ar,bodyEnglish:body_en,kind,publishedAt:published_at,expiresAt:expires_at&is_active=eq.true&order=published_at.desc"));
    if (route === "app-config" && request.method === "GET") {
      const rows = await rest("app_config?select=key,value&is_public=eq.true&order=key");
      return response(Object.fromEntries(rows.map((row: any) => [row.key, row.value])));
    }
    return response(request.method === "GET" ? "NOT_FOUND" : "METHOD_NOT_ALLOWED", request.method === "GET" ? 404 : 405);
  } catch (error) {
    console.error(error);
    return response("SERVICE_UNAVAILABLE", 503);
  }
});
