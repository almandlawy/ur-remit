import { cookies } from "next/headers";
import { NextResponse } from "next/server";
import { isSameOriginRequest } from "@/lib/api-security";
import { backendRequest } from "@/lib/backend";

export async function PATCH(request: Request, context: { params: Promise<{ id: string }> }) {
  if (!isSameOriginRequest(request)) return NextResponse.json({ error: "CSRF_REJECTED" }, { status: 403 });
  const [{ id }, cookieStore, body] = await Promise.all([context.params, cookies(), request.json().catch(() => null)]);
  const token = cookieStore.get("ur_admin_session")?.value;
  if (!token) return NextResponse.json({ error: "UNAUTHORIZED" }, { status: 401 });
  const response = await backendRequest(`/api/v1/admin/rates/${encodeURIComponent(id)}`, { method: "PATCH",
    headers: { authorization: `Bearer ${token}` }, body: JSON.stringify(body) });
  return new NextResponse(await response.text(), { status: response.status, headers: { "content-type": "application/json" } });
}
