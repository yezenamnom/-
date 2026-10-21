import { createHmac } from "node:crypto";
import { z } from "zod";
import { prisma } from "./db";
import { isBareHostname } from "./hosts";

export const REPORT_LIMIT_PER_HOUR = 5;
const HOUR_MS = 60 * 60 * 1000;
const RETENTION_MS = 24 * HOUR_MS;

export const reportInput = z
  .object({
    category: z.enum(["site_broken", "blocking_issue", "video_issue", "ads_issue", "other"]),
    message: z
      .string()
      .refine((s) => s.trim().length > 0, "message is required")
      .refine((s) => [...s].length <= 2000, "message must be at most 2000 characters"),
    appVersion: z.string().regex(/^\d{1,5}\.\d{1,5}\.\d{1,5}([+-][0-9A-Za-z.-]{1,32})?$/, "appVersion must look like 1.2.3"),
    platform: z.enum(["android", "ios"]),
    locale: z.string().regex(/^[a-z]{2,3}([-_][A-Za-z0-9]{2,8})?$/, "Invalid locale"),
    siteHost: z
      .string()
      .max(253)
      .transform((s) => s.toLowerCase())
      .refine(isBareHostname, "siteHost must be a bare hostname (no scheme, port, path or query)")
      .nullable()
      .optional(),
  })
  .strict();

export type ReportInput = z.infer<typeof reportInput>;

export function hashIp(ip: string, salt: string): string {
  return createHmac("sha256", salt).update(ip, "utf8").digest("hex");
}

/**
 * Fixed one-hour windows per salted IP hash. Returns false when the caller is over the limit.
 * Rows older than 24h are purged on every call.
 */
export async function consumeReportQuota(ipHash: string, now = new Date()): Promise<boolean> {
  const windowStart = new Date(Math.floor(now.getTime() / HOUR_MS) * HOUR_MS);
  await prisma.reportRateLimit.deleteMany({ where: { windowStart: { lt: new Date(now.getTime() - RETENTION_MS) } } });
  const row = await prisma.reportRateLimit.upsert({
    where: { ipHash_windowStart: { ipHash, windowStart } },
    create: { ipHash, windowStart, count: 1 },
    update: { count: { increment: 1 } },
  });
  return row.count <= REPORT_LIMIT_PER_HOUR;
}
