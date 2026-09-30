import "server-only";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { createHmac, randomBytes } from "node:crypto";

/**
 * Supabase-backed replacement for the previous Fastify-proxy `backendRequest`.
 *
 * The admin console (pages, components, API routes) was built around a single
 * choke point: `backendRequest(path, init)` returning a fetch-style Response
 * for paths shaped like `/api/v1/admin/<resource>[/:id]`. That contract is
 * preserved exactly here so no page/component needs to change — only the
 * implementation now talks to Supabase directly (Auth for credentials,
 * PostgREST via the service-role client for data) instead of proxying to an
 * unreleased Fastify backend.
 *
 * Deliberate simplification vs. the old backend: admin sessions are no longer
 * gated behind a separate scrypt password + TOTP MFA check baked into
 * `admin_users`. Password verification is delegated entirely to Supabase Auth
 * (`auth.users`), and `admin_users` is now just the authorization/profile
 * record (role, permissions, disabled flag) keyed by email.
 */

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`${name} must be configured on the Next.js server.`);
  return value;
}

let cachedServiceClient: SupabaseClient | null = null;
function serviceClient(): SupabaseClient {
  if (!cachedServiceClient) {
    cachedServiceClient = createClient(requireEnv("SUPABASE_URL"), requireEnv("SUPABASE_SERVICE_ROLE_KEY"), {
      auth: { persistSession: false, autoRefreshToken: false }
    });
  }
  return cachedServiceClient;
}

function anonClient(): SupabaseClient {
  const anonKey = process.env.SUPABASE_PUBLISHABLE_KEY ?? process.env.SUPABASE_ANON_KEY;
  if (!anonKey) throw new Error("SUPABASE_PUBLISHABLE_KEY (or SUPABASE_ANON_KEY) must be configured on the Next.js server.");
  return createClient(requireEnv("SUPABASE_URL"), anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
}

/** Derives a stable HMAC key from the service-role secret so no extra signing secret needs to be provisioned. */
function signingKey(): string {
  return createHmac("sha256", requireEnv("SUPABASE_SERVICE_ROLE_KEY")).update("ur-admin-session-signing").digest("hex");
}

function fingerprint(value: string): string {
  return createHmac("sha256", signingKey()).update(value).digest("hex");
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}

function bearerToken(init: RequestInit): string | null {
  const headers = new Headers(init.headers);
  const value = headers.get("authorization");
  if (!value?.startsWith("Bearer ")) return null;
  return value.slice(7);
}

function readBody<T>(init: RequestInit): T | null {
  if (init.body === undefined || init.body === null) return null;
  try { return JSON.parse(String(init.body)) as T; } catch { return null; }
}

type Actor = { id: string; role: string; permissions: string[] };

async function authenticateToken(token: string): Promise<Actor | null> {
  const client = serviceClient();
  const tokenHash = fingerprint(token);
  const { data: session } = await client
    .from("admin_sessions")
    .select("id, admin_user_id, expires_at, revoked_at")
    .eq("token_hash", tokenHash)
    .maybeSingle();
  if (!session || session.revoked_at || new Date(session.expires_at as string).getTime() <= Date.now()) return null;

  const { data: user } = await client
    .from("admin_users")
    .select("id, disabled_at, role_id")
    .eq("id", session.admin_user_id as string)
    .maybeSingle();
  if (!user || user.disabled_at) return null;

  const { data: role } = await client.from("roles").select("name").eq("id", user.role_id as string).maybeSingle();
  const { data: rolePermissions } = await client
    .from("role_permissions")
    .select("permission_id")
    .eq("role_id", user.role_id as string);
  const permissionIds = (rolePermissions ?? []).map((row) => row.permission_id as string);
  let permissions: string[] = [];
  if (permissionIds.length > 0) {
    const { data: permissionRows } = await client.from("permissions").select("name").in("id", permissionIds);
    permissions = (permissionRows ?? []).map((row) => row.name as string).filter(Boolean);
  }

  void client.from("admin_sessions").update({ last_seen_at: new Date().toISOString() }).eq("id", session.id as string);
  return { id: user.id as string, role: (role?.name as string) ?? "UNKNOWN", permissions };
}

async function login(
  body: { email?: unknown; password?: unknown } | null,
  context: { requestId: string; ip?: string | undefined }
): Promise<{ token: string; expiresAt: string } | null> {
  const email = typeof body?.email === "string" ? body.email.trim().toLowerCase() : "";
  const password = typeof body?.password === "string" ? body.password : "";
  if (!email || !password) return null;

  const { data: authData, error: authError } = await anonClient().auth.signInWithPassword({ email, password });
  if (authError || !authData?.session || !authData.user?.email) return null;

  const client = serviceClient();
  const { data: adminUser } = await client
    .from("admin_users")
    .select("id, disabled_at")
    .ilike("email", authData.user.email)
    .maybeSingle();
  if (!adminUser || adminUser.disabled_at) return null;

  const token = randomBytes(32).toString("base64url");
  const tokenHash = fingerprint(token);
  const expiresAt = new Date(Date.now() + 24 * 60 * 60_000).toISOString();

  const { error: insertError } = await client.from("admin_sessions").insert({
    admin_user_id: adminUser.id,
    token_hash: tokenHash,
    mfa_verified_at: null,
    expires_at: expiresAt,
    ip_fingerprint: context.ip ? fingerprint(context.ip) : null
  });
  if (insertError) return null;

  await client.from("admin_users").update({ last_login_at: new Date().toISOString() }).eq("id", adminUser.id as string);
  await client.from("audit_logs").insert({
    actor_id: adminUser.id,
    action: "LOGIN",
    entity_type: "admin_user",
    entity_id: String(adminUser.id),
    after_value: { success: true, method: "supabase-auth" },
    request_id: context.requestId,
    ip_context: context.ip ?? null
  });

  return { token, expiresAt };
}

async function logout(actor: Actor, token: string, requestId: string, ip?: string): Promise<void> {
  const client = serviceClient();
  const tokenHash = fingerprint(token);
  const { data: revoked } = await client
    .from("admin_sessions")
    .update({ revoked_at: new Date().toISOString() })
    .eq("token_hash", tokenHash)
    .eq("admin_user_id", actor.id)
    .is("revoked_at", null)
    .select("id")
    .maybeSingle();
  if (revoked) {
    await client.from("audit_logs").insert({
      actor_id: actor.id,
      action: "LOGOUT",
      entity_type: "admin_session",
      entity_id: revoked.id,
      after_value: { revoked: true },
      request_id: requestId,
      ip_context: ip ?? null
    });
  }
}

async function dashboard(): Promise<Record<string, unknown>> {
  // NOTE: the `admin_dashboard_metrics()` DB function is a SECURITY DEFINER RPC
  // gated by `is_admin_user()`, which checks `auth.uid()`. A service-role call
  // carries no end-user JWT, so `auth.uid()` is null and the RPC would silently
  // return `{}`. Compute the same metrics directly against the tables instead.
  const client = serviceClient();
  const [routes, offices, agents, pushTokens, latestRate] = await Promise.all([
    client.from("rate_routes").select("id", { count: "exact", head: true }).eq("is_active", true),
    client.from("offices").select("id", { count: "exact", head: true }).eq("is_active", true).eq("is_verified", true),
    client.from("agents").select("id", { count: "exact", head: true }).eq("status", "VERIFIED"),
    client.from("push_tokens").select("id", { count: "exact", head: true }).is("revoked_at", null),
    client.from("rates").select("source_timestamp").eq("is_active", true).order("source_timestamp", { ascending: false }).limit(1).maybeSingle()
  ]);
  return {
    activeRoutes: routes.count ?? 0,
    activeOffices: offices.count ?? 0,
    verifiedAgents: agents.count ?? 0,
    pushSubscribers: pushTokens.count ?? 0,
    lastRateUpdate: latestRate.data?.source_timestamp ?? null
  };
}

function toText(value: unknown): string | null {
  return value === null || value === undefined ? null : String(value);
}

async function listRates(): Promise<Record<string, unknown>[]> {
  const { data, error } = await serviceClient()
    .from("rates")
    .select(
      "id, route_id, buy, sell, fee_fixed, fee_percent, valid_from, valid_until, source_timestamp, version, is_active, rate_routes(name_ar, name_en, source_currency, destination_currency)"
    )
    .order("is_active", { ascending: false })
    .order("source_timestamp", { ascending: false })
    .limit(500);
  if (error) throw new Error(error.message);
  return (data ?? []).map((row) => {
    const route = row.rate_routes as { name_ar?: string; name_en?: string; source_currency?: string; destination_currency?: string } | null;
    return {
      id: row.id,
      routeId: row.route_id,
      routeNameArabic: route?.name_ar ?? null,
      routeNameEnglish: route?.name_en ?? null,
      sourceCurrency: route?.source_currency ?? null,
      destinationCurrency: route?.destination_currency ?? null,
      buy: toText(row.buy),
      sell: toText(row.sell),
      feeFixed: toText(row.fee_fixed),
      feePercent: toText(row.fee_percent),
      validFrom: row.valid_from,
      validUntil: row.valid_until,
      sourceTimestamp: row.source_timestamp,
      version: row.version,
      active: row.is_active
    };
  });
}

async function updateRate(
  rateId: string,
  update: { buy?: unknown; sell?: unknown; feeFixed?: unknown; feePercent?: unknown },
  actor: Actor,
  requestId: string,
  ip?: string
): Promise<Record<string, unknown> | null> {
  const client = serviceClient();
  const { data: oldRate, error: fetchError } = await client.from("rates").select("*").eq("id", rateId).maybeSingle();
  if (fetchError) throw new Error(fetchError.message);
  if (!oldRate) return null;

  await client.from("rates").update({ is_active: false }).eq("id", rateId);

  const insertPayload = {
    route_id: oldRate.route_id,
    buy: update.buy === undefined ? oldRate.buy : update.buy,
    sell: update.sell === undefined ? oldRate.sell : update.sell,
    fee_fixed: update.feeFixed === undefined ? oldRate.fee_fixed : update.feeFixed,
    fee_percent: update.feePercent === undefined ? oldRate.fee_percent : update.feePercent,
    valid_from: new Date().toISOString(),
    valid_until: oldRate.valid_until,
    source_timestamp: new Date().toISOString(),
    version: Number(oldRate.version) + 1,
    is_active: true
  };
  const { data: newRate, error: insertError } = await client.from("rates").insert(insertPayload).select("*").single();
  if (insertError || !newRate) {
    await client.from("rates").update({ is_active: true }).eq("id", rateId);
    throw new Error(insertError?.message ?? "rate insert failed");
  }

  await client.from("rate_history").insert({
    rate_id: newRate.id,
    old_value: oldRate,
    new_value: newRate,
    actor_id: actor.id,
    request_id: requestId,
    context: { source: "admin-web-supabase" }
  });
  await client.from("audit_logs").insert({
    actor_id: actor.id,
    action: "UPDATE",
    entity_type: "rate",
    entity_id: String(newRate.id),
    before_value: oldRate,
    after_value: newRate,
    request_id: requestId,
    ip_context: ip ?? null
  });

  return newRate as Record<string, unknown>;
}

function mapOffice(row: Record<string, unknown>): Record<string, unknown> {
  const country = row.countries as { iso_code?: string; name_ar?: string; name_en?: string } | null;
  const city = row.cities as { name_ar?: string; name_en?: string } | null;
  return {
    id: row.id,
    publicCode: row.public_code,
    countryId: row.country_id,
    cityId: row.city_id,
    nameArabic: row.name_ar,
    nameEnglish: row.name_en,
    addressArabic: row.address_ar,
    addressEnglish: row.address_en,
    countryCode: country?.iso_code ?? null,
    countryArabic: country?.name_ar ?? null,
    countryEnglish: country?.name_en ?? null,
    cityArabic: city?.name_ar ?? null,
    cityEnglish: city?.name_en ?? null,
    latitude: toText(row.latitude),
    longitude: toText(row.longitude),
    phone: row.phone,
    whatsapp: row.whatsapp,
    workingHours: row.working_hours,
    services: row.services,
    verified: row.is_verified,
    active: row.is_active,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

async function listOffices(): Promise<Record<string, unknown>[]> {
  const { data, error } = await serviceClient()
    .from("offices")
    .select(
      "id, public_code, country_id, city_id, name_ar, name_en, address_ar, address_en, latitude, longitude, phone, whatsapp, working_hours, services, is_verified, is_active, created_at, updated_at, countries(iso_code, name_ar, name_en), cities(name_ar, name_en)"
    )
    .order("updated_at", { ascending: false })
    .limit(500);
  if (error) throw new Error(error.message);
  return (data ?? []).map((row) => mapOffice(row as Record<string, unknown>));
}

type OfficeInput = {
  countryId?: unknown; cityId?: unknown; publicCode?: unknown; nameArabic?: unknown; nameEnglish?: unknown;
  addressArabic?: unknown; addressEnglish?: unknown; latitude?: unknown; longitude?: unknown;
  phone?: unknown; whatsapp?: unknown; workingHours?: unknown; services?: unknown; verified?: unknown; active?: unknown;
};

async function validLocationPair(countryId: string, cityId: string): Promise<boolean> {
  const client = serviceClient();
  const { data: city } = await client.from("cities").select("id, country_id, is_active").eq("id", cityId).maybeSingle();
  if (!city || !city.is_active || city.country_id !== countryId) return false;
  const { data: country } = await client.from("countries").select("id, is_active").eq("id", countryId).maybeSingle();
  return Boolean(country?.is_active);
}

async function createOffice(input: OfficeInput, actor: Actor, requestId: string, ip?: string): Promise<Record<string, unknown> | null> {
  const countryId = String(input.countryId ?? "");
  const cityId = String(input.cityId ?? "");
  if (!(await validLocationPair(countryId, cityId))) return null;
  const client = serviceClient();
  const { data: office, error } = await client
    .from("offices")
    .insert({
      public_code: input.publicCode, country_id: countryId, city_id: cityId,
      name_ar: input.nameArabic, name_en: input.nameEnglish,
      address_ar: input.addressArabic, address_en: input.addressEnglish,
      latitude: input.latitude ?? null, longitude: input.longitude ?? null,
      phone: input.phone ?? null, whatsapp: input.whatsapp ?? null,
      working_hours: input.workingHours ?? {}, services: input.services ?? [],
      is_verified: input.verified ?? false, is_active: input.active ?? true
    })
    .select("*")
    .single();
  if (error || !office) return null;
  await client.from("audit_logs").insert({
    actor_id: actor.id, action: "CREATE", entity_type: "office", entity_id: String(office.id),
    after_value: office, request_id: requestId, ip_context: ip ?? null
  });
  return office as Record<string, unknown>;
}

async function updateOffice(officeId: string, input: OfficeInput, actor: Actor, requestId: string, ip?: string): Promise<Record<string, unknown> | null> {
  const client = serviceClient();
  const { data: current } = await client.from("offices").select("*").eq("id", officeId).maybeSingle();
  if (!current) return null;
  const countryId = String(input.countryId ?? current.country_id);
  const cityId = String(input.cityId ?? current.city_id);
  if (!(await validLocationPair(countryId, cityId))) return null;
  const { data: updated, error } = await client
    .from("offices")
    .update({
      public_code: input.publicCode ?? current.public_code, country_id: countryId, city_id: cityId,
      name_ar: input.nameArabic ?? current.name_ar, name_en: input.nameEnglish ?? current.name_en,
      address_ar: input.addressArabic ?? current.address_ar, address_en: input.addressEnglish ?? current.address_en,
      latitude: input.latitude === undefined ? current.latitude : input.latitude,
      longitude: input.longitude === undefined ? current.longitude : input.longitude,
      phone: input.phone === undefined ? current.phone : input.phone,
      whatsapp: input.whatsapp === undefined ? current.whatsapp : input.whatsapp,
      working_hours: input.workingHours ?? current.working_hours, services: input.services ?? current.services,
      is_verified: input.verified ?? current.is_verified, is_active: input.active ?? current.is_active,
      updated_at: new Date().toISOString()
    })
    .eq("id", officeId)
    .select("*")
    .single();
  if (error || !updated) return null;
  await client.from("audit_logs").insert({
    actor_id: actor.id, action: "UPDATE", entity_type: "office", entity_id: officeId,
    before_value: current, after_value: updated, request_id: requestId, ip_context: ip ?? null
  });
  return updated as Record<string, unknown>;
}

async function deleteOffice(officeId: string, actor: Actor, requestId: string, ip?: string): Promise<boolean> {
  const client = serviceClient();
  const { data: current } = await client.from("offices").select("*").eq("id", officeId).maybeSingle();
  if (!current) return false;
  if (current.is_active) {
    const { data: updated } = await client
      .from("offices")
      .update({ is_active: false, updated_at: new Date().toISOString() })
      .eq("id", officeId)
      .select("*")
      .single();
    await client.from("audit_logs").insert({
      actor_id: actor.id, action: "UPDATE", entity_type: "office", entity_id: officeId,
      before_value: current, after_value: updated, request_id: requestId, ip_context: ip ?? null
    });
  }
  return true;
}

async function listAgents(): Promise<Record<string, unknown>[]> {
  const { data, error } = await serviceClient()
    .from("agents")
    .select("id, trade_name, status, expires_at, created_at, countries(name_ar, name_en), cities(name_ar, name_en)")
    .order("created_at", { ascending: false })
    .limit(500);
  if (error) throw new Error(error.message);
  return (data ?? []).map((row) => {
    const country = row.countries as { name_ar?: string; name_en?: string } | null;
    const city = row.cities as { name_ar?: string; name_en?: string } | null;
    return {
      id: row.id, tradeName: row.trade_name, status: row.status, expiresAt: row.expires_at, createdAt: row.created_at,
      countryArabic: country?.name_ar ?? null, countryEnglish: country?.name_en ?? null,
      cityArabic: city?.name_ar ?? null, cityEnglish: city?.name_en ?? null
    };
  });
}

async function listAdmins(): Promise<Record<string, unknown>[]> {
  const { data, error } = await serviceClient()
    .from("admin_users")
    .select("id, username, email, disabled_at, last_login_at, created_at, roles(name)")
    .order("created_at", { ascending: false })
    .limit(500);
  if (error) throw new Error(error.message);
  return (data ?? []).map((row) => ({
    id: row.id, username: row.username, email: row.email, role: (row.roles as { name?: string } | null)?.name ?? null,
    disabledAt: row.disabled_at, lastLoginAt: row.last_login_at, createdAt: row.created_at
  }));
}

async function auditLog(): Promise<Record<string, unknown>[]> {
  const { data, error } = await serviceClient()
    .from("audit_logs")
    .select("id, action, entity_type, entity_id, before_value, after_value, request_id, created_at, admin_users(username)")
    .order("created_at", { ascending: false })
    .limit(200);
  if (error) throw new Error(error.message);
  return (data ?? []).map((row) => ({
    id: row.id, action: row.action, entityType: row.entity_type, entityId: row.entity_id,
    beforeValue: row.before_value, afterValue: row.after_value, requestId: row.request_id, createdAt: row.created_at,
    actor: (row.admin_users as { username?: string } | null)?.username ?? null
  }));
}

/**
 * Self-service "forgot password" flow, used because the real admin account
 * (almandlawy112@gmail.com) originally authenticated via Google OAuth only
 * and has no password set in Supabase Auth yet. Sends the standard Supabase
 * recovery email; does not reveal whether the email exists (always returns
 * true unless the request itself is malformed) to avoid account enumeration.
 */
async function requestPasswordReset(email: string, redirectTo: string): Promise<void> {
  await anonClient().auth.resetPasswordForEmail(email, { redirectTo });
}

/**
 * Completes the recovery flow: the browser lands on /reset-password with a
 * Supabase recovery access token in the URL fragment (never sent to any
 * server by the browser automatically). The client posts that token here
 * directly, scoped to a one-off client tied to that token, to set the new
 * password. This is independent from our own admin_sessions bearer tokens.
 */
async function confirmPasswordReset(recoveryAccessToken: string, newPassword: string): Promise<boolean> {
  const scopedClient = createClient(requireEnv("SUPABASE_URL"), process.env.SUPABASE_PUBLISHABLE_KEY ?? process.env.SUPABASE_ANON_KEY ?? "", {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${recoveryAccessToken}` } }
  });
  const { data: userData, error: userError } = await scopedClient.auth.getUser();
  if (userError || !userData?.user?.email) return false;

  // Only allow this for emails already registered as admin_users, so the
  // recovery flow can't be used to set a password for an arbitrary auth.users
  // account that has no admin console access.
  const { data: adminUser } = await serviceClient()
    .from("admin_users")
    .select("id, disabled_at")
    .ilike("email", userData.user.email)
    .maybeSingle();
  if (!adminUser || adminUser.disabled_at) return false;

  const { error: updateError } = await scopedClient.auth.updateUser({ password: newPassword });
  return !updateError;
}

async function changePasswordForActor(actor: Actor, currentPassword: string, newPassword: string): Promise<boolean> {
  const client = serviceClient();
  const { data: adminUser } = await client.from("admin_users").select("email").eq("id", actor.id).maybeSingle();
  const email = adminUser?.email as string | undefined;
  if (!email) return false;

  const { data: authData, error } = await anonClient().auth.signInWithPassword({ email, password: currentPassword });
  if (error || !authData?.session) return false;

  const scopedClient = createClient(requireEnv("SUPABASE_URL"), process.env.SUPABASE_PUBLISHABLE_KEY ?? process.env.SUPABASE_ANON_KEY ?? "", {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${authData.session.access_token}` } }
  });
  const { error: updateError } = await scopedClient.auth.updateUser({ password: newPassword });
  return !updateError;
}

async function mobileCountries(): Promise<Record<string, unknown>[]> {
  const { data, error } = await serviceClient()
    .from("countries")
    .select("id, iso_code, name_ar, name_en")
    .eq("is_active", true)
    .order("name_ar", { ascending: true });
  if (error) throw new Error(error.message);
  return (data ?? []).map((row) => ({ id: row.id, isoCode: row.iso_code, nameArabic: row.name_ar, nameEnglish: row.name_en }));
}

async function mobileCities(): Promise<Record<string, unknown>[]> {
  const { data, error } = await serviceClient()
    .from("cities")
    .select("id, name_ar, name_en, is_active, countries(iso_code)")
    .eq("is_active", true)
    .order("name_ar", { ascending: true });
  if (error) throw new Error(error.message);
  return (data ?? []).map((row) => ({
    id: row.id, nameArabic: row.name_ar, nameEnglish: row.name_en,
    countryCode: (row.countries as { iso_code?: string } | null)?.iso_code ?? null
  }));
}

/**
 * Drop-in replacement for the old fetch-to-Fastify `backendRequest`. Same
 * signature and Response contract; every admin page/component/API route
 * keeps working without modification.
 */
export async function backendRequest(path: string, init: RequestInit = {}): Promise<Response> {
  const method = (init.method ?? "GET").toUpperCase();
  const requestId = randomBytes(8).toString("hex");

  try {
    if (path === "/api/v1/mobile/countries" && method === "GET") return json({ data: await mobileCountries() });
    if (path === "/api/v1/mobile/cities" && method === "GET") return json({ data: await mobileCities() });

    if (path === "/api/v1/admin/auth/login" && method === "POST") {
      const body = readBody<{ email?: unknown; password?: unknown }>(init);
      const result = await login(body, { requestId });
      if (!result) return json({ error: "INVALID_CREDENTIALS" }, 401);
      return json({ data: result });
    }
    if (path === "/api/v1/admin/auth/forgot-password" && method === "POST") {
      const body = readBody<{ email?: unknown; redirectTo?: unknown }>(init);
      if (typeof body?.email === "string" && typeof body?.redirectTo === "string") {
        await requestPasswordReset(body.email, body.redirectTo);
      }
      // Always return ok, whether or not the email exists, to avoid account enumeration.
      return json({ data: { ok: true } });
    }
    if (path === "/api/v1/admin/auth/reset-password" && method === "POST") {
      const body = readBody<{ accessToken?: unknown; newPassword?: unknown }>(init);
      const ok = typeof body?.accessToken === "string" && typeof body?.newPassword === "string"
        ? await confirmPasswordReset(body.accessToken, body.newPassword)
        : false;
      return ok ? json({ data: { ok: true } }) : json({ error: "INVALID_RESET_LINK" }, 400);
    }

    // Everything below requires a bearer session token.
    const token = bearerToken(init);
    if (!token) return json({ error: "UNAUTHORIZED" }, 401);
    const actor = await authenticateToken(token);
    if (!actor) return json({ error: "UNAUTHORIZED" }, 401);

    if (path === "/api/v1/admin/auth/logout" && method === "POST") {
      await logout(actor, token, requestId);
      return json({ data: { ok: true } });
    }
    if (path === "/api/v1/admin/me" && method === "GET") return json({ data: actor });
    if (path === "/api/v1/admin/dashboard" && method === "GET") return json({ data: await dashboard() });
    if (path === "/api/v1/admin/rates" && method === "GET") return json({ data: await listRates() });
    if (path === "/api/v1/admin/offices" && method === "GET") return json({ data: await listOffices() });
    if (path === "/api/v1/admin/offices" && method === "POST") {
      const body = readBody<OfficeInput>(init) ?? {};
      const office = await createOffice(body, actor, requestId);
      if (!office) return json({ error: "INVALID_OFFICE" }, 400);
      return json({ data: office });
    }
    if (path === "/api/v1/admin/agents" && method === "GET") return json({ data: await listAgents() });
    if (path === "/api/v1/admin/users" && method === "GET") return json({ data: await listAdmins() });
    if (path === "/api/v1/admin/audit" && method === "GET") return json({ data: await auditLog() });
    if (path === "/api/v1/admin/auth/change-password" && method === "POST") {
      const body = readBody<{ currentPassword?: unknown; newPassword?: unknown }>(init);
      const ok = typeof body?.currentPassword === "string" && typeof body?.newPassword === "string"
        ? await changePasswordForActor(actor, String(body.currentPassword), String(body.newPassword))
        : false;
      return ok ? json({ data: { ok: true } }) : json({ error: "INVALID_CURRENT_PASSWORD" }, 401);
    }

    const ratesMatch = /^\/api\/v1\/admin\/rates\/([0-9a-f-]{36})$/i.exec(path);
    if (ratesMatch && method === "PATCH") {
      const body = readBody<{ buy?: unknown; sell?: unknown; feeFixed?: unknown; feePercent?: unknown }>(init) ?? {};
      const rate = await updateRate(ratesMatch[1]!, body, actor, requestId);
      if (!rate) return json({ error: "NOT_FOUND" }, 404);
      return json({ data: rate });
    }
    const officesMatch = /^\/api\/v1\/admin\/offices\/([0-9a-f-]{36})$/i.exec(path);
    if (officesMatch && method === "PATCH") {
      const body = readBody<OfficeInput>(init) ?? {};
      const office = await updateOffice(officesMatch[1]!, body, actor, requestId);
      if (!office) return json({ error: "NOT_FOUND" }, 404);
      return json({ data: office });
    }
    if (officesMatch && method === "DELETE") {
      const ok = await deleteOffice(officesMatch[1]!, actor, requestId);
      return ok ? json({ data: { ok: true } }) : json({ error: "NOT_FOUND" }, 404);
    }

    return json({ error: "NOT_FOUND" }, 404);
  } catch (cause) {
    console.error(`admin backend adapter error [${requestId}]`, cause);
    return json({ error: "INTERNAL_ERROR" }, 502);
  }
}
