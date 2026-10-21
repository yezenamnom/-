import { prisma } from "./db";
import { configPayloadSchema, releaseContentSchema, stampPayload } from "./config-schema";
import { signingKeyId, signingPrivateKeyB64 } from "./env";
import { loadPrivateKey, signPayloadJson, type SignedEnvelope } from "./signing";
import type { KeyObject } from "node:crypto";

let cachedKey: { b64: string; key: KeyObject } | null = null;

/** Parsed signing key, or null when not configured / invalid (never throws, never logs the key). */
export function getSigningKey(): KeyObject | null {
  const b64 = signingPrivateKeyB64();
  if (!b64) return null;
  if (cachedKey?.b64 === b64) return cachedKey.key;
  try {
    const key = loadPrivateKey(b64);
    cachedKey = { b64, key };
    return key;
  } catch {
    return null;
  }
}

export type EnvelopeResult =
  | { status: 200; envelope: SignedEnvelope; configVersion: number }
  | { status: 404 | 500 | 503; error: string };

export async function buildSignedEnvelope(now = new Date()): Promise<EnvelopeResult> {
  const current = await prisma.configRelease.findFirst({ where: { isCurrent: true } });
  if (!current) return { status: 404, error: "no_published_config" };
  const key = getSigningKey();
  if (!key) return { status: 503, error: "signing_key_unavailable" };
  const content = releaseContentSchema.safeParse(JSON.parse(current.contentJson));
  if (!content.success) return { status: 500, error: "stored_config_invalid" };
  const payload = configPayloadSchema.safeParse(stampPayload(content.data, now));
  if (!payload.success) return { status: 500, error: "stored_config_invalid" };
  const payloadJson = JSON.stringify(payload.data);
  return { status: 200, envelope: signPayloadJson(payloadJson, key, signingKeyId()), configVersion: content.data.configVersion };
}

function utcDay(now: Date): Date {
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
}

/** Aggregated counter only: (UTC date, platform) → count. No IP, no device id, no app version. */
export async function countConfigFetch(platform: "android" | "ios" | "unknown", now = new Date()): Promise<void> {
  const date = utcDay(now);
  await prisma.dailyStat.upsert({
    where: { date_platform: { date, platform } },
    create: { date, platform, configFetches: 1 },
    update: { configFetches: { increment: 1 } },
  });
}

export async function configFetchesLastDays(days: number, now = new Date()) {
  const from = new Date(utcDay(now).getTime() - (days - 1) * 86_400_000);
  const rows = await prisma.dailyStat.findMany({ where: { date: { gte: from } }, orderBy: { date: "asc" } });
  const byDay = new Map<string, { date: string; android: number; ios: number; unknown: number; total: number }>();
  for (let i = 0; i < days; i++) {
    const d = new Date(from.getTime() + i * 86_400_000).toISOString().slice(0, 10);
    byDay.set(d, { date: d, android: 0, ios: 0, unknown: 0, total: 0 });
  }
  for (const r of rows) {
    const d = r.date.toISOString().slice(0, 10);
    const e = byDay.get(d);
    if (!e) continue;
    e[r.platform] += r.configFetches;
    e.total += r.configFetches;
  }
  const list = [...byDay.values()];
  return { days: list, total: list.reduce((s, d) => s + d.total, 0) };
}
