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
 * The script prints a base32 TOTP secret ONCE. Add it to an authenticator
 * app (e.g. Google Authenticator, 1Password) immediately — it is not stored
 * anywhere in plaintext and cannot be recovered afterwards; you would need
 * to re-run this script to rotate it.
 */
import { config } from "dotenv";
import { randomBytes } from "node:crypto";
import { Pool } from "pg";
import { loadConfig } from "../src/config.js";
import { encryptMFASecret, hashPassword } from "../src/admin-auth.js";

config();

function encodeBase32(bytes: Buffer): string {
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
  let bits = "";
  for (const byte of bytes) bits += byte.toString(2).padStart(8, "0");
  let output = "";
  for (let index = 0; index + 5 <= bits.length; index += 5) {
    output += alphabet[Number.parseInt(bits.slice(index, index + 5), 2)];
  }
  return output;
}

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
  const pool = new Pool({ connectionString: config.DATABASE_URL });

  try {
    const role = await pool.query<{ id: string }>("SELECT id FROM roles WHERE name = $1", [roleName]);
    if (role.rowCount === 0) {
      console.error(`Role "${roleName}" not found. Run backend/db/002_admin_sessions.sql first, or pick one of: SUPER_ADMIN, COUNTRY_MANAGER, COMPLIANCE_OFFICER, SUPPORT_EMPLOYEE, CONTENT_MANAGER, PRICE_MANAGER, VIEWER.`);
      process.exit(1);
    }

    const passwordHash = await hashPassword(password);
    const totpSecret = encodeBase32(randomBytes(20));
    const mfaSecretCiphertext = encryptMFASecret(totpSecret, config.ADMIN_MFA_ENCRYPTION_KEY);

    const result = await pool.query<{ id: string }>(
      `INSERT INTO admin_users (email, password_hash, role_id, mfa_required, mfa_secret_ciphertext)
       VALUES ($1, $2, $3, true, $4)
       ON CONFLICT (email) DO UPDATE
         SET password_hash = EXCLUDED.password_hash,
             role_id = EXCLUDED.role_id,
             mfa_secret_ciphertext = EXCLUDED.mfa_secret_ciphertext,
             failed_login_count = 0,
             locked_until = NULL,
             disabled_at = NULL
       RETURNING id`,
      [email, passwordHash, role.rows[0]!.id, mfaSecretCiphertext]
    );

    console.log("\n✅ Admin account ready.");
    console.log(`   id:    ${result.rows[0]!.id}`);
    console.log(`   email: ${email}`);
    console.log(`   role:  ${roleName}`);
    console.log(`\n🔑 TOTP secret (add to your authenticator app now, shown only once):`);
    console.log(`   ${totpSecret}`);
    console.log(`\nLog in at http://localhost:3000/login with your email + password, then the 6-digit code.`);
  } finally {
    await pool.end();
  }
}

main().catch((error) => {
  console.error("Failed to create local admin:", error);
  process.exit(1);
});
