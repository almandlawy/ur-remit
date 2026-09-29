import { NextResponse } from "next/server";
import { cookies } from "next/headers";
import { isSameOriginRequest } from "@/lib/api-security";
import { backendRequest } from "@/lib/backend";

export async function GET() {
  const token = (await cookies()).get("ur_admin_session")?.value;
  if (!token) return NextResponse.json({ error: "UNAUTHORIZED" }, { status: 401 });
  const upstream = await backendRequest("/api/v1/admin/me", { headers: { authorization: `Bearer ${token}` } });
  return new NextResponse(await upstream.text(), {
    status: upstream.status,
    headers: { "content-type": upstream.headers.get("content-type") ?? "application/json", "cache-control": "no-store" }
  });
}

export async function POST(request: Request) {
  if (!isSameOriginRequest(request)) return NextResponse.json({ error: "CSRF_REJECTED" }, { status: 403 });
  const body = await request.json().catch(() => null);
  const upstream = await backendRequest("/api/v1/admin/auth/login", { method: "POST", body: JSON.stringify(body) });
  if (!upstream.ok) return NextResponse.json({ error: "INVALID_CREDENTIALS" }, { status: upstream.status });
  const payload = await upstream.json() as { data: { token: string; expiresAt: string } };
  if (!payload.data?.token || !payload.data.expiresAt || !Number.isFinite(Date.parse(payload.data.expiresAt)))
    return NextResponse.json({ error: "AUTH_SERVICE_ERROR" }, { status: 502 });
  const result = NextResponse.json({ ok: true });
  result.cookies.set("ur_admin_session", payload.data.token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "strict",
    path: "/",
    expires: new Date(payload.data.expiresAt)
  });
  return result;
}

export async function DELETE(request: Request) {
  if (!isSameOriginRequest(request)) return NextResponse.json({ error: "CSRF_REJECTED" }, { status: 403 });
  const token = (await cookies()).get("ur_admin_session")?.value;
  if (token) {
    const upstream = await backendRequest("/api/v1/admin/auth/logout", {
      method: "POST",
      headers: { authorization: `Bearer ${token}` }
    });
    if (!upstream.ok && upstream.status !== 401)
      return NextResponse.json({ error: "LOGOUT_FAILED" }, { status: upstream.status });
  }
  const response = NextResponse.json({ ok: true });
  response.cookies.delete("ur_admin_session");
  return response;
}
