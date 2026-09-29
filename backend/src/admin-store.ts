import { createHmac, randomBytes } from "node:crypto";
import pg from "pg";
import { decryptMFASecret, verifyPassword, verifyTOTP } from "./admin-auth.js";

export type AdminActor = { id: string; role: string; permissions: string[] };
export type RateUpdate = {
  buy?: string | null | undefined; sell?: string | null | undefined;
  feeFixed?: string | null | undefined; feePercent?: string | null | undefined;
  validFrom?: string | undefined; validUntil?: string | null | undefined; active?: boolean | undefined;
};

export interface AdminStore {
  login(credentials: { email: string; password: string; otp: string }, keys: { session: string; mfa: string }, context: { ip?: string | undefined; userAgent?: string | undefined }): Promise<{ token: string; expiresAt: string } | null>;
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

  async login(credentials: { email: string; password: string; otp: string }, keys: { session: string; mfa: string }, context: { ip?: string | undefined; userAgent?: string | undefined }): Promise<{ token: string; expiresAt: string } | null> {
    const result = await this.pool.query<{ id: string; password_hash: string; mfa_secret_ciphertext: Buffer; failed_login_count: number }>(`
      SELECT id, password_hash, mfa_secret_ciphertext, failed_login_count FROM admin_users
      WHERE lower(email) = lower($1) AND disabled_at IS NULL AND (locked_until IS NULL OR locked_until <= now()) LIMIT 1`, [credentials.email]);
    const user = result.rows[0];
    const passwordValid = user ? await verifyPassword(credentials.password, user.password_hash) : false;
    let otpValid = false;
    if (user && passwordValid && user.mfa_secret_ciphertext) {
      try { otpValid = verifyTOTP(decryptMFASecret(user.mfa_secret_ciphertext, keys.mfa), credentials.otp); }
      catch { otpValid = false; }
    }
    if (!user || !passwordValid || !otpValid) {
      if (user) await this.pool.query(`UPDATE admin_users SET failed_login_count = failed_login_count + 1,
        locked_until = CASE WHEN failed_login_count + 1 >= 5 THEN now() + interval '15 minutes' ELSE locked_until END WHERE id = $1`, [user.id]);
      return null;
    }
    const token = randomBytes(32).toString("base64url");
    const tokenHash = sessionFingerprint(token, keys.session); const expiresAt = new Date(Date.now() + 30 * 60_000).toISOString();
    const client = await this.pool.connect();
    await client.query("BEGIN");
    try {
      await client.query(`INSERT INTO admin_sessions(admin_user_id, token_hash, mfa_verified_at, expires_at, ip_fingerprint, user_agent_fingerprint)
        VALUES ($1,$2,now(),$3,$4,$5)`, [user.id, tokenHash, expiresAt,
        context.ip ? sessionFingerprint(context.ip, keys.session) : null,
        context.userAgent ? sessionFingerprint(context.userAgent, keys.session) : null]);
      await client.query("UPDATE admin_users SET failed_login_count = 0, locked_until = NULL, last_login_at = now() WHERE id = $1", [user.id]);
      await client.query("COMMIT");
    } catch (error) { await client.query("ROLLBACK"); throw error; }
    finally { client.release(); }
    return { token, expiresAt };
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
    const [metrics, activity] = await Promise.all([
      this.pool.query(`SELECT
        (SELECT count(*)::int FROM rate_routes WHERE is_active) AS "activeRoutes",
        (SELECT count(*)::int FROM offices WHERE is_active AND is_verified) AS "activeOffices",
        (SELECT count(*)::int FROM agents WHERE status = 'VERIFIED') AS "verifiedAgents",
        (SELECT count(*)::int FROM push_tokens WHERE revoked_at IS NULL) AS "pushSubscribers",
        (SELECT max(source_timestamp) FROM rates WHERE is_active) AS "lastRateUpdate"`),
      this.pool.query(`SELECT a.action, a.entity_type AS "entityType", a.entity_id AS "entityId",
          a.created_at AS "createdAt", u.email AS "actorEmail"
        FROM audit_logs a LEFT JOIN admin_users u ON u.id = a.actor_id
        ORDER BY a.created_at DESC LIMIT 10`)
    ]);
    return { ...(metrics.rows[0] ?? {}), recentActivity: activity.rows };
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
