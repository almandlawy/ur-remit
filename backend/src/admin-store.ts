import { createHmac, randomBytes } from "node:crypto";
import pg from "pg";
import { hashPassword, verifyPassword } from "./admin-auth.js";
import { postgresSSLConfig } from "./postgres-ssl.js";

export type AdminActor = { id: string; role: string; permissions: string[] };
export type RateUpdate = {
  buy?: string | null | undefined; sell?: string | null | undefined;
  feeFixed?: string | null | undefined; feePercent?: string | null | undefined;
  validFrom?: string | undefined; validUntil?: string | null | undefined; active?: boolean | undefined;
};
export type OfficeInput = {
  countryId: string; cityId: string; publicCode: string; nameArabic: string; nameEnglish: string;
  addressArabic: string; addressEnglish: string; latitude?: string | null | undefined;
  longitude?: string | null | undefined; phone?: string | null | undefined; whatsapp?: string | null | undefined;
  workingHours?: Record<string, unknown> | undefined; services?: unknown[] | undefined;
  verified?: boolean | undefined; active?: boolean | undefined;
};
export type OfficeUpdate = { [Key in keyof OfficeInput]?: OfficeInput[Key] | undefined };

export function rateUpdateRpcArguments(update: RateUpdate): unknown[] {
  return [
    update.buy ?? null,
    update.sell ?? null,
    update.feeFixed ?? null,
    update.feePercent ?? null,
    Object.prototype.hasOwnProperty.call(update, "buy"),
    Object.prototype.hasOwnProperty.call(update, "sell"),
    Object.prototype.hasOwnProperty.call(update, "feeFixed"),
    Object.prototype.hasOwnProperty.call(update, "feePercent"),
    update.validFrom ?? null,
    update.validUntil ?? null,
    Object.prototype.hasOwnProperty.call(update, "validUntil"),
    update.active ?? true,
  ];
}

export interface AdminStore {
  login(credentials: { username: string; password: string }, keys: { session: string }, context: { requestId: string; ip?: string | undefined; userAgent?: string | undefined }): Promise<{ token: string; expiresAt: string } | null>;
  authenticate(tokenHash: string): Promise<AdminActor | null>;
  revokeSession(tokenHash: string, actorId: string, requestId: string, ip?: string): Promise<void>;
  dashboard(): Promise<Record<string, unknown>>;
  listRates(): Promise<Record<string, unknown>[]>;
  updateRate(rateId: string, update: RateUpdate, actor: AdminActor, requestId: string, ip?: string): Promise<Record<string, unknown> | null>;
  listOffices(): Promise<Record<string, unknown>[]>;
  createOffice(input: OfficeInput, actor: AdminActor, requestId: string, ip?: string): Promise<Record<string, unknown> | null>;
  updateOffice(officeId: string, input: OfficeUpdate, actor: AdminActor, requestId: string, ip?: string): Promise<Record<string, unknown> | null>;
  deleteOffice(officeId: string, actor: AdminActor, requestId: string, ip?: string): Promise<boolean>;
  listAgents(): Promise<Record<string, unknown>[]>;
  listAdmins(): Promise<Record<string, unknown>[]>;
  auditLog(): Promise<Record<string, unknown>[]>;
  changePassword(actor: AdminActor, currentPassword: string, newPassword: string, requestId: string, ip?: string): Promise<boolean>;
  close(): Promise<void>;
}

export function sessionFingerprint(token: string, key: string): string {
  return createHmac("sha256", key).update(token).digest("hex");
}

export class PostgresAdminStore implements AdminStore {
  private readonly pool: pg.Pool;
  constructor(databaseURL: string) {
    this.pool = new pg.Pool({ connectionString: databaseURL, max: 10, connectionTimeoutMillis: 5_000,
      ssl: postgresSSLConfig(databaseURL) });
  }

  async login(credentials: { username: string; password: string }, keys: { session: string }, context: { requestId: string; ip?: string | undefined; userAgent?: string | undefined }): Promise<{ token: string; expiresAt: string } | null> {
    const result = await this.pool.query<{ id: string; password_hash: string; failed_login_count: number }>(`
      SELECT id, password_hash, failed_login_count FROM admin_users
      WHERE (lower(username) = lower($1) OR lower(email) = lower($1))
        AND disabled_at IS NULL AND (locked_until IS NULL OR locked_until <= now()) LIMIT 1`, [credentials.username]);
    const user = result.rows[0];
    const passwordValid = user ? await verifyPassword(credentials.password, user.password_hash) : false;
    if (!user || !passwordValid) {
      if (user) await this.pool.query(`UPDATE admin_users SET failed_login_count = failed_login_count + 1,
        locked_until = CASE WHEN failed_login_count + 1 >= 5 THEN now() + interval '15 minutes' ELSE locked_until END WHERE id = $1`, [user.id]);
      return null;
    }
    const token = randomBytes(32).toString("base64url");
    const tokenHash = sessionFingerprint(token, keys.session); const expiresAt = new Date(Date.now() + 24 * 60 * 60_000).toISOString();
    const client = await this.pool.connect();
    await client.query("BEGIN");
    try {
      await client.query(`INSERT INTO admin_sessions(admin_user_id, token_hash, expires_at, ip_fingerprint, user_agent_fingerprint)
        VALUES ($1,$2,$3,$4,$5)`, [user.id, tokenHash, expiresAt,
        context.ip ? sessionFingerprint(context.ip, keys.session) : null,
        context.userAgent ? sessionFingerprint(context.userAgent, keys.session) : null]);
      await client.query("UPDATE admin_users SET failed_login_count = 0, locked_until = NULL, last_login_at = now() WHERE id = $1", [user.id]);
      await client.query(`INSERT INTO audit_logs(actor_id, action, entity_type, entity_id, after_value, request_id, ip_context)
        VALUES ($1, 'LOGIN', 'admin_user', $1::text, '{"success":true}'::jsonb, $2, $3)`,
      [user.id, context.requestId, context.ip ?? null]);
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
        AND s.expires_at > now() AND u.disabled_at IS NULL
      RETURNING u.id, r.name AS role,
        ARRAY(SELECT p.name FROM role_permissions rp JOIN permissions p ON p.id = rp.permission_id WHERE rp.role_id = r.id) AS permissions`,
      [tokenHash]);
    return result.rows[0] ?? null;
  }

  async revokeSession(tokenHash: string, actorId: string, requestId: string, ip?: string): Promise<void> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const revoked = await client.query(
        "UPDATE admin_sessions SET revoked_at = now() WHERE token_hash = $1 AND admin_user_id = $2 AND revoked_at IS NULL RETURNING id",
        [tokenHash, actorId]
      );
      if (revoked.rowCount) {
        await client.query(`INSERT INTO audit_logs(actor_id, action, entity_type, entity_id, after_value, request_id, ip_context)
          VALUES ($1, 'LOGOUT', 'admin_session', $2, '{"revoked":true}'::jsonb, $3, $4)`,
        [actorId, revoked.rows[0]?.id, requestId, ip ?? null]);
      }
      await client.query("COMMIT");
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally { client.release(); }
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

  async listRates(): Promise<Record<string, unknown>[]> {
    const result = await this.pool.query(`SELECT r.id, r.route_id AS "routeId", rr.name_ar AS "routeNameArabic",
      rr.name_en AS "routeNameEnglish", rr.source_currency AS "sourceCurrency",
      rr.destination_currency AS "destinationCurrency", r.buy::text, r.sell::text,
      r.fee_fixed::text AS "feeFixed", r.fee_percent::text AS "feePercent",
      r.valid_from AS "validFrom", r.valid_until AS "validUntil",
      r.source_timestamp AS "sourceTimestamp", r.version::int, r.is_active AS "active"
      FROM rates r JOIN rate_routes rr ON rr.id = r.route_id
      ORDER BY r.is_active DESC, r.source_timestamp DESC LIMIT 500`);
    return result.rows as Record<string, unknown>[];
  }

  // Delegates to the admin_update_rate() SQL function instead of
  // re-implementing rate versioning here. A prior version of this method
  // resolved the row to update with `WHERE id = $1 FOR UPDATE` and computed
  // `version = oldRate.version + 1` directly from the row the caller passed
  // in. If a caller (a UI that hadn't refreshed after an earlier save, or a
  // second concurrent admin) reused a rate id that had since been retired,
  // that recomputed a version number that had already been inserted by the
  // save that retired it, and the insert failed against the
  // `rates_route_id_version_key` unique constraint - surfacing as "تعذّر
  // الاتصال بخدمة الإدارة" even though the real cause was a stale id, not a
  // network/connectivity problem. admin_update_rate() resolves the route
  // from whatever id is passed, locks all of that route's rows, and always
  // versions off the row that is *currently* active, so retries and
  // successive saves with a stale id succeed instead of racing. Update flags
  // let the function preserve omitted fields from the active row under lock,
  // rather than copying stale values from a pre-read.
  async updateRate(rateId: string, update: RateUpdate, actor: AdminActor, requestId: string, ip?: string): Promise<Record<string, unknown> | null> {
    const client = await this.pool.connect();
    try {
      const rateArguments = rateUpdateRpcArguments(update);
      const result = await client.query(
        `SELECT admin_update_rate(
          $1, $2, $3, $4, $5, $6, $7,
          $8, $9, $10, $11, $12, $13, $14, $15
        ) AS rate`,
        [
          actor.id,
          rateId,
          ...rateArguments.slice(0, 3),
          requestId,
          ...rateArguments.slice(3),
        ],
      );
      const newRate = result.rows[0]?.rate as Record<string, unknown> | undefined;
      if (!newRate) return null;

      // admin_update_rate() already records rate_history and audit_logs
      // entries internally (matching the production edge function path);
      // inserting another audit row here would double-log every save. The
      // ip_context column is best-effort only for this action.
      if (ip) {
        await client.query(
          `UPDATE audit_logs SET ip_context = $1 WHERE request_id = $2 AND entity_type = 'rate' AND ip_context IS NULL`,
          [ip, requestId],
        );
      }
      return newRate;
    } finally { client.release(); }
  }

  async listOffices(): Promise<Record<string, unknown>[]> {
    const result = await this.pool.query(`SELECT o.id, o.public_code AS "publicCode", o.country_id AS "countryId",
      o.city_id AS "cityId", o.name_ar AS "nameArabic", o.name_en AS "nameEnglish",
      o.address_ar AS "addressArabic", o.address_en AS "addressEnglish",
      c.iso_code AS "countryCode", c.name_ar AS "countryArabic", c.name_en AS "countryEnglish",
      ci.name_ar AS "cityArabic", ci.name_en AS "cityEnglish",
      o.latitude::text, o.longitude::text, o.phone, o.whatsapp, o.working_hours AS "workingHours",
      o.services, o.is_verified AS "verified", o.is_active AS "active",
      o.created_at AS "createdAt", o.updated_at AS "updatedAt"
      FROM offices o JOIN countries c ON c.id = o.country_id
      JOIN cities ci ON ci.id = o.city_id ORDER BY o.updated_at DESC LIMIT 500`);
    return result.rows as Record<string, unknown>[];
  }

  async createOffice(input: OfficeInput, actor: AdminActor, requestId: string, ip?: string): Promise<Record<string, unknown> | null> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const result = await client.query(`INSERT INTO offices
        (public_code, country_id, city_id, name_ar, name_en, address_ar, address_en,
         latitude, longitude, phone, whatsapp, working_hours, services, is_verified, is_active)
        SELECT $1, c.id, ci.id, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15
        FROM countries c JOIN cities ci ON ci.country_id = c.id
        WHERE c.id = $2 AND ci.id = $3 AND c.is_active AND ci.is_active
        RETURNING *`, [
        input.publicCode, input.countryId, input.cityId, input.nameArabic, input.nameEnglish,
        input.addressArabic, input.addressEnglish, input.latitude ?? null, input.longitude ?? null,
        input.phone ?? null, input.whatsapp ?? null, input.workingHours ?? {}, input.services ?? [],
        input.verified ?? false, input.active ?? true
      ]);
      const office = result.rows[0] as Record<string, unknown> | undefined;
      if (!office) { await client.query("ROLLBACK"); return null; }
      await client.query(`INSERT INTO audit_logs(actor_id, action, entity_type, entity_id, after_value, request_id, ip_context)
        VALUES ($1, 'CREATE', 'office', $2, $3, $4, $5)`,
      [actor.id, String(office.id), office, requestId, ip ?? null]);
      await client.query("COMMIT");
      return office;
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally { client.release(); }
  }

  async updateOffice(officeId: string, input: OfficeUpdate, actor: AdminActor, requestId: string, ip?: string): Promise<Record<string, unknown> | null> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const currentResult = await client.query("SELECT * FROM offices WHERE id = $1 FOR UPDATE", [officeId]);
      const current = currentResult.rows[0] as Record<string, unknown> | undefined;
      if (!current) { await client.query("ROLLBACK"); return null; }
      const next = {
        publicCode: input.publicCode ?? current.public_code,
        countryId: input.countryId ?? current.country_id,
        cityId: input.cityId ?? current.city_id,
        nameArabic: input.nameArabic ?? current.name_ar,
        nameEnglish: input.nameEnglish ?? current.name_en,
        addressArabic: input.addressArabic ?? current.address_ar,
        addressEnglish: input.addressEnglish ?? current.address_en,
        latitude: input.latitude === undefined ? current.latitude : input.latitude,
        longitude: input.longitude === undefined ? current.longitude : input.longitude,
        phone: input.phone === undefined ? current.phone : input.phone,
        whatsapp: input.whatsapp === undefined ? current.whatsapp : input.whatsapp,
        workingHours: input.workingHours ?? current.working_hours,
        services: input.services ?? current.services,
        verified: input.verified ?? current.is_verified,
        active: input.active ?? current.is_active
      };
      const updatedResult = await client.query(`UPDATE offices o SET
        public_code = $2, country_id = c.id, city_id = ci.id, name_ar = $5, name_en = $6,
        address_ar = $7, address_en = $8, latitude = $9, longitude = $10, phone = $11,
        whatsapp = $12, working_hours = $13, services = $14, is_verified = $15,
        is_active = $16, updated_at = now()
        FROM countries c JOIN cities ci ON ci.country_id = c.id
        WHERE o.id = $1 AND c.id = $3 AND ci.id = $4 AND c.is_active AND ci.is_active
        RETURNING o.*`, [
        officeId, next.publicCode, next.countryId, next.cityId, next.nameArabic, next.nameEnglish,
        next.addressArabic, next.addressEnglish, next.latitude, next.longitude, next.phone, next.whatsapp,
        next.workingHours, next.services, next.verified, next.active
      ]);
      const updated = updatedResult.rows[0] as Record<string, unknown> | undefined;
      if (!updated) { await client.query("ROLLBACK"); return null; }
      await client.query(`INSERT INTO audit_logs(actor_id, action, entity_type, entity_id, before_value, after_value, request_id, ip_context)
        VALUES ($1, 'DELETE', 'office', $2, $3, $4, $5, $6)`,
      [actor.id, officeId, current, updated, requestId, ip ?? null]);
      await client.query("COMMIT");
      return updated;
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally { client.release(); }
  }

  async deleteOffice(officeId: string, actor: AdminActor, requestId: string, ip?: string): Promise<boolean> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const currentResult = await client.query("SELECT * FROM offices WHERE id = $1 FOR UPDATE", [officeId]);
      const current = currentResult.rows[0] as Record<string, unknown> | undefined;
      if (!current) { await client.query("ROLLBACK"); return false; }
      if (current.is_active) {
        const updatedResult = await client.query("UPDATE offices SET is_active = false, updated_at = now() WHERE id = $1 RETURNING *", [officeId]);
        await client.query(`INSERT INTO audit_logs(actor_id, action, entity_type, entity_id, before_value, after_value, request_id, ip_context)
          VALUES ($1, 'UPDATE', 'office', $2, $3, $4, $5, $6)`,
        [actor.id, officeId, current, updatedResult.rows[0], requestId, ip ?? null]);
      }
      await client.query("COMMIT");
      return true;
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally { client.release(); }
  }

  async listAgents(): Promise<Record<string, unknown>[]> {
    const result = await this.pool.query(`SELECT a.id, a.trade_name AS "tradeName", a.status::text,
      a.expires_at AS "expiresAt", a.created_at AS "createdAt",
      c.name_ar AS "countryArabic", c.name_en AS "countryEnglish",
      ci.name_ar AS "cityArabic", ci.name_en AS "cityEnglish"
      FROM agents a JOIN countries c ON c.id = a.country_id
      JOIN cities ci ON ci.id = a.city_id ORDER BY a.created_at DESC LIMIT 500`);
    return result.rows as Record<string, unknown>[];
  }

  async listAdmins(): Promise<Record<string, unknown>[]> {
    const result = await this.pool.query(`SELECT u.id, u.username, u.email, r.name AS role,
      u.disabled_at AS "disabledAt",
      u.last_login_at AS "lastLoginAt", u.created_at AS "createdAt"
      FROM admin_users u JOIN roles r ON r.id = u.role_id ORDER BY u.created_at DESC LIMIT 500`);
    return result.rows as Record<string, unknown>[];
  }

  async auditLog(): Promise<Record<string, unknown>[]> {
    const result = await this.pool.query(`SELECT l.id, l.action, l.entity_type AS "entityType",
      l.entity_id AS "entityId", l.before_value AS "beforeValue", l.after_value AS "afterValue",
      l.request_id AS "requestId", l.created_at AS "createdAt", u.username AS actor
      FROM audit_logs l LEFT JOIN admin_users u ON u.id = l.actor_id
      ORDER BY l.created_at DESC LIMIT 200`);
    return result.rows as Record<string, unknown>[];
  }

  async changePassword(actor: AdminActor, currentPassword: string, newPassword: string, requestId: string, ip?: string): Promise<boolean> {
    const result = await this.pool.query<{ password_hash: string }>(
      "SELECT password_hash FROM admin_users WHERE id = $1 AND disabled_at IS NULL", [actor.id]);
    const user = result.rows[0];
    if (!user) return false;
    const passwordValid = await verifyPassword(currentPassword, user.password_hash);
    if (!passwordValid) return false;

    const newHash = await hashPassword(newPassword);
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const updated = await client.query(
        "UPDATE admin_users SET password_hash = $2 WHERE id = $1 AND password_hash = $3 AND disabled_at IS NULL",
        [actor.id, newHash, user.password_hash]
      );
      if (updated.rowCount !== 1) { await client.query("ROLLBACK"); return false; }
      await client.query("UPDATE admin_sessions SET revoked_at = now() WHERE admin_user_id = $1 AND revoked_at IS NULL", [actor.id]);
      await client.query(`INSERT INTO audit_logs(actor_id, action, entity_type, entity_id, before_value, after_value, request_id, ip_context)
        VALUES ($1, 'UPDATE', 'admin_user', $2, '{"passwordChanged":false}'::jsonb, '{"passwordChanged":true}'::jsonb, $3, $4)`,
      [actor.id, actor.id, requestId, ip ?? null]);
      await client.query("COMMIT");
      return true;
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally { client.release(); }
  }

  async close(): Promise<void> { await this.pool.end(); }
}
