export function isSameOriginRequest(request: Request): boolean {
  const origin = request.headers.get("origin");
  const host = request.headers.get("x-forwarded-host") ?? request.headers.get("host");
  const protocol = (request.headers.get("x-forwarded-proto") ?? new URL(request.url).protocol.slice(0, -1))
    .split(",")[0]?.trim();
  return Boolean(origin && host && origin === `${protocol}://${host.split(",")[0]?.trim()}`);
}
