import { readFileSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import pg from "pg";

const { Client } = pg;
const BACKEND_DIR = dirname(dirname(fileURLToPath(import.meta.url)));
const DB_DIR = join(BACKEND_DIR, "db");
const MIGRATION_TABLE = "public._migrations";
const APPLY = process.argv.includes("--apply");

function getMigrationBody(sql, filename) {
  const lines = sql.split(/\r?\n/);
  const first = lines.findIndex((line) => line.trim() !== "");
  let last = lines.length - 1;
  while (last >= 0 && lines[last].trim() === "") last--;

  if (first < 0 || !/^BEGIN\s*;\s*$/i.test(lines[first]) || !/^COMMIT\s*;\s*$/i.test(lines[last])) {
    throw new Error(`${filename} must start with BEGIN; and end with COMMIT;`);
  }

  return lines.slice(first + 1, last).join("\n");
}

async function main() {
  const files = readdirSync(DB_DIR).filter((file) => file.endsWith(".sql")).sort();
  if (files.length === 0) throw new Error("No SQL migrations found.");

  if (!APPLY) {
    console.log(`Dry run: found ${files.length} migration(s); no database connection or changes made.`);
    for (const file of files) console.log(`  ${file}`);
    console.log("\nPass --apply to execute these migrations.");
    return;
  }

  process.loadEnvFile(join(BACKEND_DIR, ".env"));
  if (!process.env.DATABASE_URL) throw new Error("DATABASE_URL is not configured.");

  const client = new Client({ connectionString: process.env.DATABASE_URL });
  let lockAcquired = false;
  try {
    await client.connect();
    await client.query("SELECT pg_advisory_lock(hashtext($1))", ["ur-backend-sql-migrations"]);
    lockAcquired = true;

    const { rows: stateRows } = await client.query(`
      SELECT
        to_regclass('public._migrations') IS NOT NULL AS tracking_exists,
        to_regclass('public.admin_users') IS NOT NULL
          OR to_regclass('public.rate_routes') IS NOT NULL
          OR to_regclass('public.offices') IS NOT NULL AS application_schema_exists
    `);
    const state = stateRows[0];
    if (!state.tracking_exists && state.application_schema_exists) {
      throw new Error("Application tables exist without migration history; reconcile the database before applying migrations.");
    }

    await client.query(`
      CREATE TABLE IF NOT EXISTS ${MIGRATION_TABLE} (
        id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        filename text UNIQUE NOT NULL,
        applied_at timestamptz NOT NULL DEFAULT now()
      )
    `);

    const { rows } = await client.query(`SELECT filename FROM ${MIGRATION_TABLE}`);
    const applied = new Set(rows.map((row) => row.filename));
    if (applied.size === 0 && state.application_schema_exists) {
      throw new Error("Application tables exist but migration history is empty; reconcile the database before applying migrations.");
    }
    let count = 0;

    for (const file of files) {
      if (applied.has(file)) {
        console.log(`Skipped ${file} (already applied).`);
        continue;
      }

      console.log(`Applying ${file}...`);
      const sql = readFileSync(join(DB_DIR, file), "utf8");
      const migrationBody = getMigrationBody(sql, file);
      try {
        await client.query("BEGIN");
        await client.query(migrationBody);
        await client.query(`INSERT INTO ${MIGRATION_TABLE} (filename) VALUES ($1)`, [file]);
        await client.query("COMMIT");
        count++;
        console.log(`Applied ${file}.`);
      } catch (error) {
        await client.query("ROLLBACK");
        throw error;
      }
    }

    console.log(`Applied ${count} new migration(s).`);
  } finally {
    if (lockAcquired) {
      try {
        await client.query("SELECT pg_advisory_unlock(hashtext($1))", ["ur-backend-sql-migrations"]);
      } catch {
        console.error("Could not release the migration advisory lock; it will be released when the connection closes.");
      }
    }
    await client.end();
  }
}

main().catch((error) => {
  console.error("Migration failed:", error.code ? `database error (${error.code})` : error.message);
  process.exitCode = 1;
});
