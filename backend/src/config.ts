import { z } from "zod";

const schema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  HOST: z.string().default("127.0.0.1"),
  PORT: z.coerce.number().int().min(1).max(65535).default(8080),
  DATABASE_URL: z.string().url(),
  LOOKUP_HASH_KEY: z.string().min(32),
  ADMIN_SESSION_HASH_KEY: z.string().min(32),
  ADMIN_MFA_ENCRYPTION_KEY: z.string().refine((value) => Buffer.from(value, "base64").length === 32),
  TRUST_PROXY: z.enum(["true", "false"]).default("false").transform((v) => v === "true")
});

export type AppConfig = z.infer<typeof schema>;

export function loadConfig(environment: NodeJS.ProcessEnv = process.env): AppConfig {
  return schema.parse(environment);
}
