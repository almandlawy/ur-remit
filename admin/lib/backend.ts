import "server-only";

export async function backendRequest(path: string, init: RequestInit = {}) {
  const backendURL = process.env.UR_BACKEND_URL;
  if (!backendURL) throw new Error("UR_BACKEND_URL must be configured on the Next.js server.");

  let origin: URL;
  try { origin = new URL(backendURL); }
  catch { throw new Error("UR_BACKEND_URL must be an absolute HTTP(S) URL."); }

  if (!["http:", "https:"].includes(origin.protocol))
    throw new Error("UR_BACKEND_URL must use HTTP or HTTPS.");
  if (process.env.NODE_ENV === "production" && origin.protocol !== "https:")
    throw new Error("UR_BACKEND_URL must use HTTPS in production.");
  if (!path.startsWith("/")) throw new Error("Backend paths must be absolute paths.");

  return fetch(new URL(path, origin), {
    ...init,
    cache: "no-store",
    headers: { "content-type": "application/json", ...init.headers }
  });
}
