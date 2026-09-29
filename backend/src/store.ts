import { createHmac } from "node:crypto";
import pg from "pg";
import type { AgentVerification, PublicOffice, PublicRate, TransferPublicStatus } from "./domain.js";
import { postgresSSLConfig } from "./postgres-ssl.js";

export interface PublicStore {
  health(): Promise<boolean>;
  listRates(filters: { country?: string | undefined; region?: string | undefined; search?: string | undefined }): Promise<PublicRate[]>;
  getRate(id: string): Promise<PublicRate | null>;
  rateHistory(routeId?: string | undefined): Promise<PublicRate[]>;
  listCountries(): Promise<unknown[]>;
  listCities(country?: string | undefined): Promise<unknown[]>;
  listRoutes(): Promise<unknown[]>;
  listOffices(filters: { country?: string | undefined; city?: string | undefined; search?: string | undefined }): Promise<PublicOffice[]>;
  publicConfig(): Promise<Record<string, unknown>>;
  listNotices(): Promise<unknown[]>;
  verifyAgent(hash: string): Promise<AgentVerification | null>;
  trackTransfer(hash: string, normalizedReference: string): Promise<TransferPublicStatus | null>;
  close(): Promise<void>;
}

export function blindIndex(value: string, key: string): string {
  return createHmac("sha256", key).update(value.trim().toUpperCase()).digest("hex");
}

const rateProjection = `
  r.id, rr.name_ar AS "routeNameArabic", rr.name_en AS "routeNameEnglish",
  rr.source_currency AS "sourceCurrency", rr.destination_currency AS "destinationCurrency",
  r.buy::text, r.sell::text, r.fee_fixed::text AS "feeFixed", r.fee_percent::text AS "feePercent",
  r.created_at AS "updatedAt", r.source_timestamp AS "sourceTimestamp", r.version::int,
  r.valid_from AS "validFrom", r.valid_until AS "validUntil",
  (r.source_timestamp + interval '15 minutes') AS "staleAfter"`;

export class PostgresPublicStore implements PublicStore {
  private readonly pool: pg.Pool;

  constructor(databaseURL: string) {
    this.pool = new pg.Pool({
      connectionString: databaseURL,
      max: 15,
      idleTimeoutMillis: 30_000,
      connectionTimeoutMillis: 5_000,
      ssl: postgresSSLConfig(databaseURL)
    });
  }

  async health(): Promise<boolean> {
    const result = await this.pool.query<{ ok: number }>("SELECT 1 AS ok");
    return result.rows[0]?.ok === 1;
  }

  async listRates(filters: { country?: string | undefined; region?: string | undefined; search?: string | undefined }): Promise<PublicRate[]> {
    const values: string[] = [];
    const conditions = ["r.is_active", "rr.is_active", "r.valid_from <= now()", "(r.valid_until IS NULL OR r.valid_until > now())"];
    if (filters.country) {
      values.push(filters.country.toUpperCase());
      conditions.push(`(oc.iso_code = $${values.length} OR dc.iso_code = $${values.length})`);
    }
    if (filters.search) {
      values.push(`%${filters.search}%`);
      conditions.push(`(rr.name_ar ILIKE $${values.length} OR rr.name_en ILIKE $${values.length})`);
    }
    const result = await this.pool.query<PublicRate>(`
      SELECT ${rateProjection}
      FROM rates r JOIN rate_routes rr ON rr.id = r.route_id
      JOIN countries oc ON oc.id = rr.origin_country_id JOIN countries dc ON dc.id = rr.destination_country_id
      WHERE ${conditions.join(" AND ")} ORDER BY rr.name_en, r.version DESC`, values);
    return result.rows;
  }

  async getRate(id: string): Promise<PublicRate | null> {
    const result = await this.pool.query<PublicRate>(`
      SELECT ${rateProjection} FROM rates r JOIN rate_routes rr ON rr.id = r.route_id
      WHERE r.id = $1 AND r.is_active AND rr.is_active AND r.valid_from <= now()
        AND (r.valid_until IS NULL OR r.valid_until > now())`, [id]);
    return result.rows[0] ?? null;
  }

  async rateHistory(routeId?: string): Promise<PublicRate[]> {
    const values = routeId ? [routeId] : [];
    const routeFilter = routeId ? "AND rr.id = $1" : "";
    const result = await this.pool.query<PublicRate>(`
      SELECT ${rateProjection} FROM rates r JOIN rate_routes rr ON rr.id = r.route_id
      WHERE rr.is_active ${routeFilter} ORDER BY r.source_timestamp DESC LIMIT 100`, values);
    return result.rows;
  }

  async listCountries(): Promise<unknown[]> {
    const result = await this.pool.query(`SELECT id, iso_code AS "isoCode", name_ar AS "nameArabic",
      name_en AS "nameEnglish" FROM countries WHERE is_active ORDER BY name_en`);
    return result.rows;
  }

  async listCities(country?: string): Promise<unknown[]> {
    const result = await this.pool.query(`SELECT ci.id, ci.name_ar AS "nameArabic", ci.name_en AS "nameEnglish",
      c.iso_code AS "countryCode" FROM cities ci JOIN countries c ON c.id = ci.country_id
      WHERE ci.is_active AND c.is_active AND ($1::text IS NULL OR c.iso_code = $1) ORDER BY c.name_en, ci.name_en`,
      [country?.toUpperCase() ?? null]);
    return result.rows;
  }

  async listRoutes(): Promise<unknown[]> {
    const result = await this.pool.query(`SELECT rr.id, rr.name_ar AS "nameArabic", rr.name_en AS "nameEnglish",
      rr.source_currency AS "sourceCurrency", rr.destination_currency AS "destinationCurrency",
      oc.iso_code AS "originCountry", dc.iso_code AS "destinationCountry"
      FROM rate_routes rr JOIN countries oc ON oc.id = rr.origin_country_id
      JOIN countries dc ON dc.id = rr.destination_country_id WHERE rr.is_active ORDER BY rr.name_en`);
    return result.rows;
  }

  async listOffices(filters: { country?: string | undefined; city?: string | undefined; search?: string | undefined }): Promise<PublicOffice[]> {
    const values: string[] = [];
    const conditions = ["o.is_active", "o.is_verified", "c.is_active", "ci.is_active"];
    if (filters.country) { values.push(filters.country.toUpperCase()); conditions.push(`c.iso_code = $${values.length}`); }
    if (filters.city) { values.push(`%${filters.city}%`); conditions.push(`(ci.name_ar ILIKE $${values.length} OR ci.name_en ILIKE $${values.length})`); }
    if (filters.search) { values.push(`%${filters.search}%`); conditions.push(`(o.name_ar ILIKE $${values.length} OR o.name_en ILIKE $${values.length})`); }
    const result = await this.pool.query<PublicOffice>(`
      SELECT o.id, o.public_code AS "publicCode", o.name_ar AS "nameArabic", o.name_en AS "nameEnglish",
        c.name_ar AS "countryArabic", c.name_en AS "countryEnglish", ci.name_ar AS "cityArabic", ci.name_en AS "cityEnglish",
        o.address_ar AS "addressArabic", o.address_en AS "addressEnglish", o.latitude::text, o.longitude::text,
        o.phone, o.whatsapp, o.working_hours AS "workingHours", o.services, true AS verified
      FROM offices o JOIN countries c ON c.id = o.country_id JOIN cities ci ON ci.id = o.city_id
      WHERE ${conditions.join(" AND ")} ORDER BY c.name_en, ci.name_en, o.name_en`, values);
    return result.rows;
  }

  async publicConfig(): Promise<Record<string, unknown>> {
    const result = await this.pool.query<{ key: string; value: unknown }>(
      "SELECT key, value FROM app_config WHERE is_public ORDER BY key");
    return Object.fromEntries(result.rows.map((row) => [row.key, row.value]));
  }

  async listNotices(): Promise<unknown[]> {
    const result = await this.pool.query(`SELECT id, title_ar AS "titleArabic", title_en AS "titleEnglish",
      body_ar AS "bodyArabic", body_en AS "bodyEnglish", kind, published_at AS "publishedAt", expires_at AS "expiresAt"
      FROM announcements WHERE is_active AND published_at <= now()
      AND (expires_at IS NULL OR expires_at > now()) ORDER BY published_at DESC`);
    return result.rows;
  }

  async verifyAgent(hash: string): Promise<AgentVerification | null> {
    const result = await this.pool.query<AgentVerification>(`
      SELECT a.trade_name AS "tradeName", json_build_object('ar', c.name_ar, 'en', c.name_en) AS country,
        json_build_object('ar', ci.name_ar, 'en', ci.name_en) AS city,
        CASE WHEN a.expires_at IS NOT NULL AND a.expires_at <= now() THEN 'EXPIRED' ELSE a.status::text END AS status
      FROM agents a JOIN countries c ON c.id = a.country_id JOIN cities ci ON ci.id = a.city_id
      WHERE a.code_hash = $1 OR a.phone_hash = $1 LIMIT 1`, [hash]);
    return result.rows[0] ?? null;
  }

  async trackTransfer(hash: string, normalizedReference: string): Promise<TransferPublicStatus | null> {
    const result = await this.pool.query<Omit<TransferPublicStatus, "reference">>(`
      SELECT origin_label AS origin, destination_label AS destination, status::text,
        updated_at AS "lastUpdate", estimated_completion AS "estimatedCompletion"
      FROM transfer_status_public WHERE reference_hash = $1 LIMIT 1`, [hash]);
    const row = result.rows[0];
    return row ? { reference: normalizedReference, ...row } : null;
  }

  async close(): Promise<void> { await this.pool.end(); }
}
