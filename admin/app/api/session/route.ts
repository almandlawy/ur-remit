import { NextResponse } from "next/server";
import { ADMIN_ACCESS_COOKIE, ADMIN_REFRESH_COOKIE, isSupabaseConfigured, supabaseAuthRequest, supabaseRestRequest } from "@/lib/supabase";

const REFRESH_MAX_AGE_SECONDS = 60 * 60 * 24 * 30; // 30 days — matches the iOS app's admin session lifetime.

type TokenPayload = { access_token: string; refresh_token: string; expires_in: number };

export async function POST(request: Request) {
  if (!isSupabaseConfigured()) {
    return NextResponse.json({ error: "SUPABASE_NOT_CONFIGURED" }, { status: 503 });
  }
  const body = (await request.json().catch(() => null)) as { email?: unknown; password?: unknown } | null;
  const email = typeof body?.email === "string" ? body.email.trim() : "";
  const password = typeof body?.password === "string" ? body.password : "";
  if (!email || !password) return NextResponse.json({ error: "INVALID_INPUT" }, { status: 422 });

  let tokenResponse: Response;
  try {
    tokenResponse = await supabaseAuthRequest("token?grant_type=password", { method: "POST", body: JSON.stringify({ email, password }) });
  } catch {
    return NextResponse.json({ error: "SUPABASE_UNREACHABLE" }, { status: 503 });
  }
  if (tokenResponse.status === 400 || tokenResponse.status === 401) {
    return NextResponse.json({ error: "INVALID_CREDENTIALS" }, { status: 401 });
  }
  if (!tokenResponse.ok) return NextResponse.json({ error: "SUPABASE_UNREACHABLE" }, { status: 503 });

  const token = (await tokenResponse.json()) as TokenPayload;

  // Signing in only proves the email/password is correct; confirm the account is actually listed
  // as an admin via the `is_admin_user()` RPC, which is enforced by Postgres RLS server-side.
  let isAdmin = false;
  try {
    const adminCheck = await supabaseRestRequest("rpc/is_admin_user", { method: "POST", accessToken: token.access_token, body: "{}" });
    isAdmin = adminCheck.ok && (await adminCheck.json()) === true;
  } catch {
    return NextResponse.json({ error: "SUPABASE_UNREACHABLE" }, { status: 503 });
  }
  if (!isAdmin) return NextResponse.json({ error: "NOT_ADMIN" }, { status: 403 });

  const result = NextResponse.json({ ok: true });
  const secure = process.env.NODE_ENV === "production";
  result.cookies.set(ADMIN_ACCESS_COOKIE, token.access_token, { httpOnly: true, secure, sameSite: "strict", path: "/", maxAge: token.expires_in });
  result.cookies.set(ADMIN_REFRESH_COOKIE, token.refresh_token, { httpOnly: true, secure, sameSite: "strict", path: "/", maxAge: REFRESH_MAX_AGE_SECONDS });
  return result;
}

export async function DELETE() {
  const response = NextResponse.json({ ok: true });
  response.cookies.delete(ADMIN_ACCESS_COOKIE);
  response.cookies.delete(ADMIN_REFRESH_COOKIE);
  return response;
}
