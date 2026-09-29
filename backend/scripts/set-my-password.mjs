import 'dotenv/config';
import { randomBytes, scrypt as _scrypt } from 'crypto';
import { promisify } from 'util';
import { createInterface } from 'readline';
import pg from 'pg';

const scrypt = promisify(_scrypt);
const { Client } = pg;

const N = 32768, r = 8, p = 1;
const KEY_LEN = 32;
const SALT_LEN = 16;

async function hashPassword(password) {
  const salt = randomBytes(SALT_LEN);
  const hash = await scrypt(password, salt, KEY_LEN, { N, r, p });
  return `${salt.toString('hex')}:${hash.toString('hex')}`;
}

function ask(question) {
  const rl = createInterface({ input: process.stdin, output: process.stdout });
  return new Promise(resolve => rl.question(question, ans => { rl.close(); resolve(ans); }));
}

async function main() {
  const username = process.argv[2] || 'taha';
  const password = await ask(`كلمة المرور الجديدة لـ "${username}": `);

  if (password.length < 8) {
    console.error('❌ كلمة المرور قصيرة جداً (8+ أحرف)');
    process.exit(1);
  }

  const hash = await hashPassword(password);
  const client = new Client({ connectionString: process.env.DATABASE_URL });
  await client.connect();

  const { rowCount } = await client.query(
    'UPDATE admin_users SET password_hash = $1 WHERE username = $2',
    [hash, username]
  );

  if (rowCount === 0) {
    console.error(`❌ المستخدم "${username}" غير موجود`);
    process.exit(1);
  }

  console.log('✅ تم تعيين كلمة المرور الجديدة');
  await client.end();
}

main();
