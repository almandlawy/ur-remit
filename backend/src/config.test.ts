import { describe, expect, it } from "vitest";
import { loadConfig } from "./config.js";

const validEnvironment = {
  DATABASE_URL: "postgresql://localhost:5432/ur",
  LOOKUP_HASH_KEY: "a-lookup-key-that-is-long-enough-32",
  ADMIN_SESSION_HASH_KEY: "a-distinct-session-key-long-enough-32"
};

describe("server network configuration", () => {
  it("binds to all interfaces in production by default", () => {
    expect(loadConfig({ ...validEnvironment, NODE_ENV: "production" }).HOST).toBe("0.0.0.0");
  });

  it("keeps local development bound to loopback by default", () => {
    expect(loadConfig({ ...validEnvironment, NODE_ENV: "development" }).HOST).toBe("127.0.0.1");
  });

  it("respects an explicitly configured host", () => {
    expect(loadConfig({ ...validEnvironment, NODE_ENV: "production", HOST: "127.0.0.1" }).HOST).toBe("127.0.0.1");
  });

  it("does not require an authenticator encryption key", () => {
    expect(() => loadConfig({ ...validEnvironment, NODE_ENV: "production" })).not.toThrow();
  });
});
