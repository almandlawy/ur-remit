import Fastify from "fastify";
import helmet from "@fastify/helmet";
import rateLimit from "@fastify/rate-limit";
import { loadConfig, type AppConfig } from "./config.js";

export async function buildServer(config: AppConfig) {
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

  app.get("/api/v1/health", async (request) => ({
    status: "ok",
    service: "ur-public-api",
    version: "0.1.0",
    requestId: request.id,
    timestamp: new Date().toISOString()
  }));

  app.get("/api/v1/mobile/app-config", async (request) => ({
    requestId: request.id,
    data: {
      maintenanceMode: false,
      minimumSupportedVersion: "1.0.0",
      latestVersion: "1.0.0",
      featureFlags: {
        priceAlerts: false,
        officeQR: false,
        map: true,
        tracking: true,
        calculator: true
      }
    }
  }));

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

