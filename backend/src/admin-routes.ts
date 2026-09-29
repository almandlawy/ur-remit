import type { FastifyInstance, FastifyRequest } from "fastify";
import { z } from "zod";
import { sessionFingerprint, type AdminActor, type AdminStore, type OfficeInput } from "./admin-store.js";

declare module "fastify" { interface FastifyRequest { adminActor?: AdminActor } }

const decimal = z.string().regex(/^\d{1,16}(\.\d{1,8})?$/);
const updateRateSchema = z.object({
  buy: decimal.nullable().optional(), sell: decimal.nullable().optional(),
  feeFixed: decimal.nullable().optional(), feePercent: decimal.nullable().optional(),
  validFrom: z.iso.datetime().optional(), validUntil: z.iso.datetime().nullable().optional(), active: z.boolean().optional()
}).strict().refine((value) => Object.keys(value).length > 0);
const idSchema = z.object({ id: z.string().uuid() });
const coordinate = (maximum: number) => z.string().regex(/^-?\d{1,3}(\.\d{1,6})?$/)
  .refine((value) => Math.abs(Number(value)) <= maximum).nullable().optional();
const officeFields = {
  countryId: z.string().uuid(),
  cityId: z.string().uuid(),
  publicCode: z.string().trim().min(2).max(32).regex(/^[A-Za-z0-9_-]+$/),
  nameArabic: z.string().trim().min(1).max(160),
  nameEnglish: z.string().trim().min(1).max(160),
  addressArabic: z.string().trim().min(1).max(500),
  addressEnglish: z.string().trim().min(1).max(500),
  latitude: coordinate(90),
  longitude: coordinate(180),
  phone: z.string().trim().max(32).nullable().optional(),
  whatsapp: z.string().trim().max(32).nullable().optional(),
  workingHours: z.record(z.string(), z.unknown()).optional(),
  services: z.array(z.unknown()).max(100).optional(),
  verified: z.boolean().optional(),
  active: z.boolean().optional()
};
const createOfficeSchema = z.object(officeFields).strict();
const updateOfficeSchema = z.object(officeFields).partial().strict()
  .refine((value) => Object.keys(value).length > 0);
const loginSchema = z.object({
  username: z.string().min(4).max(254).regex(/^[A-Za-z0-9@._-]+$/),
  password: z.string().min(10).max(256),
  mfaCode: z.string().regex(/^\d{6}$/)
});
const changePasswordSchema = z.object({
  currentPassword: z.string().min(10).max(256),
  newPassword: z.string().min(12).max(256),
  mfaCode: z.string().regex(/^\d{6}$/)
}).strict().refine((value) => value.currentPassword !== value.newPassword);

function bearerToken(request: FastifyRequest): string | null {
  const value = request.headers.authorization;
  if (!value?.startsWith("Bearer ")) return null;
  const token = value.slice(7);
  return /^[A-Za-z0-9_-]{32,256}$/.test(token) ? token : null;
}

export async function registerAdminRoutes(app: FastifyInstance, store: AdminStore, keys: { session: string; mfa: string }) {
  app.addHook("preHandler", async (request, reply) => {
    if (!request.url.startsWith("/api/v1/admin/")) return;
    if (request.url === "/api/v1/admin/auth/login" && request.method === "POST") return;
    const token = bearerToken(request);
    const actor = token ? await store.authenticate(sessionFingerprint(token, keys.session)) : null;
    if (!actor) return reply.code(401).send({ requestId: request.id, error: { code: "UNAUTHORIZED", message: "Authentication required" } });
    request.adminActor = actor;
  });

  app.post("/api/v1/admin/auth/login", { config: { rateLimit: { max: 5, timeWindow: "15 minutes" } } }, async (request, reply) => {
    const parsed = loginSchema.safeParse(request.body);
    if (!parsed.success) return reply.code(400).send({ requestId: request.id, error: { code: "INVALID_INPUT", message: "The request is invalid" } });
    const session = await store.login(parsed.data, keys, { requestId: request.id, ip: request.ip, userAgent: request.headers["user-agent"] });
    if (!session) return reply.code(401).send({ requestId: request.id, error: { code: "INVALID_CREDENTIALS", message: "Credentials could not be verified" } });
    return { requestId: request.id, data: session };
  });

  app.post("/api/v1/admin/auth/logout", async (request, reply) => {
    const token = bearerToken(request);
    if (!token) return reply.code(401).send({ requestId: request.id, error: { code: "UNAUTHORIZED", message: "Authentication required" } });
    await store.revokeSession(sessionFingerprint(token, keys.session), request.adminActor!.id, request.id, request.ip);
    return { requestId: request.id, data: { success: true } };
  });

  app.get("/api/v1/admin/me", async (request) => ({
    requestId: request.id,
    data: request.adminActor
  }));

  app.post("/api/v1/admin/auth/change-password", async (request, reply) => {
    const parsed = changePasswordSchema.safeParse(request.body);
    if (!parsed.success)
      return reply.code(400).send({ requestId: request.id, error: { code: "INVALID_INPUT", message: "The request is invalid" } });
    const changed = await store.changePassword(
      request.adminActor!, parsed.data.currentPassword, parsed.data.newPassword,
      parsed.data.mfaCode, keys.mfa, request.id, request.ip
    );
    return changed ? { requestId: request.id, data: { success: true } }
      : reply.code(401).send({ requestId: request.id, error: { code: "INVALID_CREDENTIALS", message: "Credentials could not be verified" } });
  });

  app.get("/api/v1/admin/dashboard", async (request, reply) => {
    if (!request.adminActor?.permissions.includes("dashboard.read"))
      return reply.code(403).send({ requestId: request.id, error: { code: "FORBIDDEN", message: "Insufficient permission" } });
    return { requestId: request.id, data: await store.dashboard() };
  });

  app.get("/api/v1/admin/rates", async (request, reply) => {
    if (!request.adminActor?.permissions.includes("rates.read"))
      return reply.code(403).send({ requestId: request.id, error: { code: "FORBIDDEN", message: "Insufficient permission" } });
    return { requestId: request.id, data: await store.listRates() };
  });

  app.patch("/api/v1/admin/rates/:id", async (request, reply) => {
    const actor = request.adminActor!;
    if (!actor.permissions.includes("rates.write"))
      return reply.code(403).send({ requestId: request.id, error: { code: "FORBIDDEN", message: "Insufficient permission" } });
    const params = idSchema.safeParse(request.params); const body = updateRateSchema.safeParse(request.body);
    if (!params.success || !body.success)
      return reply.code(400).send({ requestId: request.id, error: { code: "INVALID_INPUT", message: "The request is invalid" } });
    const rate = await store.updateRate(params.data.id, body.data, actor, request.id, request.ip);
    return rate ? { requestId: request.id, data: rate }
      : reply.code(404).send({ requestId: request.id, error: { code: "RATE_UNAVAILABLE", message: "Rate unavailable" } });
  });

  app.get("/api/v1/admin/offices", async (request, reply) => {
    if (!request.adminActor?.permissions.includes("offices.read"))
      return reply.code(403).send({ requestId: request.id, error: { code: "FORBIDDEN", message: "Insufficient permission" } });
    return { requestId: request.id, data: await store.listOffices() };
  });

  app.post("/api/v1/admin/offices", async (request, reply) => {
    const actor = request.adminActor!;
    if (!actor.permissions.includes("offices.write"))
      return reply.code(403).send({ requestId: request.id, error: { code: "FORBIDDEN", message: "Insufficient permission" } });
    const parsed = createOfficeSchema.safeParse(request.body);
    if (!parsed.success)
      return reply.code(400).send({ requestId: request.id, error: { code: "INVALID_INPUT", message: "The request is invalid" } });
    const office = await store.createOffice(parsed.data as OfficeInput, actor, request.id, request.ip);
    return office ? reply.code(201).send({ requestId: request.id, data: office })
      : reply.code(400).send({ requestId: request.id, error: { code: "INVALID_LOCATION", message: "The selected country or city is unavailable" } });
  });

  app.patch("/api/v1/admin/offices/:id", async (request, reply) => {
    const actor = request.adminActor!;
    if (!actor.permissions.includes("offices.write"))
      return reply.code(403).send({ requestId: request.id, error: { code: "FORBIDDEN", message: "Insufficient permission" } });
    const params = idSchema.safeParse(request.params);
    const body = updateOfficeSchema.safeParse(request.body);
    if (!params.success || !body.success)
      return reply.code(400).send({ requestId: request.id, error: { code: "INVALID_INPUT", message: "The request is invalid" } });
    const office = await store.updateOffice(params.data.id, body.data, actor, request.id, request.ip);
    return office ? { requestId: request.id, data: office }
      : reply.code(404).send({ requestId: request.id, error: { code: "OFFICE_UNAVAILABLE", message: "Office unavailable" } });
  });

  app.delete("/api/v1/admin/offices/:id", async (request, reply) => {
    const actor = request.adminActor!;
    if (!actor.permissions.includes("offices.write"))
      return reply.code(403).send({ requestId: request.id, error: { code: "FORBIDDEN", message: "Insufficient permission" } });
    const params = idSchema.safeParse(request.params);
    if (!params.success)
      return reply.code(400).send({ requestId: request.id, error: { code: "INVALID_INPUT", message: "The request is invalid" } });
    const deleted = await store.deleteOffice(params.data.id, actor, request.id, request.ip);
    return deleted ? { requestId: request.id, data: { success: true } }
      : reply.code(404).send({ requestId: request.id, error: { code: "OFFICE_UNAVAILABLE", message: "Office unavailable" } });
  });

  app.get("/api/v1/admin/agents", async (request, reply) => {
    if (!request.adminActor?.permissions.includes("agents.read"))
      return reply.code(403).send({ requestId: request.id, error: { code: "FORBIDDEN", message: "Insufficient permission" } });
    return { requestId: request.id, data: await store.listAgents() };
  });

  app.get("/api/v1/admin/users", async (request, reply) => {
    if (!request.adminActor?.permissions.includes("admins.read"))
      return reply.code(403).send({ requestId: request.id, error: { code: "FORBIDDEN", message: "Insufficient permission" } });
    return { requestId: request.id, data: await store.listAdmins() };
  });

  app.get("/api/v1/admin/audit", async (request, reply) => {
    if (!request.adminActor?.permissions.includes("audit.read"))
      return reply.code(403).send({ requestId: request.id, error: { code: "FORBIDDEN", message: "Insufficient permission" } });
    return { requestId: request.id, data: await store.auditLog() };
  });
}
