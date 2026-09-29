import { randomBytes, scrypt as nodeScrypt, createCipheriv } from "node:crypto";
import { promisify } from "node:util";
import pg from "pg";

const scrypt = promisify(nodeScrypt);
const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";

function toBase32(bytes) {
  let bits = "";
  for (const byte of bytes) bits += byte.toString(2).padStart(8, "0");
  let output = "";
  for (let index = 0; index < bits.length; index += 5) {
    output += alphabet[Number.parseInt(bits.slice(index, index + 5).padEnd(5, "0"), 2)];
  }
  return output;
}

function hashPassword(password) {
  const salt = randomBytes(16);
  return scrypt(password, salt, 32, { N: 32768, r: 8, p: 1, maxmem: 64 * 1024 * 1024 })
    .then((derived) => `scrypt$32768$8$1$${salt.toString("base64url")}$${Buffer.from(derived).toString("base64url")}`);
}

function encryptMFASecret(secret, base64Key) {
  const key = Buffer.from(base64Key, "base64");
  if (key.length !== 32) throw new Error("ADMIN_MFA_ENCRYPTION_KEY must decode to exactly 32 bytes");
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", key, iv);
  const ciphertext = Buffer.concat([cipher.update(secret, "utf8"), cipher.final()]);
  return Buffer.concat([iv, cipher.getAuthTag(), ciphertext]);
}

function readArguments(args) {
  const values = new Map();
  for (let index = 0; index < args.length; index += 1) {
    const current = args[index];
    if (current === "--reset-existing") {
      values.set(current, true);
    } else if (current?.startsWith("--") && args[index + 1] && !args[index + 1].startsWith("--")) {
      values.set(current, args[index + 1]);
      index += 1;
    }
  }
  return values;
}

const args = readArguments(process.argv.slice(2));
const email = String(args.get("--email") ?? "").trim().toLowerCase();
const username = String(args.get("--username") ?? "").trim();
const roleName = String(args.get("--role") ?? "SUPER_ADMIN").trim();
const resetExisting = args.get("--reset-existing") === true;
const password = process.env.ADMIN_INITIAL_PASSWORD ?? "";
delete process.env.ADMIN_INITIAL_PASSWORD;

if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
  throw new Error("Pass a valid administrator address with --email.");
}
if (!/^[A-Za-z0-9._-]{4,64}$/.test(username)) {
  throw new Error("Pass a username of 4-64 letters, digits, dots, underscores, or hyphens with --username.");
}
if (password.length < 12 || password.length > 256) {
  throw new Error("Set ADMIN_INITIAL_PASSWORD to a 12-256 character password before running this script.");
}
if (!process.env.DATABASE_URL || !process.env.ADMIN_MFA_ENCRYPTION_KEY) {
  throw new Error("DATABASE_URL and ADMIN_MFA_ENCRYPTION_KEY are required.");
}

const mfaSecret = toBase32(randomBytes(20));
const encodedMFA = encryptMFASecret(mfaSecret, process.env.ADMIN_MFA_ENCRYPTION_KEY);
const encodedPassword = await hashPassword(password);
const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL,
  max: 1,
  connectionTimeoutMillis: 5000,
  ssl: process.env.NODE_ENV === "production" ? { rejectUnauthorized: true } : undefined
});

try {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const role = await client.query("SELECT id FROM roles WHERE name = $1", [roleName]);
    if (!role.rows[0]) throw new Error(`Role ${roleName} does not exist. Apply the admin schema migrations first.`);

    const existing = await client.query("SELECT id FROM admin_users WHERE lower(email) = $1 FOR UPDATE", [email]);
    if (existing.rowCount && !resetExisting) {
      throw new Error("An account already exists for this email. Re-run with --reset-existing only to rotate its password and MFA seed.");
    }
    const user = existing.rowCount
      ? await client.query(
        `UPDATE admin_users SET email = $2, username = $3, password_hash = $4,
         role_id = $5, mfa_required = true, mfa_secret_ciphertext = $6, disabled_at = NULL
         WHERE id = $1 RETURNING id`,
        [existing.rows[0].id, email, username, encodedPassword, role.rows[0].id, encodedMFA]
      )
      : await client.query(
        `INSERT INTO admin_users(email, username, password_hash, role_id, mfa_required, mfa_secret_ciphertext, disabled_at)
         VALUES ($1, $2, $3, $4, true, $5, NULL) RETURNING id`,
        [email, username, encodedPassword, role.rows[0].id, encodedMFA]
      );
    await client.query("UPDATE admin_sessions SET revoked_at = now() WHERE admin_user_id = $1 AND revoked_at IS NULL", [user.rows[0].id]);
    await client.query("COMMIT");
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
} finally {
  await pool.end();
}

const issuer = encodeURIComponent("UR Remit");
const account = encodeURIComponent(`${username} (${email})`);
console.log("Administrator created with mandatory MFA.");
console.log(`Role: ${roleName}`);
console.log("Add this TOTP seed to an authenticator now; the seed is not stored in plaintext:");
console.log(mfaSecret);
console.log(`Provisioning URI: otpauth://totp/${issuer}:${account}?secret=${mfaSecret}&issuer=${issuer}&algorithm=SHA1&digits=6&period=30`);
console.log("Store the MFA seed securely. It cannot be retrieved from the database.");
