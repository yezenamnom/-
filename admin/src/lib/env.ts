import { z } from "zod";

/**
 * Server-side environment. Read lazily (per call) so tests can override process.env
 * and so a missing optional secret only disables the feature that needs it.
 * Never log values from here.
 */
export type AppEnv = "development" | "staging" | "production";

const appEnvSchema = z.enum(["development", "staging", "production"]);

export function appEnv(): AppEnv {
  const parsed = appEnvSchema.safeParse(process.env.APP_ENV ?? "development");
  return parsed.success ? parsed.data : "development";
}

export function isSecureDeployment(): boolean {
  return appEnv() !== "development";
}

export function signingKeyId(): string {
  const id = process.env.CONFIG_SIGNING_KEY_ID?.trim();
  return id && /^[A-Za-z0-9._-]{1,32}$/.test(id) ? id : "k1";
}

export function signingPrivateKeyB64(): string | null {
  const v = process.env.CONFIG_SIGNING_PRIVATE_KEY?.trim();
  return v ? v : null;
}

export function publicBaseUrl(): URL | null {
  const v = process.env.PUBLIC_BASE_URL?.trim();
  if (!v) return null;
  try {
    return new URL(v);
  } catch {
    return null;
  }
}

let devSalt: string | null = null;

/**
 * Salt for hashing app-user IPs (report rate limit only). Required outside development.
 * In development a random per-process salt is used so the feature still works.
 */
export function reportIpSalt(): string | null {
  const v = process.env.REPORT_IP_SALT?.trim();
  if (v && v.length >= 16) return v;
  if (appEnv() === "development") {
    if (!devSalt) devSalt = crypto.randomUUID() + crypto.randomUUID();
    return devSalt;
  }
  return null;
}
