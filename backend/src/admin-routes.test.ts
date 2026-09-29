import { describe, expect, it } from "vitest";
import { buildServer } from "./server.js";
import type { AdminStore } from "./admin-store.js";
import type { PublicStore } from "./store.js";

const config = {
  NODE_ENV: "test" as const, HOST: "127.0.0.1", PORT: 8080,
  DATABASE_URL: "postgres://test:test@127.0.0.1:5432/test",
  LOOKUP_HASH_KEY: "test-key-with-at-least-thirty-two-characters",
  ADMIN_SESSION_HASH_KEY: "independent-admin-session-test-key-32-chars", TRUST_PROXY: false
  , ADMIN_MFA_ENCRYPTION_KEY: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
};
const token = "A_secure_test_session_token_1234567890";

function publicStore(): PublicStore {
  return {
    health: async () => true, listRates: async () => [], getRate: async () => null, rateHistory: async () => [],
    listCountries: async () => [], listCities: async () => [], listRoutes: async () => [], listOffices: async () => [],
    publicConfig: async () => ({}), listNotices: async () => [], verifyAgent: async () => null,
    trackTransfer: async () => null, close: async () => undefined
  };
}

function adminStore(permissions: string[]): AdminStore {
  return {
    login: async () => null,
    authenticate: async () => ({ id: "c65d937a-e48f-4be1-83e6-1934534dad10", role: "PRICE_MANAGER", permissions }),
    dashboard: async () => ({ activeRoutes: 3, recentActivity: [
      { action: "UPDATE", entityType: "rate", entityId: "69c9fe66-775e-4234-8b87-ca9e670342c9", createdAt: "2026-09-24T10:00:00.000Z", actorEmail: "admin@urremit.com" }
    ] }),
    updateRate: async (_id, update, actor, requestId) => ({ ...update, actorId: actor.id, requestId }),
    close: async () => undefined
  };
}

describe("admin API", () => {
  it("issues a session only after the store verifies password and MFA", async () => {
    const store = adminStore([]);
    store.login = async () => ({ token: "issued-session", expiresAt: "2026-09-25T01:00:00.000Z" });
    const app = await buildServer(config, publicStore(), store);
    const response = await app.inject({ method: "POST", url: "/api/v1/admin/auth/login",
      payload: { email: "admin@urremit.com", password: "a-secure-password-value", otp: "123456" } });
    expect(response.statusCode).toBe(200);
    expect(response.json().data.token).toBe("issued-session");
    await app.close();
  });

  it("accepts a blank OTP field for accounts configured without MFA", async () => {
    const store = adminStore([]);
    store.login = async (credentials) => {
      expect(credentials.otp).toBe("");
      return { token: "password-only-local-session", expiresAt: "2026-09-25T01:00:00.000Z" };
    };
    const app = await buildServer(config, publicStore(), store);
    const response = await app.inject({ method: "POST", url: "/api/v1/admin/auth/login",
      payload: { email: "admin@urremit.com", password: "a-secure-password-value", otp: "" } });
    expect(response.statusCode).toBe(200);
    await app.close();
  });

  it("returns a generic login failure", async () => {
    const app = await buildServer(config, publicStore(), adminStore([]));
    const response = await app.inject({ method: "POST", url: "/api/v1/admin/auth/login",
      payload: { email: "admin@urremit.com", password: "a-secure-password-value", otp: "123456" } });
    expect(response.statusCode).toBe(401);
    expect(response.json().error.code).toBe("INVALID_CREDENTIALS");
    await app.close();
  });

  it("rejects missing session credentials", async () => {
    const store = adminStore(["dashboard.read"]); store.authenticate = async () => null;
    const app = await buildServer(config, publicStore(), store);
    const response = await app.inject({ method: "GET", url: "/api/v1/admin/dashboard" });
    expect(response.statusCode).toBe(401);
    expect(response.json().error.code).toBe("UNAUTHORIZED");
    await app.close();
  });

  it("enforces permissions after authentication", async () => {
    const app = await buildServer(config, publicStore(), adminStore([]));
    const response = await app.inject({ method: "GET", url: "/api/v1/admin/dashboard", headers: { authorization: `Bearer ${token}` } });
    expect(response.statusCode).toBe(403);
    await app.close();
  });

  it("returns dashboard data to an authorized role", async () => {
    const app = await buildServer(config, publicStore(), adminStore(["dashboard.read"]));
    const response = await app.inject({ method: "GET", url: "/api/v1/admin/dashboard", headers: { authorization: `Bearer ${token}` } });
    expect(response.statusCode).toBe(200);
    expect(response.json().data.activeRoutes).toBe(3);
    await app.close();
  });

  it("includes recent audit activity in the dashboard payload for authorized roles", async () => {
    const app = await buildServer(config, publicStore(), adminStore(["dashboard.read"]));
    const response = await app.inject({ method: "GET", url: "/api/v1/admin/dashboard", headers: { authorization: `Bearer ${token}` } });
    expect(response.statusCode).toBe(200);
    const activity = response.json().data.recentActivity;
    expect(Array.isArray(activity)).toBe(true);
    expect(activity[0].action).toBe("UPDATE");
    expect(activity[0].actorEmail).toBe("admin@urremit.com");
    await app.close();
  });

  it("validates Decimal rate updates and invokes the audited write", async () => {
    const app = await buildServer(config, publicStore(), adminStore(["rates.write"]));
    const response = await app.inject({
      method: "PATCH", url: "/api/v1/admin/rates/69c9fe66-775e-4234-8b87-ca9e670342c9",
      headers: { authorization: `Bearer ${token}` }, payload: { buy: "1570.125", active: true }
    });
    expect(response.statusCode).toBe(200);
    expect(response.json().data.buy).toBe("1570.125");
    await app.close();
  });

  it("rejects floating-point and malformed monetary input", async () => {
    const app = await buildServer(config, publicStore(), adminStore(["rates.write"]));
    const response = await app.inject({
      method: "PATCH", url: "/api/v1/admin/rates/69c9fe66-775e-4234-8b87-ca9e670342c9",
      headers: { authorization: `Bearer ${token}` }, payload: { buy: 1570.125 }
    });
    expect(response.statusCode).toBe(400);
    await app.close();
  });
});
