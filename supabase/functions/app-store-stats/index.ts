import { importPKCS8, SignJWT } from "npm:jose@6.1.0";

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" },
});

Deno.serve(async (request) => {
  if (request.method !== "GET") return json({ error: "method_not_allowed" }, 405);

  const adminToken = Deno.env.get("APP_STATS_ADMIN_TOKEN");
  const supplied = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "");
  if (!adminToken || supplied !== adminToken) return json({ error: "unauthorized" }, 401);

  const issuer = Deno.env.get("APP_STORE_ISSUER_ID");
  const keyId = Deno.env.get("APP_STORE_KEY_ID");
  const privateKey = Deno.env.get("APP_STORE_PRIVATE_KEY")?.replace(/\\n/g, "\n");
  const vendor = Deno.env.get("APP_STORE_VENDOR_NUMBER");
  if (!issuer || !keyId || !privateKey || !vendor) {
    return json({
      configured: false,
      downloads: null,
      firstOpens: null,
      sessions: null,
      registeredUsers: null,
      message: "App Store Connect server credentials are not configured.",
    }, 503);
  }

  try {
    const key = await importPKCS8(privateKey, "ES256");
    const token = await new SignJWT({})
      .setProtectedHeader({ alg: "ES256", kid: keyId, typ: "JWT" })
      .setIssuer(issuer).setAudience("appstoreconnect-v1")
      .setIssuedAt().setExpirationTime("15m").sign(key);

    const url = new URL("https://api.appstoreconnect.apple.com/v1/salesReports");
    url.searchParams.set("filter[frequency]", "DAILY");
    url.searchParams.set("filter[reportSubType]", "SUMMARY");
    url.searchParams.set("filter[reportType]", "SALES");
    url.searchParams.set("filter[vendorNumber]", vendor);
    url.searchParams.set("filter[reportDate]", new URL(request.url).searchParams.get("date") ?? new Date(Date.now() - 86400000).toISOString().slice(0, 10));
    const result = await fetch(url, { headers: { authorization: `Bearer ${token}`, accept: "application/a-gzip" } });
    if (!result.ok) return json({ error: "apple_report_failed", status: result.status }, 502);

    const decompressed = result.body?.pipeThrough(new DecompressionStream("gzip"));
    const text = decompressed ? await new Response(decompressed).text() : "";
    const rows = text.trim().split("\n").map((line) => line.split("\t"));
    const header = rows.shift() ?? [];
    const unitsIndex = header.indexOf("Units");
    const productTypeIndex = header.indexOf("Product Type Identifier");
    const downloads = rows.reduce((sum, row) => {
      const productType = row[productTypeIndex] ?? "";
      return ["1", "1-B"].includes(productType) ? sum + Number(row[unitsIndex] ?? 0) : sum;
    }, 0);

    return json({
      configured: true,
      downloads: { value: downloads, source: "Apple Sales and Trends", includesRedownloads: false },
      firstOpens: null,
      sessions: null,
      registeredUsers: null,
      note: "Apple downloads are not first opens, sessions, or registered users.",
    });
  } catch {
    return json({ error: "app_store_stats_unavailable" }, 502);
  }
});
