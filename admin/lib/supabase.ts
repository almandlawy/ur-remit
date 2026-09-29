/// The admin dashboard talks directly to Supabase Auth + PostgREST — the same project the iOS app
/// uses — instead of a local Fastify backend that is never reachable once this page is deployed
/// (this was the root cause of "Could not connect to the server" / rate edits silently not saving).
/// Both values are safe to keep server-side only: the publishable (anon) key only grants whatever
/// access Postgres RLS allows for the `anon`/`authenticated` roles, and it is never sent to the browser.
export const supabaseURL = process.env.SUPABASE_URL ?? "";
export const supabasePublishableKey = process.env.SUPABASE_PUBLISHABLE_KEY ?? "";

export function isSupabaseConfigured(): boolean {
  return supabaseURL.length > 0 && supabasePublishableKey.length > 0;
}

type SupabaseRequestOptions = Omit<RequestInit, "headers"> & { accessToken?: string; headers?: Record<string, string> };

export async function supabaseAuthRequest(path: string, init: SupabaseRequestOptions = {}): Promise<Response> {
  const { headers, ...rest } = init;
  return fetch(`${supabaseURL}/auth/v1/${path}`, {
    ...rest,
    cache: "no-store",
    headers: { "content-type": "application/json", apikey: supabasePublishableKey, ...headers },
  });
}

/// `accessToken` should be the signed-in admin's Supabase access token so PostgREST evaluates RLS
/// (`is_admin_user()`) as that user; it falls back to the anon key for public, unauthenticated reads.
export async function supabaseRestRequest(path: string, init: SupabaseRequestOptions = {}): Promise<Response> {
  const { accessToken, headers, ...rest } = init;
  return fetch(`${supabaseURL}/rest/v1/${path}`, {
    ...rest,
    cache: "no-store",
    headers: {
      "content-type": "application/json",
      apikey: supabasePublishableKey,
      authorization: `Bearer ${accessToken ?? supabasePublishableKey}`,
      ...headers,
    },
  });
}

export const ADMIN_ACCESS_COOKIE = "ur_admin_session";
export const ADMIN_REFRESH_COOKIE = "ur_admin_refresh";
