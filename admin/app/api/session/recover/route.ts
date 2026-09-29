import { NextResponse } from "next/server";
import { isSupabaseConfigured, supabaseAuthRequest } from "@/lib/supabase";

/// Sends a Supabase-hosted "reset your password" email. Mirrors the iOS in-app admin console's
/// `requestPasswordReset` — needed here too because the web admin login has no other recovery path
/// for an account whose password was never set (e.g. created via Google sign-in) or was forgotten.
export async function POST(request: Request) {
  if (!isSupabaseConfigured()) {
    return NextResponse.json({ error: "SUPABASE_NOT_CONFIGURED" }, { status: 503 });
  }
  const body = (await request.json().catch(() => null)) as { email?: unknown } | null;
  const email = typeof body?.email === "string" ? body.email.trim() : "";
  if (!email) return NextResponse.json({ error: "INVALID_INPUT" }, { status: 422 });

  try {
    // Always report success to the caller regardless of Supabase's response: confirming or denying
    // whether an email is a registered admin account would leak which accounts exist.
    await supabaseAuthRequest("recover", { method: "POST", body: JSON.stringify({ email }) });
  } catch {
    return NextResponse.json({ error: "SUPABASE_UNREACHABLE" }, { status: 503 });
  }
  return NextResponse.json({ ok: true });
}
