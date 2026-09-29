import { NextRequest, NextResponse } from "next/server";

// Supabase access tokens expire after ~1 hour; without this, admins would be forced back to
// /login every hour even though their 30-day refresh token is still valid. This mirrors the
// silent-refresh behaviour already implemented on the iOS side.
const ACCESS_COOKIE = "ur_admin_session";
const REFRESH_COOKIE = "ur_admin_refresh";

export const config = { matcher: ["/dashboard/:path*"] };

export async function proxy(request: NextRequest) {
  if (request.cookies.get(ACCESS_COOKIE)?.value) return NextResponse.next();

  const refreshToken = request.cookies.get(REFRESH_COOKIE)?.value;
  const supabaseURL = process.env.SUPABASE_URL;
  const supabaseKey = process.env.SUPABASE_PUBLISHABLE_KEY;
  if (!refreshToken || !supabaseURL || !supabaseKey) {
    return NextResponse.redirect(new URL("/login", request.url));
  }

  try {
    const response = await fetch(`${supabaseURL}/auth/v1/token?grant_type=refresh_token`, {
      method: "POST",
      headers: { "content-type": "application/json", apikey: supabaseKey },
      body: JSON.stringify({ refresh_token: refreshToken }),
    });
    if (!response.ok) return NextResponse.redirect(new URL("/login", request.url));

    const token = (await response.json()) as { access_token: string; refresh_token: string; expires_in: number };
    const next = NextResponse.next();
    const secure = process.env.NODE_ENV === "production";
    next.cookies.set(ACCESS_COOKIE, token.access_token, { httpOnly: true, secure, sameSite: "strict", path: "/", maxAge: token.expires_in });
    next.cookies.set(REFRESH_COOKIE, token.refresh_token, { httpOnly: true, secure, sameSite: "strict", path: "/", maxAge: 60 * 60 * 24 * 30 });
    return next;
  } catch {
    return NextResponse.redirect(new URL("/login", request.url));
  }
}
