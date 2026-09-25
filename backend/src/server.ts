import Fastify from "fastify";
import helmet from "@fastify/helmet";
import rateLimit from "@fastify/rate-limit";
import { loadConfig, type AppConfig } from "./config.js";
import { registerPublicRoutes } from "./public-routes.js";
import { PostgresPublicStore, type PublicStore } from "./store.js";
import { registerAdminRoutes } from "./admin-routes.js";
import { PostgresAdminStore, type AdminStore } from "./admin-store.js";

export async function buildServer(config: AppConfig, suppliedStore?: PublicStore, suppliedAdminStore?: AdminStore) {
  const store = suppliedStore ?? new PostgresPublicStore(config.DATABASE_URL);
  const adminStore = suppliedAdminStore ?? new PostgresAdminStore(config.DATABASE_URL);
  const app = Fastify({
    logger: {
      level: config.NODE_ENV === "production" ? "info" : "debug",
      redact: ["req.headers.authorization", "req.headers.cookie", "*.token", "*.reference"]
    },
    trustProxy: config.TRUST_PROXY,
    requestIdHeader: "x-request-id"
  });

  await app.register(helmet, { global: true });
  await app.register(rateLimit, { max: 120, timeWindow: "1 minute" });

  app.get("/api/v1/health", async (request, reply) => {
    const database = await store.health().catch(() => false);
    if (!database) reply.code(503);
    return {
      status: database ? "ok" : "degraded", service: "ur-public-api", version: "0.1.0",
      requestId: request.id, timestamp: new Date().toISOString(),
      dependencies: { database: database ? "ok" : "unavailable" }
    };
  });

  await registerPublicRoutes(app, store, config.LOOKUP_HASH_KEY);
  await registerAdminRoutes(app, adminStore, config.ADMIN_SESSION_HASH_KEY);
  app.addHook("onClose", async () => store.close());
  app.addHook("onClose", async () => adminStore.close());

  app.setNotFoundHandler((request, reply) => reply.code(404).send({
    requestId: request.id,
    error: { code: "RESOURCE_NOT_FOUND", message: "Resource not found" }
  }));

  app.setErrorHandler((error, request, reply) => {
    request.log.error({ err: error }, "request failed");
    reply.code(500).send({
      requestId: request.id,
      error: { code: "INTERNAL_ERROR", message: "Request could not be completed" }
    });
  });

  return app;
}

if (process.env.NODE_ENV !== "test") {
  const config = loadConfig();
  const app = await buildServer(config);
  await app.listen({ host: config.HOST, port: config.PORT });
}
