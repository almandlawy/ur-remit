import { describe, expect, it } from "vitest";
import { buildServer } from "./server.js";

const config = {
  NODE_ENV: "test" as const,
  HOST: "127.0.0.1",
  PORT: 8080,
  DATABASE_URL: "postgres://test:test@127.0.0.1:5432/test",
  TRUST_PROXY: false
};

describe("public API", () => {
  it("returns a versioned health response", async () => {
    const app = await buildServer(config);
    const response = await app.inject({ method: "GET", url: "/api/v1/health" });
    expect(response.statusCode).toBe(200);
    expect(response.json()).toMatchObject({ status: "ok", service: "ur-public-api" });
    await app.close();
  });

  it("does not expose unversioned API routes", async () => {
    const app = await buildServer(config);
    const response = await app.inject({ method: "GET", url: "/api/rates" });
    expect(response.statusCode).toBe(404);
    expect(response.json().error.code).toBe("RESOURCE_NOT_FOUND");
    await app.close();
  });
});

