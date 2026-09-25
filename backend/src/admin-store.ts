import { createHmac } from "node:crypto";
import pg from "pg";

export type AdminActor = { id: string; role: string; permissions: string[] };
export type RateUpdate = {
  buy?: string | null | undefined; sell?: string | null | undefined;
  feeFixed?: string | null | undefined; feePercent?: string | null | undefined;
  validFrom?: string | undefined; validUntil?: string | null | undefined; active?: boolean | undefined;
};

export interface AdminStore {
  authenticate(tokenHash: string): Promise<AdminActor | null>;
  dashboard(): Promise<Record<string, unknown>>;
  updateRate(rateId: string, update: RateUpdate, actor: AdminActor, requestId: string, ip?: string): Promise<Record<string, unknown> | null>;
  close(): Promise<void>;
}

export function sessionFingerprint(token: string, key: string): string {
  return createHmac("sha256", key).update(token).digest("hex");
}

export class PostgresAdminStore implements AdminStore {
  private readonly pool: pg.Pool;
  constructor(databaseURL: string) {
    this.pool = new pg.Pool({ connectionString: databaseURL, max: 10, connectionTimeoutMillis: 5_000,
      ssl: process.env.NODE_ENV === "production" ? { rejectUnauthorized: true } : undefined });
  }

  async authenticate(tokenHash: string): Promise<AdminActor | null> {
    const result = await this.pool.query<{ id: string; role: string; permissions: string[] }>(`
      UPDATE admin_sessions s SET last_seen_at = now()
      FROM admin_users u JOIN roles r ON r.id = u.role_id
      WHERE s.admin_user_id = u.id AND s.token_hash = $1 AND s.revoked_at IS NULL
        AND s.expires_at > now() AND s.mfa_verified_at IS NOT NULL AND u.disabled_at IS NULL
      RETURNING u.id, r.name AS role,
        ARRAY(SELECT p.name FROM role_permissions rp JOIN permissions p ON p.id = rp.permission_id WHERE rp.role_id = r.id) AS permissions`,
      [tokenHash]);
    return result.rows[0] ?? null;
  }

  async dashboard(): Promise<Record<string, unknown>> {
    const result = await this.pool.query(`SELECT
      (SELECT count(*)::int FROM rate_routes WHERE is_active) AS "activeRoutes",
      (SELECT count(*)::int FROM offices WHERE is_active AND is_verified) AS "activeOffices",
      (SELECT count(*)::int FROM agents WHERE status = 'VERIFIED') AS "verifiedAgents",
      (SELECT count(*)::int FROM push_tokens WHERE revoked_at IS NULL) AS "pushSubscribers",
      (SELECT max(source_timestamp) FROM rates WHERE is_active) AS "lastRateUpdate"`);
    return result.rows[0] ?? {};
  }

  async updateRate(rateId: string, update: RateUpdate, actor: AdminActor, requestId: string, ip?: string): Promise<Record<string, unknown> | null> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const current = await client.query(`SELECT * FROM rates WHERE id = $1 FOR UPDATE`, [rateId]);
      const oldRate = current.rows[0] as Record<string, unknown> | undefined;
      if (!oldRate) { await client.query("ROLLBACK"); return null; }
      await client.query("UPDATE rates SET is_active = false WHERE id = $1", [rateId]);
      const inserted = await client.query(`INSERT INTO rates
        (route_id, buy, sell, fee_fixed, fee_percent, valid_from, valid_until, source_timestamp, version, is_active)
        VALUES ($1,$2,$3,$4,$5,$6,$7,now(),$8,$9) RETURNING *`, [
        oldRate.route_id, update.buy === undefined ? oldRate.buy : update.buy,
        update.sell === undefined ? oldRate.sell : update.sell,
        update.feeFixed === undefined ? oldRate.fee_fixed : update.feeFixed,
        update.feePercent === undefined ? oldRate.fee_percent : update.feePercent,
        update.validFrom ?? new Date().toISOString(), update.validUntil === undefined ? oldRate.valid_until : update.validUntil,
        Number(oldRate.version) + 1, update.active ?? true
      ]);
      const newRate = inserted.rows[0] as Record<string, unknown>;
      await client.query(`INSERT INTO rate_history(rate_id, old_value, new_value, actor_id, request_id, context)
        VALUES ($1,$2,$3,$4,$5,$6)`, [newRate.id, oldRate, newRate, actor.id, requestId, { source: "admin-api" }]);
      await client.query(`INSERT INTO audit_logs(actor_id, action, entity_type, entity_id, before_value, after_value, request_id, ip_context)
        VALUES ($1,'UPDATE','rate',$2,$3,$4,$5,$6)`, [actor.id, String(newRate.id), oldRate, newRate, requestId, ip ?? null]);
      await client.query("COMMIT");
      return newRate;
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally { client.release(); }
  }

  async close(): Promise<void> { await this.pool.end(); }
}
