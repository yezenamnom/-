import { NextResponse } from "next/server";
import { Prisma } from "@prisma/client";
import { ZodError, type ZodTypeAny, type z } from "zod";
import { publicBaseUrl } from "./env";

export class HttpError extends Error {
  constructor(
    public readonly status: number,
    public readonly code: string,
    message?: string,
    public readonly details?: unknown,
  ) {
    super(message ?? code);
  }
}

export const NO_STORE = { "Cache-Control": "no-store" };

export function json(data: unknown, status = 200, headers: Record<string, string> = {}): NextResponse {
  return NextResponse.json(data, { status, headers: { ...NO_STORE, ...headers } });
}

export function errorJson(status: number, code: string, message?: string, details?: unknown): NextResponse {
  return json({ error: code, ...(message ? { message } : {}), ...(details !== undefined ? { details } : {}) }, status);
}

export function zodIssues(err: ZodError) {
  return err.issues.slice(0, 50).map((i) => ({ path: i.path.join("."), message: i.message }));
}

/** Read a JSON body with a hard size cap, then validate with zod. */
export async function readJson<S extends ZodTypeAny>(req: Request, schema: S, maxBytes = 64 * 1024): Promise<z.infer<S>> {
  const declared = Number(req.headers.get("content-length") ?? "0");
  if (declared > maxBytes) throw new HttpError(413, "payload_too_large");
  const ct = req.headers.get("content-type") ?? "";
  if (!ct.toLowerCase().startsWith("application/json")) throw new HttpError(415, "unsupported_media_type", "Expected application/json");
  const text = await req.text();
  if (Buffer.byteLength(text, "utf8") > maxBytes) throw new HttpError(413, "payload_too_large");
  let data: unknown;
  try {
    data = JSON.parse(text);
  } catch {
    throw new HttpError(400, "invalid_json");
  }
  const parsed = schema.safeParse(data);
  if (!parsed.success) throw new HttpError(400, "validation_failed", "Invalid input", zodIssues(parsed.error));
  return parsed.data;
}

/**
 * Client IP used for admin audit/login limits and (hashed) for report rate limits.
 * Uses the right-most X-Forwarded-For entry: Next.js sets it from the socket when absent, and a
 * reverse proxy (nginx `proxy_add_x_forwarded_for`, Caddy) appends the real peer address.
 * Production MUST run behind such a proxy; see README.
 */
export function clientIp(req: Request): string {
  const xff = req.headers.get("x-forwarded-for");
  if (xff) {
    const parts = xff.split(",").map((s) => s.trim()).filter(Boolean);
    const last = parts[parts.length - 1];
    if (last && last.length <= 64) return last.replace(/^::ffff:/, "");
  }
  const real = req.headers.get("x-real-ip")?.trim();
  if (real && real.length <= 64) return real;
  return "unknown";
}

/** Same-origin check for state-changing admin requests (defence in depth on top of SameSite + CSRF token). */
export function originAllowed(req: Request): boolean {
  const origin = req.headers.get("origin");
  if (!origin || origin === "null") return false;
  let o: URL;
  try {
    o = new URL(origin);
  } catch {
    return false;
  }
  const base = publicBaseUrl();
  if (base && o.origin === base.origin) return true;
  const host = req.headers.get("host");
  return !!host && o.host === host && (o.protocol === "https:" || o.protocol === "http:");
}

export function handleError(e: unknown): NextResponse {
  if (e instanceof HttpError) return errorJson(e.status, e.code, e.message !== e.code ? e.message : undefined, e.details);
  if (e instanceof ZodError) return errorJson(400, "validation_failed", "Invalid input", zodIssues(e));
  if (e instanceof Prisma.PrismaClientKnownRequestError) {
    if (e.code === "P2002") return errorJson(409, "conflict", "A record with this unique value already exists");
    if (e.code === "P2025") return errorJson(404, "not_found");
  }
  console.error("[api] unhandled error:", e instanceof Error ? e.message : "unknown");
  return errorJson(500, "internal_error");
}
