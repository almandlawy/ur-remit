import { cookies } from "next/headers";
import { NextResponse } from "next/server";
import { isSameOriginRequest } from "@/lib/api-security";
import { backendRequest } from "@/lib/backend";

type RouteContext = { params: Promise<{ path: string[] }> };

function allowedPath(method: string, segments: string[]): string | null {
  const path = segments.join("/");
  if (method === "POST" && path === "auth/change-password")
    return "/api/v1/admin/auth/change-password";
  if (method === "GET" && ["rates", "offices", "agents", "users", "audit"].includes(path))
    return `/api/v1/admin/${path}`;
  if (method === "POST" && path === "offices") return "/api/v1/admin/offices";
  if (segments.length === 2 && /^[0-9a-f-]{36}$/i.test(segments[1] ?? "")) {
    if (method === "PATCH" && segments[0] === "rates")
      return `/api/v1/admin/rates/${encodeURIComponent(segments[1]!)}`;
    if (method === "PATCH" && segments[0] === "offices")
      return `/api/v1/admin/offices/${encodeURIComponent(segments[1]!)}`;
    if (method === "DELETE" && segments[0] === "offices")
      return `/api/v1/admin/offices/${encodeURIComponent(segments[1]!)}`;
  }
  return null;
}

async function proxy(request: Request, context: RouteContext, method: "GET" | "POST" | "PATCH" | "DELETE") {
  if (method !== "GET" && !isSameOriginRequest(request))
    return NextResponse.json({ error: "CSRF_REJECTED" }, { status: 403 });

  const path = allowedPath(method, (await context.params).path);
  if (!path) return NextResponse.json({ error: "NOT_FOUND" }, { status: 404 });

  const token = (await cookies()).get("ur_admin_session")?.value;
  if (!token) return NextResponse.json({ error: "UNAUTHORIZED" }, { status: 401 });

  const init: RequestInit = {
    method,
    headers: { authorization: `Bearer ${token}` }
  };
  if (method !== "GET" && method !== "DELETE") {
    let body: unknown;
    try { body = await request.json(); }
    catch { return NextResponse.json({ error: "INVALID_JSON" }, { status: 400 }); }
    init.headers = { ...init.headers, "content-type": "application/json" };
    init.body = JSON.stringify(body);
  }

  const response = await backendRequest(path, init);
  const result = new NextResponse(await response.text(), {
    status: response.status,
    headers: { "content-type": response.headers.get("content-type") ?? "application/json" }
  });
  if (path === "/api/v1/admin/auth/change-password" && response.ok)
    result.cookies.delete("ur_admin_session");
  return result;
}

export const GET = (request: Request, context: RouteContext) => proxy(request, context, "GET");
export const POST = (request: Request, context: RouteContext) => proxy(request, context, "POST");
export const PATCH = (request: Request, context: RouteContext) => proxy(request, context, "PATCH");
export const DELETE = (request: Request, context: RouteContext) => proxy(request, context, "DELETE");
