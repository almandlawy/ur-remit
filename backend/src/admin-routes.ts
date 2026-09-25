import type { FastifyInstance, FastifyRequest } from "fastify";
import { z } from "zod";
import { sessionFingerprint, type AdminActor, type AdminStore } from "./admin-store.js";

declare module "fastify" { interface FastifyRequest { adminActor?: AdminActor } }

const decimal = z.string().regex(/^\d{1,16}(\.\d{1,8})?$/);
const updateRateSchema = z.object({
  buy: decimal.nullable().optional(), sell: decimal.nullable().optional(),
  feeFixed: decimal.nullable().optional(), feePercent: decimal.nullable().optional(),
  validFrom: z.iso.datetime().optional(), validUntil: z.iso.datetime().nullable().optional(), active: z.boolean().optional()
}).refine((value) => Object.keys(value).length > 0);
const idSchema = z.object({ id: z.string().uuid() });

function bearerToken(request: FastifyRequest): string | null {
  const value = request.headers.authorization;
  if (!value?.startsWith("Bearer ")) return null;
  const token = value.slice(7);
  return /^[A-Za-z0-9_-]{32,256}$/.test(token) ? token : null;
}

export async function registerAdminRoutes(app: FastifyInstance, store: AdminStore, sessionKey: string) {
  app.addHook("preHandler", async (request, reply) => {
    if (!request.url.startsWith("/api/v1/admin/")) return;
    const token = bearerToken(request);
    const actor = token ? await store.authenticate(sessionFingerprint(token, sessionKey)) : null;
    if (!actor) return reply.code(401).send({ requestId: request.id, error: { code: "UNAUTHORIZED", message: "Authentication required" } });
    request.adminActor = actor;
  });

  app.get("/api/v1/admin/dashboard", async (request, reply) => {
    if (!request.adminActor?.permissions.includes("dashboard.read"))
      return reply.code(403).send({ requestId: request.id, error: { code: "FORBIDDEN", message: "Insufficient permission" } });
    return { requestId: request.id, data: await store.dashboard() };
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
}
