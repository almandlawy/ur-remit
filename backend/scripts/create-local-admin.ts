/**
 * Local development helper: creates (or updates) an admin_users row on the
 * database referenced by DATABASE_URL, so you can log into the URAdmin
 * dashboard locally. This never touches any hosted/production database on
 * its own — it only talks to whatever DATABASE_URL your local .env points
 * at. It is NOT wired into any HTTP route and must be invoked manually.
 *
 * Usage (from backend/):
 *   ADMIN_EMAIL=you@example.com ADMIN_PASSWORD='a-strong-unique-password' \
 *     ADMIN_ROLE=SUPER_ADMIN npx tsx scripts/create-local-admin.ts
 *
 * ADMIN_ROLE defaults to SUPER_ADMIN and must be one of the roles seeded in
 * backend/db/002_admin_sessions.sql (SUPER_ADMIN, COUNTRY_MANAGER,
 * COMPLIANCE_OFFICER, SUPPORT_EMPLOYEE, CONTENT_MANAGER, PRICE_MANAGER,
 * VIEWER).
 *
 * MFA is disabled for this local development account. Do not reuse this
 * password or account in production.
 */
import { Pool } from "pg";
import { loadConfig, loadLocalEnvironment } from "../src/config.js";
import { hashPassword } from "../src/admin-auth.js";

loadLocalEnvironment();

async function main() {
  const email = process.env.ADMIN_EMAIL?.trim().toLowerCase();
  const password = process.env.ADMIN_PASSWORD;
  const roleName = process.env.ADMIN_ROLE?.trim().toUpperCase() ?? "SUPER_ADMIN";

  if (!email || !password) {
    console.error("Missing ADMIN_EMAIL or ADMIN_PASSWORD environment variables.");
    console.error("Example: ADMIN_EMAIL=you@example.com ADMIN_PASSWORD='a-strong-unique-password' npx tsx scripts/create-local-admin.ts");
    process.exit(1);
  }
  if (password.length < 12) {
    console.error("ADMIN_PASSWORD must be at least 12 characters.");
    process.exit(1);
  }

  const config = loadConfig();
  const database = new URL(config.DATABASE_URL);
  if (!["localhost", "127.0.0.1", "::1", "[::1]"].includes(database.hostname) || database.pathname !== "/ur_local") {
    console.error("Refusing to continue: this helper only permits localhost databases named ur_local.");
    process.exit(1);
  }
  const pool = new Pool({ connectionString: config.DATABASE_URL });

  try {
    const role = await pool.query<{ id: string }>("SELECT id FROM roles WHERE name = $1", [roleName]);
    if (role.rowCount === 0) {
      console.error(`Role "${roleName}" not found. Run backend/db/002_admin_sessions.sql first, or pick one of: SUPER_ADMIN, COUNTRY_MANAGER, COMPLIANCE_OFFICER, SUPPORT_EMPLOYEE, CONTENT_MANAGER, PRICE_MANAGER, VIEWER.`);
      process.exit(1);
    }

    const passwordHash = await hashPassword(password);

    const result = await pool.query<{ id: string }>(
      `INSERT INTO admin_users (email, password_hash, role_id, mfa_required, mfa_secret_ciphertext)
       VALUES ($1, $2, $3, false, NULL)
       ON CONFLICT (email) DO UPDATE
         SET password_hash = EXCLUDED.password_hash,
             role_id = EXCLUDED.role_id,
             mfa_secret_ciphertext = EXCLUDED.mfa_secret_ciphertext,
             mfa_required = false,
             failed_login_count = 0,
             locked_until = NULL,
             disabled_at = NULL
       RETURNING id`,
      [email, passwordHash, role.rows[0]!.id]
    );

    console.log("\n✅ Admin account ready.");
    console.log(`   id:    ${result.rows[0]!.id}`);
    console.log(`   email: ${email}`);
    console.log(`   role:  ${roleName}`);
    console.log("\nMFA is disabled for this LOCAL development account.");
    console.log("Log in at http://localhost:3000/login with your email and password only.");
  } finally {
    await pool.end();
  }
}

main().catch((error) => {
  console.error("Failed to create local admin:", error);
  process.exit(1);
});
