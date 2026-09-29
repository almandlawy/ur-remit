import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const moduleDirectory = path.dirname(fileURLToPath(import.meta.url));

/**
 * Supabase issues every project's Postgres/pooler TLS certificate from the
 * same fleet-wide "Supabase Root 2021 CA" (verified against the live TLS
 * chain of a Supabase pooler host). It is not project-specific and is not a
 * secret — it is the same public root CA every Supabase user would download
 * from Database Settings → SSL Configuration. Bundling it lets verify-full
 * TLS work out of the box against any *.supabase.co / *.supabase.com host
 * without requiring manual certificate downloads or PGSSLROOTCERT setup.
 */
const BUNDLED_SUPABASE_CA_PATH = path.join(moduleDirectory, "..", "certs", "supabase-prod-ca-2021.crt");

function isSupabaseHost(hostname: string): boolean {
  return hostname.endsWith(".supabase.co") || hostname.endsWith(".supabase.com");
}

/**
 * Reads the Postgres root CA certificate for verify-full TLS connections
 * (for example, Supabase's project-provided CA certificate) from the given
 * file path. Returns undefined if no path is configured, letting Node use
 * its default trust store instead.
 */
function readRootCertificate(caCertificatePath: string | undefined): string | undefined {
  if (!caCertificatePath) return undefined;
  try {
    return readFileSync(caCertificatePath, "utf8");
  } catch {
    return undefined;
  }
}

export function postgresSSLConfig(
  databaseURL: string,
  nodeEnvironment = process.env.NODE_ENV,
  caCertificatePath = process.env.PGSSLROOTCERT
) {
  const hostname = new URL(databaseURL).hostname;
  const localHosts = ["localhost", "127.0.0.1", "::1", "[::1]"];

  if (nodeEnvironment === "production" || !localHosts.includes(hostname)) {
    const effectivePath = caCertificatePath ?? (isSupabaseHost(hostname) ? BUNDLED_SUPABASE_CA_PATH : undefined);
    const ca = readRootCertificate(effectivePath);
    return ca ? { rejectUnauthorized: true, ca } : { rejectUnauthorized: true };
  }
  return undefined;
}
