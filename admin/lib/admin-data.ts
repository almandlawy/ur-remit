import "server-only";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { backendRequest } from "@/lib/backend";

export async function adminData<T>(path: string): Promise<{ data: T | null; forbidden: boolean }> {
  const token = (await cookies()).get("ur_admin_session")?.value;
  if (!token) redirect("/login");
  const response = await backendRequest(`/api/v1/admin/${path}`, {
    headers: { authorization: `Bearer ${token}` }
  });
  if (response.status === 401) redirect("/login");
  if (response.status === 403) return { data: null, forbidden: true };
  if (!response.ok) throw new Error(`Admin service request failed (${response.status})`);
  const payload = await response.json() as { data: T };
  return { data: payload.data, forbidden: false };
}
