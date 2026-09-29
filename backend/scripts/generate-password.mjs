import { randomBytes, randomUUID } from "node:crypto";
import { chmodSync, mkdirSync, openSync, closeSync, unlinkSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import pg from "pg";
import { hashPassword } from "../dist/admin-auth.js";

const BACKEND_DIR = dirname(dirname(fileURLToPath(import.meta.url)));
const LOCAL_DIR = join(BACKEND_DIR, ".local");
const username = process.argv[2] ?? "taha";

function saveSecret(path, value) {
  const fd = openSync(path, "wx", 0o600);
  try {
    writeFileSync(fd, value, { encoding: "utf8" });
  } finally {
    closeSync(fd);
  }
}

async function main() {
  if (!/^[A-Za-z0-9@._-]{4,254}$/.test(username)) throw new Error("Invalid username.");
  process.loadEnvFile(join(BACKEND_DIR, ".env"));
  if (!process.env.DATABASE_URL) throw new Error("DATABASE_URL is not configured.");

  mkdirSync(LOCAL_DIR, { recursive: true, mode: 0o700 });
  chmodSync(LOCAL_DIR, 0o700);

  const password = randomBytes(32).toString("base64url");
  const passwordHash = await hashPassword(password);
  const passwordFile = join(LOCAL_DIR, `admin-password-${username.toLowerCase()}.txt`);
  saveSecret(passwordFile, `Admin username: ${username}\nNew password: ${password}\n`);

  const client = new pg.Client({ connectionString: process.env.DATABASE_URL });
  try {
    await client.connect();
    await client.query("BEGIN");
    const { rows } = await client.query(
      "SELECT id, mfa_required FROM admin_users WHERE lower(username) = lower($1) AND disabled_at IS NULL FOR UPDATE",
      [username],
    );
    const admin = rows[0];
    if (!admin) throw new Error("Enabled admin account was not found.");
    if (!admin.mfa_required) throw new Error("Admin MFA is not required; refusing password rotation.");

    await client.query(
      `UPDATE admin_users
       SET password_hash = $1, failed_login_count = 0, locked_until = NULL
       WHERE id = $2`,
      [passwordHash, admin.id],
    );
    await client.query(
      "UPDATE admin_sessions SET revoked_at = now() WHERE admin_user_id = $1 AND revoked_at IS NULL",
      [admin.id],
    );
    await client.query(
      `INSERT INTO audit_logs (actor_id, action, entity_type, entity_id, before_value, after_value, request_id)
       VALUES ($1, 'PASSWORD_RESET', 'admin_user', $2, '{}'::jsonb, '{"password_changed":true}'::jsonb, $3)`,
      [admin.id, admin.id, randomUUID()],
    );
    await client.query("COMMIT");
    console.log("Admin password rotated; active sessions revoked.");
    console.log(`The new password is stored locally in: ${passwordFile}`);
  } catch (error) {
    try {
      await client.query("ROLLBACK");
    } catch {}
    unlinkSync(passwordFile);
    throw error;
  } finally {
    await client.end();
  }
}

main().catch((error) => {
  console.error("Password generation failed:", error.code ? `database error (${error.code})` : error.message);
  process.exitCode = 1;
});
