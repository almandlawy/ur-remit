import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { postgresSSLConfig } from "./postgres-ssl.js";

const bundledSupabaseCA = readFileSync(
  join(import.meta.dirname, "..", "certs", "supabase-prod-ca-2021.crt"),
  "utf8"
);

describe("Postgres TLS configuration", () => {
  it("uses verified TLS with the bundled Supabase root CA for Supabase hosts in development", () => {
    expect(postgresSSLConfig("postgresql://user:pass@db.example.supabase.co:5432/postgres", "development"))
      .toEqual({ rejectUnauthorized: true, ca: bundledSupabaseCA });
  });

  it("uses verified TLS without a bundled CA for non-Supabase remote hosts", () => {
    expect(postgresSSLConfig("postgresql://user:pass@db.example.com:5432/postgres", "development"))
      .toEqual({ rejectUnauthorized: true });
  });

  it("keeps local development databases on the existing non-TLS setup", () => {
    expect(postgresSSLConfig("postgresql://user:pass@127.0.0.1:5432/ur_local", "development"))
      .toBeUndefined();
  });

  it("requires verified TLS for production databases", () => {
    expect(postgresSSLConfig("postgresql://user:pass@localhost:5432/ur_local", "production"))
      .toEqual({ rejectUnauthorized: true });
  });

  describe("with an explicitly configured root CA certificate override", () => {
    let certificateDirectory: string;
    let certificatePath: string;

    afterEach(() => {
      if (certificateDirectory) rmSync(certificateDirectory, { recursive: true, force: true });
    });

    it("loads and forwards a custom CA certificate for verify-full connections", () => {
      certificateDirectory = mkdtempSync(join(tmpdir(), "pg-ca-"));
      certificatePath = join(certificateDirectory, "root.crt");
      writeFileSync(certificatePath, "-----BEGIN CERTIFICATE-----\nFAKE\n-----END CERTIFICATE-----\n");

      expect(postgresSSLConfig("postgresql://user:pass@db.example.supabase.co:5432/postgres", "development", certificatePath))
        .toEqual({ rejectUnauthorized: true, ca: "-----BEGIN CERTIFICATE-----\nFAKE\n-----END CERTIFICATE-----\n" });
    });

    it("still requires TLS but skips the ca option when an explicit CA path is unreadable", () => {
      expect(postgresSSLConfig("postgresql://user:pass@db.example.supabase.co:5432/postgres", "development", "/nonexistent/path/root.crt"))
        .toEqual({ rejectUnauthorized: true });
    });
  });
});
