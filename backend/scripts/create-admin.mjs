import { randomBytes } from "node:crypto";
import { chmodSync, mkdirSync, openSync, closeSync, unlinkSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import pg from "pg";
import { encryptMFASecret, hashPassword } from "../dist/admin-auth.js";

const BACKEND_DIR = dirname(dirname(fileURLToPath(import.meta.url)));
const BOOTSTRAP_DIR = join(BACKEND_DIR, ".local");

function readArguments(argv) {
  const values = new Map();
  for (let index = 0; index < argv.length; index += 1) {
    const key = argv[index];
    if (!["--username", "--email", "--role"].includes(key) || values.has(key)) {
      throw new Error(`Unsupported or duplicate argument: ${key}`);
    }
    const value = argv[index + 1];
    if (!value || value.startsWith("--")) throw new Error(`Missing value for ${key}`);
    values.set(key, value);
    index += 1;
  }
  const username = values.get("--username");
  const email = values.get("--email");
  const roleInput = values.get("--role");
  if (!username || !/^[A-Za-z0-9@._-]{4,254}$/.test(username)) {
    throw new Error("A valid --username is required.");
  }
  if (!email || email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new Error("A valid --email is required.");
  }
  if (!roleInput) throw new Error("--role is required.");
  const normalizedRole = roleInput.toUpperCase().replaceAll("-", "_");
  const role = normalizedRole === "SUPERADMIN" ? "SUPER_ADMIN" : normalizedRole;
  if (!["SUPER_ADMIN", "COUNTRY_MANAGER", "COMPLIANCE_OFFICER", "SUPPORT_EMPLOYEE", "CONTENT_MANAGER", "PRICE_MANAGER", "VIEWER"].includes(role)) {
    throw new Error("The requested role is not supported.");
  }
  return { username, email: email.toLowerCase(), role };
}

function encodeBase32(bytes) {
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
  let bits = "";
  for (const byte of bytes) bits += byte.toString(2).padStart(8, "0");
  let encoded = "";
  for (let index = 0; index < bits.length; index += 5) {
    encoded += alphabet[Number.parseInt(bits.slice(index, index + 5).padEnd(5, "0"), 2)];
  }
  return encoded;
}

function writeBootstrapFile(path, contents) {
  const fd = openSync(path, "wx", 0o600);
  try {
    writeFileSync(fd, contents, { encoding: "utf8" });
  } finally {
    closeSync(fd);
  }
}

async function main() {
  const { username, email, role } = readArguments(process.argv.slice(2));
  process.loadEnvFile(join(BACKEND_DIR, ".env"));
  const databaseURL = process.env.DATABASE_URL;
  const mfaKey = process.env.ADMIN_MFA_ENCRYPTION_KEY;
  if (!databaseURL || !mfaKey || Buffer.from(mfaKey, "base64").length !== 32) {
    throw new Error("DATABASE_URL or a valid ADMIN_MFA_ENCRYPTION_KEY is not configured.");
  }

  mkdirSync(BOOTSTRAP_DIR, { recursive: true, mode: 0o700 });
  chmodSync(BOOTSTRAP_DIR, 0o700);
  const bootstrapPath = join(BOOTSTRAP_DIR, `admin-bootstrap-${username.toLowerCase()}.txt`);
  const password = randomBytes(32).toString("base64url");
  const mfaSecret = encodeBase32(randomBytes(20));
  const issuer = "UR Remit";
  const label = `${issuer}:${email}`;
  const otpAuthURL = `otpauth://totp/${encodeURIComponent(label)}?secret=${mfaSecret}&issuer=${encodeURIComponent(issuer)}&algorithm=SHA1&digits=6&period=30`;
  const passwordHash = await hashPassword(password);
  const encryptedMFASecret = encryptMFASecret(mfaSecret, mfaKey);
  const bootstrapContents = [
    "One-time admin account bootstrap. Keep this file private and delete it after setup.",
    `Username: ${username}`,
    `Email: ${email}`,
    `Role: ${role}`,
    `Temporary password: ${password}`,
    `TOTP secret: ${mfaSecret}`,
    `Authenticator setup URI: ${otpAuthURL}`,
    "",
  ].join("\n");
  writeBootstrapFile(bootstrapPath, bootstrapContents);

  const client = new pg.Client({ connectionString: databaseURL });
  try {
    await client.connect();
    await client.query("BEGIN");
    const existing = await client.query(
      "SELECT 1 FROM admin_users WHERE lower(email) = lower($1) OR lower(username) = lower($2) LIMIT 1",
      [email, username],
    );
    if (existing.rowCount) throw new Error("An admin account with this email or username already exists.");

    const roleResult = await client.query(
      `SELECT r.id, count(rp.permission_id)::int AS permission_count
       FROM roles r
       LEFT JOIN role_permissions rp ON rp.role_id = r.id
       WHERE r.name = $1
       GROUP BY r.id`,
      [role],
    );
    const roleRow = roleResult.rows[0];
    if (!roleRow || roleRow.permission_count === 0) {
      throw new Error("The requested role is missing or has no assigned permissions.");
    }

    await client.query(
      `INSERT INTO admin_users (email, username, password_hash, role_id, mfa_required, mfa_secret_ciphertext)
       VALUES ($1, $2, $3, $4, true, $5)`,
      [email, username, passwordHash, roleRow.id, encryptedMFASecret],
    );
    await client.query("COMMIT");
    console.log("Admin account created with MFA required.");
    console.log(`One-time credentials and authenticator setup were saved locally to: ${bootstrapPath}`);
    console.log("Open that file locally, add its TOTP secret to an authenticator app, then delete the file after safely saving the credentials.");
  } catch (error) {
    try {
      await client.query("ROLLBACK");
    } catch {}
    unlinkSync(bootstrapPath);
    throw error;
  } finally {
    await client.end();
  }
}

main().catch((error) => {
  console.error("Admin creation failed:", error.code ? `database error (${error.code})` : error.message);
  process.exitCode = 1;
});
