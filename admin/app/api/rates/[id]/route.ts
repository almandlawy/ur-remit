import { cookies } from "next/headers";
import { NextResponse } from "next/server";
import { ADMIN_ACCESS_COOKIE, supabaseRestRequest } from "@/lib/supabase";

const FIELD_MAP: Record<string, string> = { buy: "buy", sell: "sell", feeFixed: "fee_fixed", feePercent: "fee_percent" };

export async function PATCH(request: Request, context: { params: Promise<{ id: string }> }) {
  const [{ id }, cookieStore, body] = await Promise.all([context.params, cookies(), request.json().catch(() => null)]);
  const accessToken = cookieStore.get(ADMIN_ACCESS_COOKIE)?.value;
  if (!accessToken) return NextResponse.json({ error: "UNAUTHORIZED" }, { status: 401 });
  if (!body || typeof body !== "object") return NextResponse.json({ error: "INVALID_INPUT" }, { status: 422 });

  const update: Record<string, unknown> = {};
  for (const [key, column] of Object.entries(FIELD_MAP)) {
    const value = (body as Record<string, unknown>)[key];
    if (value !== undefined && value !== null && value !== "") update[column] = value;
  }
  if (Object.keys(update).length === 0) return NextResponse.json({ ok: true, data: [] });

  let response: Response;
  try {
    response = await supabaseRestRequest(`rates?id=eq.${encodeURIComponent(id)}`, {
      method: "PATCH",
      accessToken,
      headers: { Prefer: "return=representation" },
      body: JSON.stringify(update),
    });
  } catch {
    return NextResponse.json({ error: "SUPABASE_UNREACHABLE" }, { status: 503 });
  }

  if (response.status === 401) return NextResponse.json({ error: "UNAUTHORIZED" }, { status: 401 });
  if (!response.ok) return NextResponse.json({ error: "UPDATE_FAILED" }, { status: 502 });

  const rows = (await response.json().catch(() => [])) as unknown[];
  // PostgREST returns 200 with an empty array (not 403) when RLS silently blocks the write —
  // treat that as forbidden instead of reporting a false success.
  if (rows.length === 0) return NextResponse.json({ error: "FORBIDDEN" }, { status: 403 });

  return NextResponse.json({ ok: true, data: rows });
}
