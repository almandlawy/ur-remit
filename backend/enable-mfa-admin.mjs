import 'dotenv/config';
import { randomBytes, createCipheriv, scrypt as _scrypt } from 'crypto';
import { promisify } from 'util';
import pg from 'pg';
const { Client } = pg;

const scrypt = promisify(_scrypt);

// إعدادات scrypt
const N = 32768, r = 8, p = 1, KEY_LEN = 32, SALT_LEN = 16;
const MAXMEM = 128 * N * r * 2;

// AES-GCM لتشفير بذرة MFA
function encryptMfaSecret(secret, keyBase64) {
  const key = Buffer.from(keyBase64, 'base64');
  const iv = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', key, iv);
  const encrypted = Buffer.concat([cipher.update(secret, 'utf8'), cipher.final()]);
  const authTag = cipher.getAuthTag();
  return `${iv.toString('base64')}:${authTag.toString('base64')}:${encrypted.toString('base64')}`;
}

// TOTP: BASE32 encode
function base32Encode(buffer) {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  let bits = 0, value = 0, output = '';
  for (const byte of buffer) {
    value = (value << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      output += alphabet[(value >>> (bits - 5)) & 31];
      bits -= 5;
    }
  }
  if (bits > 0) output += alphabet[(value << (5 - bits)) & 31];
  return output;
}

async function hashPassword(password) {
  const salt = randomBytes(SALT_LEN);
  const hash = await scrypt(password, salt, KEY_LEN, { N, r, p, maxmem: MAXMEM });
  return `${salt.toString('hex')}:${hash.toString('hex')}`;
}

const username = process.argv[2];
const newPassword = process.argv[3];
const newEmail = process.argv[4] || null;

// 1) ولّد بذرة TOTP عشوائية (20 بايت = 32 حرف Base32)
const totpSecret = base32Encode(randomBytes(20));

// 2) شفّر البذرة
const mfaKey = process.env.ADMIN_MFA_ENCRYPTION_KEY;
if (!mfaKey) {
  console.error('❌ ADMIN_MFA_ENCRYPTION_KEY غير موجود في .env');
  process.exit(1);
}
const encryptedSecret = encryptMfaSecret(totpSecret, mfaKey);

// 3) hash كلمة المرور
const hash = await hashPassword(newPassword);

// 4) حدّث الحساب
const client = new Client({ connectionString: process.env.DATABASE_URL });
await client.connect();

const { rowCount } = await client.query(
  `UPDATE admin_users 
   SET password_hash = $1, 
       mfa_required = true, 
       mfa_secret_ciphertext = $2,
       disabled_at = NULL,
       email = COALESCE($3, email)
   WHERE username = $4`,
  [hash, encryptedSecret, newEmail, username]
);

if (rowCount === 0) {
  console.error('❌ غير موجود');
  process.exit(1);
}

console.log('');
console.log('═══════════════════════════════════════════');
console.log('✅ تم تفعيل الحساب مع MFA');
console.log('═══════════════════════════════════════════');
console.log('');
console.log('📧 البريد: ' + (newEmail || username));
console.log('🔑 كلمة المرور: ' + newPassword);
console.log('');
console.log('🔐 بذرة TOTP (أضفها في Google Authenticator):');
console.log('');
console.log('   ' + totpSecret);
console.log('');
console.log('═══════════════════════════════════════════');
console.log('⚠️  احفظ البذرة في Google Authenticator فوراً!');
console.log('   - افتح Google Authenticator');
console.log('   - اضغط +');
console.log('   - اختر "Enter a setup key"');
console.log('   - Account: UR Admin');
console.log('   - Key: ' + totpSecret);
console.log('   - Add');
console.log('═══════════════════════════════════════════');

await client.end();
