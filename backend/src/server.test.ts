import { describe, expect, it } from "vitest";
import { buildServer } from "./server.js";
import type { PublicStore } from "./store.js";

const config = {
  NODE_ENV: "test" as const, HOST: "127.0.0.1", PORT: 8080,
  DATABASE_URL: "postgres://test:test@127.0.0.1:5432/test",
  LOOKUP_HASH_KEY: "test-key-with-at-least-thirty-two-characters",
  ADMIN_SESSION_HASH_KEY: "independent-admin-session-test-key-32-chars",
  TRUST_PROXY: false
};

function makeStore(overrides: Partial<PublicStore> = {}): PublicStore {
  return {
    health: async () => true, listRates: async () => [], getRate: async () => null, rateHistory: async () => [],
    listCountries: async () => [], listCities: async () => [], listRoutes: async () => [],
    listOffices: async () => [], publicConfig: async () => ({}), listNotices: async () => [],
    verifyAgent: async () => null, trackTransfer: async () => null,
    close: async () => undefined, ...overrides
  };
}

describe("public API", () => {
  it("returns a friendly landing response at the root instead of a 404", async () => {
    const app = await buildServer(config, makeStore());
    const response = await app.inject({ method: "GET", url: "/" });
    expect(response.statusCode).toBe(200);
    expect(response.json()).toMatchObject({ service: "ur-public-api", status: "running", health: "/api/v1/health" });
    await app.close();
  });

  it("returns database-aware versioned health", async () => {
    const app = await buildServer(config, makeStore());
    const response = await app.inject({ method: "GET", url: "/api/v1/health" });
    expect(response.statusCode).toBe(200);
    expect(response.json()).toMatchObject({ status: "ok", dependencies: { database: "ok" } });
    await app.close();
  });

  it("returns degraded health when the database is unavailable", async () => {
    const app = await buildServer(config, makeStore({ health: async () => false }));
    const response = await app.inject({ method: "GET", url: "/api/v1/health" });
    expect(response.statusCode).toBe(503);
    expect(response.json().status).toBe("degraded");
    await app.close();
  });

  it("does not expose unversioned API routes", async () => {
    const app = await buildServer(config, makeStore());
    const response = await app.inject({ method: "GET", url: "/api/rates" });
    expect(response.statusCode).toBe(404);
    await app.close();
  });

  it("rejects invalid rate filters before the store", async () => {
    const app = await buildServer(config, makeStore());
    const response = await app.inject({ method: "GET", url: "/api/v1/mobile/rates?country=IRAQ" });
    expect(response.statusCode).toBe(400);
    expect(response.json().error.code).toBe("INVALID_INPUT");
    await app.close();
  });

  it("serves rate history from the dedicated route", async () => {
    let called = false;
    const app = await buildServer(config, makeStore({ rateHistory: async () => { called = true; return []; } }));
    const response = await app.inject({ method: "GET", url: "/api/v1/mobile/rates/history" });
    expect(response.statusCode).toBe(200);
    expect(called).toBe(true);
    await app.close();
  });

  it("loads public configuration from the store", async () => {
    const app = await buildServer(config, makeStore({ publicConfig: async () => ({ maintenanceMode: true }) }));
    const response = await app.inject({ method: "GET", url: "/api/v1/mobile/app-config" });
    expect(response.json().data).toEqual({ maintenanceMode: true });
    await app.close();
  });

  it("returns only the minimal agent verification contract", async () => {
    const app = await buildServer(config, makeStore({ verifyAgent: async () => ({
      tradeName: "Approved Office", country: { ar: "العراق", en: "Iraq" },
      city: { ar: "بغداد", en: "Baghdad" }, status: "VERIFIED"
    }) }));
    const response = await app.inject({ method: "GET", url: "/api/v1/mobile/agents/verify?code=AGENT-22" });
    expect(response.statusCode).toBe(200);
    expect(Object.keys(response.json().data).sort()).toEqual(["city", "country", "status", "tradeName"]);
    await app.close();
  });

  it("uses a generic response for unknown valid references", async () => {
    const app = await buildServer(config, makeStore());
    const response = await app.inject({ method: "GET", url: "/api/v1/mobile/transfers/UR-12345678/status" });
    expect(response.statusCode).toBe(404);
    expect(response.json().error.code).toBe("TRACKING_UNAVAILABLE");
    await app.close();
  });

  it("rejects malformed tracking references", async () => {
    const app = await buildServer(config, makeStore());
    const response = await app.inject({ method: "GET", url: "/api/v1/mobile/transfers/123/status" });
    expect(response.statusCode).toBe(400);
    await app.close();
  });
});
