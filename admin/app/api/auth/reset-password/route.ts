import { NextResponse } from "next/server";
import { isSameOriginRequest } from "@/lib/api-security";
import { backendRequest } from "@/lib/backend";

/**
 * Completes the password-recovery flow started by /api/auth/forgot-password.
 * The recovery access token lives only in the URL fragment on the client
 * (never sent to any server automatically), so the client posts it here
 * explicitly, scoped to this one request, to set the new password.
 */
export async function POST(request: Request) {
  if (!isSameOriginRequest(request)) return NextResponse.json({ error: "CSRF_REJECTED" }, { status: 403 });
  const body = await request.json().catch(() => null) as { accessToken?: unknown; newPassword?: unknown } | null;
  const accessToken = typeof body?.accessToken === "string" ? body.accessToken : "";
  const newPassword = typeof body?.newPassword === "string" ? body.newPassword : "";
  if (!accessToken || newPassword.length < 8)
    return NextResponse.json({ error: "INVALID_INPUT" }, { status: 400 });

  const upstream = await backendRequest("/api/v1/admin/auth/reset-password", {
    method: "POST",
    body: JSON.stringify({ accessToken, newPassword })
  });
  if (!upstream.ok) return NextResponse.json({ error: "INVALID_RESET_LINK" }, { status: upstream.status });
  return NextResponse.json({ ok: true });
}
