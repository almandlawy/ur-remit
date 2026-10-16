const supabaseURL = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const headers = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store",
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "content-type",
};

function reply(data: unknown, status = 200) {
  return new Response(JSON.stringify(status < 400 ? { data } : { error: data }), { status, headers });
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

function base64URL(bytes: Uint8Array) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

async function sha256(value: string) {
  return Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value))))
    .map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers });
  if (request.method !== "POST") return reply("METHOD_NOT_ALLOWED", 405);

  try {
    const body = await request.json().catch(() => null) as Record<string, unknown> | null;
    const username = typeof body?.username === "string" ? body.username.trim() : "";
    const password = typeof body?.password === "string" ? body.password : "";
    if (!/^[A-Za-z0-9@._-]{4,254}$/.test(username) || password.length < 12 || password.length > 256) {
      return reply("INVALID_INPUT", 400);
    }

    const users = await rest(`admin_users?select=id,password_hash,failed_login_count,locked_until&or=(username.ilike.${encodeURIComponent(username)},email.ilike.${encodeURIComponent(username)})&disabled_at=is.null&limit=1`) as Array<Record<string, unknown>>;
    const user = users[0];
    const isLocked = Boolean(user?.locked_until && Date.parse(String(user.locked_until)) > Date.now());
    if (isLocked) return reply("ACCOUNT_LOCKED", 423);
    const verified = user && !isLocked
      ? await rest("rpc/verify_password", { method: "POST", body: JSON.stringify({ p_password: password, p_hash: user.password_hash }) }) === true
      : false;

    if (!user || !verified) {
      if (user?.id) {
        const failed = Number(user.failed_login_count ?? 0) + 1;
        await rest(`admin_users?id=eq.${user.id}`, {
          method: "PATCH",
          body: JSON.stringify({ failed_login_count: failed, ...(failed >= 5 ? { locked_until: new Date(Date.now() + 15 * 60_000).toISOString() } : {}) }),
        });
      }
      return reply("INVALID_CREDENTIALS", 401);
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
    return reply({ token, expiresAt });
  } catch {
    return reply("SERVICE_UNAVAILABLE", 503);
  }
});
