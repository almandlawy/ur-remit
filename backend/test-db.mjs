import 'dotenv/config';
import pg from 'pg';
const { Client } = pg;

console.log('═══════════════════════════════════');
console.log('DATABASE_URL موجود؟', !!process.env.DATABASE_URL);
console.log('DATABASE_URL يبدأ بـ:', (process.env.DATABASE_URL || '').substring(0, 25) + '...');
console.log('═══════════════════════════════════');

const c = new Client({ connectionString: process.env.DATABASE_URL });

try {
  await c.connect();
  const r = await c.query('SELECT 1 as ok');
  console.log('✅ DB OK');
  await c.end();
} catch (e) {
  console.log('❌ Error name:', e.name);
  console.log('❌ Error code:', e.code);
  console.log('❌ Error message:', e.message || '(empty)');
  process.exit(1);
}
