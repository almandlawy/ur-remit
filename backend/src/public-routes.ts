import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { blindIndex, type PublicStore } from "./store.js";

const filtersSchema = z.object({
  country: z.string().trim().length(2).optional(), region: z.string().trim().max(80).optional(),
  city: z.string().trim().max(120).optional(), search: z.string().trim().min(1).max(120).optional()
});
const idSchema = z.object({ id: z.string().uuid() });
const agentSchema = z.object({
  code: z.string().trim().min(4).max(40).optional(),
  phone: z.string().trim().regex(/^\+?[0-9]{8,15}$/).optional()
}).refine((value) => Number(Boolean(value.code)) + Number(Boolean(value.phone)) === 1);
const referenceSchema = z.object({ reference: z.string().trim().toUpperCase().regex(/^UR-[A-Z0-9]{8}$/) });
const historySchema = z.object({ routeId: z.string().uuid().optional() });

const validationFailure = (requestId: string) => ({
  requestId, error: { code: "INVALID_INPUT", message: "The request is invalid" }
});

export async function registerPublicRoutes(app: FastifyInstance, store: PublicStore, lookupKey: string) {
  app.get("/api/v1/mobile/rates", async (request, reply) => {
    const parsed = filtersSchema.safeParse(request.query);
    if (!parsed.success) return reply.code(400).send(validationFailure(request.id));
    return { requestId: request.id, data: await store.listRates(parsed.data) };
  });

  app.get("/api/v1/mobile/rates/:id", async (request, reply) => {
    const parsed = idSchema.safeParse(request.params);
    if (!parsed.success) return reply.code(400).send(validationFailure(request.id));
    const rate = await store.getRate(parsed.data.id);
    return rate ? { requestId: request.id, data: rate }
      : reply.code(404).send({ requestId: request.id, error: { code: "RATE_UNAVAILABLE", message: "Rate unavailable" } });
  });

  app.get("/api/v1/mobile/rates/history", async (request, reply) => {
    const parsed = historySchema.safeParse(request.query);
    if (!parsed.success) return reply.code(400).send(validationFailure(request.id));
    return { requestId: request.id, data: await store.rateHistory(parsed.data.routeId) };
  });

  app.get("/api/v1/mobile/countries", async (request) => ({ requestId: request.id, data: await store.listCountries() }));
  app.get("/api/v1/mobile/cities", async (request, reply) => {
    const parsed = z.object({ country: z.string().length(2).optional() }).safeParse(request.query);
    if (!parsed.success) return reply.code(400).send(validationFailure(request.id));
    return { requestId: request.id, data: await store.listCities(parsed.data.country) };
  });
  app.get("/api/v1/mobile/routes", async (request) => ({ requestId: request.id, data: await store.listRoutes() }));
  app.get("/api/v1/mobile/app-config", async (request) => ({ requestId: request.id, data: await store.publicConfig() }));
  app.get("/api/v1/mobile/notices", async (request) => ({ requestId: request.id, data: await store.listNotices() }));

  app.get("/api/v1/mobile/offices", async (request, reply) => {
    const parsed = filtersSchema.safeParse(request.query);
    if (!parsed.success) return reply.code(400).send(validationFailure(request.id));
    return { requestId: request.id, data: await store.listOffices(parsed.data) };
  });

  app.get("/api/v1/mobile/agents/verify", { config: { rateLimit: { max: 20, timeWindow: "1 minute" } } }, async (request, reply) => {
    const parsed = agentSchema.safeParse(request.query);
    if (!parsed.success) return reply.code(400).send(validationFailure(request.id));
    const value = parsed.data.code ?? parsed.data.phone!;
    const agent = await store.verifyAgent(blindIndex(value, lookupKey));
    return { requestId: request.id, data: agent ?? { status: "NOT_FOUND" } };
  });

  app.get("/api/v1/mobile/transfers/:reference/status", { config: { rateLimit: { max: 10, timeWindow: "1 minute" } } }, async (request, reply) => {
    const parsed = referenceSchema.safeParse(request.params);
    if (!parsed.success) return reply.code(400).send(validationFailure(request.id));
    const transfer = await store.trackTransfer(blindIndex(parsed.data.reference, lookupKey), parsed.data.reference);
    return transfer ? { requestId: request.id, data: transfer }
      : reply.code(404).send({ requestId: request.id, error: { code: "TRACKING_UNAVAILABLE", message: "Tracking information unavailable" } });
  });
}
