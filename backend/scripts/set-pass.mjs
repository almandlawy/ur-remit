import { randomBytes, scrypt as _scrypt } from 'crypto';
import { promisify } from 'util';
import pg from 'pg';
import { config } from 'dotenv';
config();
const scrypt = promisify(_scrypt);
const { Client } = pg;
const N = 32768, r = 8, p = 1, KEY_LEN = 32, SALT_LEN = 16;
async function hashPassword(password) {
  const salt = randomBytes(SALT_LEN);
  const hash = await scrypt(password, salt, KEY_LEN, { N, r, p });
  return `${salt.toString('hex')}:${hash.toString('hex')}`;
}
const username = process.argv[2];
const newPassword = process.argv[3] || randomBytes(9).toString('base64url');
if (!username) { console.error('Usage: node scripts/set-pass.mjs <username> [password]'); process.exit(1); }
const hash = await hashPassword(newPassword);
const client = new Client({ connectionString: process.env.DATABASE_URL });
await client.connect();
const { rowCount } = await client.query('UPDATE admin_users SET password_hash = $1 WHERE username = $2', [hash, username]);
if (rowCount === 0) { console.error(`❌ الحساب "${username}" غير موجود`); process.exit(1); }
console.log('═══════════════════════════════════════');
console.log('Username: ' + username);
console.log('Password: ' + newPassword);
console.log('═══════════════════════════════════════');
await client.end();
