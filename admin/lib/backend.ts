import "server-only";

const backendURL = process.env.UR_BACKEND_URL ?? "http://127.0.0.1:8080";

export async function backendRequest(path: string, init: RequestInit = {}) {
  return fetch(`${backendURL}${path}`, { ...init, cache: "no-store", headers: { "content-type": "application/json", ...init.headers } });
}

