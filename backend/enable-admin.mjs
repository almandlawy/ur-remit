import { randomBytes, scrypt as _scrypt } from 'crypto';
import { promisify } from 'util';
import pg from 'pg';
import { config } from 'dotenv';
config();

const scrypt = promisify(_scrypt);
const { Client } = pg;
const N = 32768, r = 8, p = 1, KEY_LEN = 32, SALT_LEN = 16;
const MAXMEM = 128 * N * r * 2; // 67MB

async function hashPassword(password) {
  const salt = randomBytes(SALT_LEN);
  const hash = await scrypt(password, salt, KEY_LEN, { N, r, p, maxmem: MAXMEM });
  return `${salt.toString('hex')}:${hash.toString('hex')}`;
}

const username = process.argv[2];
const newPassword = process.argv[3];
const newEmail = process.argv[4];

const hash = await hashPassword(newPassword);
const client = new Client({ connectionString: process.env.DATABASE_URL });
await client.connect();

const { rowCount } = await client.query(
  'UPDATE admin_users SET password_hash = $1, disabled_at = NULL, mfa_required = false, email = COALESCE($2, email) WHERE username = $3',
  [hash, newEmail, username]
);

if (rowCount === 0) {
  console.error('❌ غير موجود');
  process.exit(1);
}

console.log('✅ تم تفعيل ' + username);
console.log('   البريد: ' + newEmail);
console.log('   كلمة المرور: ' + newPassword);

await client.end();
