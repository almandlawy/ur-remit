const projectURL = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const headers = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store",
};

function reply(body: unknown, status: number) {
  return new Response(JSON.stringify(body), { status, headers });
}

Deno.serve(async (request) => {
  if (request.method !== "DELETE") return reply({ error: "method_not_allowed" }, 405);

  const authorization = request.headers.get("authorization") ?? "";
  if (!authorization.startsWith("Bearer ") || authorization.length > 4096) {
    return reply({ error: "unauthorized" }, 401);
  }

  try {
    // Resolve identity from the caller JWT. Never accept a user id from the client.
    const userResponse = await fetch(`${projectURL}/auth/v1/user`, {
      headers: { apikey: serviceKey, authorization },
      signal: AbortSignal.timeout(5000),
    });
    if (!userResponse.ok) return reply({ error: "unauthorized" }, 401);

    const user = await userResponse.json();
    if (typeof user?.id !== "string" || !/^[0-9a-f-]{36}$/i.test(user.id)) {
      return reply({ error: "unauthorized" }, 401);
    }

    const deletion = await fetch(`${projectURL}/auth/v1/admin/users/${user.id}`, {
      method: "DELETE",
      headers: { apikey: serviceKey, authorization: `Bearer ${serviceKey}` },
      signal: AbortSignal.timeout(8000),
    });
    if (!deletion.ok) return reply({ error: "deletion_failed" }, 503);

    return reply({ data: { deleted: true } }, 200);
  } catch {
    return reply({ error: "service_unavailable" }, 503);
  }
});
