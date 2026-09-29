import { NextResponse } from "next/server";
import { isSameOriginRequest } from "@/lib/api-security";
import { backendRequest } from "@/lib/backend";

/**
 * Sends a Supabase password-recovery email so admins who previously only
 * signed in via Google can set a real password without touching the
 * Supabase dashboard. Always responds with { ok: true } regardless of
 * whether the email exists, to avoid leaking which addresses have access.
 */
export async function POST(request: Request) {
  if (!isSameOriginRequest(request)) return NextResponse.json({ error: "CSRF_REJECTED" }, { status: 403 });
  const body = await request.json().catch(() => null) as { email?: unknown } | null;
  const email = typeof body?.email === "string" ? body.email.trim() : "";
  if (!email) return NextResponse.json({ error: "EMAIL_REQUIRED" }, { status: 400 });

  const redirectTo = new URL("/reset-password", request.url).toString();
  await backendRequest("/api/v1/admin/auth/forgot-password", {
    method: "POST",
    body: JSON.stringify({ email, redirectTo })
  });
  return NextResponse.json({ ok: true });
}
