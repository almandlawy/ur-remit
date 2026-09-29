import 'dotenv/config';
import pg from 'pg';
const { Client } = pg;

const c = new Client({ connectionString: process.env.DATABASE_URL });
await c.connect();

console.log('🔧 إزالة القيد مؤقتاً...');

await c.query(`
  ALTER TABLE admin_users 
  DROP CONSTRAINT IF EXISTS admin_users_requires_mfa;
`);

console.log('✅ تمت إزالة القيد');

await c.end();
