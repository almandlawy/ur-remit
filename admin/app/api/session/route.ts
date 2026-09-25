import { NextResponse } from "next/server";
import { backendRequest } from "@/lib/backend";

export async function POST(request: Request) {
  const body = await request.json().catch(() => null);
  const response = await backendRequest("/api/v1/admin/auth/login", { method: "POST", body: JSON.stringify(body) });
  if (!response.ok) return NextResponse.json({ error: "INVALID_CREDENTIALS" }, { status: 401 });
  const payload = await response.json() as { data: { token: string; expiresAt: string } };
  const result = NextResponse.json({ ok: true });
  result.cookies.set("ur_admin_session", payload.data.token, { httpOnly: true, secure: process.env.NODE_ENV === "production",
    sameSite: "strict", path: "/", expires: new Date(payload.data.expiresAt) });
  return result;
}

export async function DELETE() {
  const response = NextResponse.json({ ok: true }); response.cookies.delete("ur_admin_session"); return response;
}

