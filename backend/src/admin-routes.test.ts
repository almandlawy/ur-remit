import { describe, expect, it } from "vitest";
import { buildServer } from "./server.js";
import type { AdminStore } from "./admin-store.js";
import type { PublicStore } from "./store.js";

const config = {
  NODE_ENV: "test" as const, HOST: "127.0.0.1", PORT: 8080,
  DATABASE_URL: "postgres://test:test@127.0.0.1:5432/test",
  LOOKUP_HASH_KEY: "test-key-with-at-least-thirty-two-characters",
  ADMIN_SESSION_HASH_KEY: "independent-admin-session-test-key-32-chars", TRUST_PROXY: false
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
    revokeSession: async () => undefined,
    dashboard: async () => ({ activeRoutes: 3 }),
    listRates: async () => [],
    updateRate: async (_id, update, actor, requestId) => ({ ...update, actorId: actor.id, requestId }),
    listOffices: async () => [],
    createOffice: async (input) => ({ ...input, id: "93c7b4b1-14aa-4622-bbad-0d3a470c89c2" }),
    updateOffice: async (id, input) => ({ ...input, id }),
    deleteOffice: async () => true,
    listAgents: async () => [],
    listAdmins: async () => [],
    auditLog: async () => [],
    changePassword: async () => true,
    close: async () => undefined
  };
}

describe("admin API", () => {
  it("issues a session after the store verifies the username and password", async () => {
    const store = adminStore([]);
    store.login = async () => ({ token: "issued-session", expiresAt: "2026-09-25T01:00:00.000Z" });
    const app = await buildServer(config, publicStore(), store);
    const response = await app.inject({ method: "POST", url: "/api/v1/admin/auth/login",
      payload: { username: "Almandlawy", password: "a-secure-password-value" } });
    expect(response.statusCode).toBe(200);
    expect(response.json().data.token).toBe("issued-session");
    await app.close();
  });

  it("returns a generic login failure", async () => {
    const app = await buildServer(config, publicStore(), adminStore([]));
    const response = await app.inject({ method: "POST", url: "/api/v1/admin/auth/login",
      payload: { username: "Almandlawy", password: "a-secure-password-value" } });
    expect(response.statusCode).toBe(401);
    expect(response.json().error.code).toBe("INVALID_CREDENTIALS");
    await app.close();
  });

  it("accepts an admin username and password without an authenticator code", async () => {
    const store = adminStore([]);
    store.login = async () => ({ token: "password-only-session", expiresAt: "2026-09-25T01:00:00.000Z" });
    const app = await buildServer(config, publicStore(), store);
    const response = await app.inject({
      method: "POST",
      url: "/api/v1/admin/auth/login",
      payload: { username: "Almandlawy", password: "a-secure-password-value" }
    });
    expect(response.statusCode).toBe(200);
    expect(response.json().data.token).toBe("password-only-session");
    await app.close();
  });

  it("rejects malformed credentials without an authenticator code", async () => {
    const app = await buildServer(config, publicStore(), adminStore([]));
    const response = await app.inject({
      method: "POST",
      url: "/api/v1/admin/auth/login",
      payload: { username: "Almandlawy", password: "short" }
    });
    expect(response.statusCode).toBe(400);
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

  it("revokes an authenticated admin session on logout", async () => {
    let revoked = false;
    const store = adminStore([]);
    store.revokeSession = async () => { revoked = true; };
    const app = await buildServer(config, publicStore(), store);
    const response = await app.inject({
      method: "POST",
      url: "/api/v1/admin/auth/logout",
      headers: { authorization: `Bearer ${token}` }
    });
    expect(response.statusCode).toBe(200);
    expect(revoked).toBe(true);
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

  it("rejects rate updates without write permission", async () => {
    const app = await buildServer(config, publicStore(), adminStore(["rates.read"]));
    const response = await app.inject({
      method: "PATCH",
      url: "/api/v1/admin/rates/69c9fe66-775e-4234-8b87-ca9e670342c9",
      headers: { authorization: "Bearer " + token },
      payload: { buy: "1570.125" }
    });
    expect(response.statusCode).toBe(403);
    await app.close();
  });

  it("creates an office with a validated payload for an authorized admin", async () => {
    const store = adminStore(["offices.write"]);
    const app = await buildServer(config, publicStore(), store);
    const response = await app.inject({
      method: "POST",
      url: "/api/v1/admin/offices",
      headers: { authorization: ["Bearer", token].join(" ") },
      payload: {
        countryId: "c65d937a-e48f-4be1-83e6-1934534dad10",
        cityId: "93c7b4b1-14aa-4622-bbad-0d3a470c89c2",
        publicCode: "BAG-01",
        nameArabic: "مكتب بغداد",
        nameEnglish: "Baghdad Office",
        addressArabic: "بغداد",
        addressEnglish: "Baghdad"
      }
    });
    expect(response.statusCode).toBe(201);
    expect(response.json().data.publicCode).toBe("BAG-01");
    await app.close();
  });

  it("rejects office creation when required fields are missing", async () => {
    let called = false;
    const store = adminStore(["offices.write"]);
    store.createOffice = async () => { called = true; return null; };
    const app = await buildServer(config, publicStore(), store);
    const response = await app.inject({
      method: "POST",
      url: "/api/v1/admin/offices",
      headers: { authorization: ["Bearer", token].join(" ") },
      payload: { publicCode: "BAG-01" }
    });
    expect(response.statusCode).toBe(400);
    expect(called).toBe(false);
    await app.close();
  });

  it("does not allow an admin without office permission to create offices", async () => {
    const app = await buildServer(config, publicStore(), adminStore([]));
    const response = await app.inject({
      method: "POST",
      url: "/api/v1/admin/offices",
      headers: { authorization: ["Bearer", token].join(" ") },
      payload: {
        countryId: "c65d937a-e48f-4be1-83e6-1934534dad10",
        cityId: "93c7b4b1-14aa-4622-bbad-0d3a470c89c2",
        publicCode: "BAG-01",
        nameArabic: "مكتب بغداد",
        nameEnglish: "Baghdad Office",
        addressArabic: "بغداد",
        addressEnglish: "Baghdad"
      }
    });
    expect(response.statusCode).toBe(403);
    await app.close();
  });
});
