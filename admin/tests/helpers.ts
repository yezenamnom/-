import { prisma } from "@/lib/db";
import { hashPassword } from "@/lib/auth/password";
import { createSession, SESSION_COOKIE } from "@/lib/auth/session";
import type { RoleName } from "@/lib/auth/roles";
import { buildBlocklistBody } from "@/lib/blocklist";
import { generateSigningKeyPair } from "@/lib/signing";
import { starterRules } from "../prisma/seed-data/starter-blocklist";

export const ORIGIN = "http://admin.test";

const TABLES = [
  "AuditLog",
  "Session",
  "LoginAttempt",
  "Shortcut",
  "Asset",
  "AdSettings",
  "AdPlacement",
  "BlockList",
  "ContentSettings",
  "Notice",
  "ConfigRelease",
  "UserReport",
  "ReportRateLimit",
  "DailyStat",
  "AdminUser",
];

export async function resetDb() {
  await prisma.$executeRawUnsafe(`TRUNCATE ${TABLES.map((t) => `"${t}"`).join(", ")} CASCADE`);
}

let pwHash: string | null = null;
export const TEST_PASSWORD = "correct-horse-battery-staple";

export async function makeUser(role: RoleName, email = `${role.toLowerCase()}-${Math.random().toString(36).slice(2, 8)}@test.dev`) {
  pwHash ??= await hashPassword(TEST_PASSWORD);
  const user = await prisma.adminUser.create({ data: { email, role, passwordHash: pwHash } });
  const { token, session } = await createSession(user.id, "vitest");
  return { user, token, csrf: session.csrfToken, cookie: `${SESSION_COOKIE}=${token}` };
}

export type Who = { cookie: string; csrf: string } | null;

export function req(
  method: string,
  path: string,
  opts: { who?: Who; body?: unknown; csrf?: string | null; origin?: string | null; headers?: Record<string, string> } = {},
): Request {
  const headers: Record<string, string> = { host: "admin.test", ...(opts.headers ?? {}) };
  if (opts.who) headers.cookie = opts.who.cookie;
  const origin = opts.origin === undefined ? ORIGIN : opts.origin;
  if (origin && method !== "GET") headers.origin = origin;
  const csrf = opts.csrf === undefined ? opts.who?.csrf : opts.csrf;
  if (csrf && method !== "GET") headers["x-csrf-token"] = csrf;
  let body: string | undefined;
  if (opts.body !== undefined) {
    headers["content-type"] = "application/json";
    body = JSON.stringify(opts.body);
  }
  return new Request(`${ORIGIN}${path}`, { method, headers, body });
}

export const ctx = <P extends Record<string, string>>(params: P = {} as P) => ({ params: Promise.resolve(params) });

/** Seed a minimal publishable state (settings, placements, active blocklist, one shortcut). */
export async function seedPublishable() {
  await prisma.adSettings.create({ data: { id: 1, globalEnabled: true, interstitialMinIntervalSec: 600, interstitialMaxPerSession: 1 } });
  await prisma.adPlacement.createMany({
    data: [
      { key: "home_banner", format: "banner", enabled: true, adUnitIdAndroid: "ca-app-pub-3940256099942544/9214589741", adUnitIdIos: "ca-app-pub-3940256099942544/2435281174" },
      { key: "tabs_interstitial", format: "interstitial", enabled: false, adUnitIdAndroid: "ca-app-pub-3940256099942544/1033173712", adUnitIdIos: "ca-app-pub-3940256099942544/4411468910" },
    ],
  });
  await prisma.contentSettings.create({
    data: {
      id: 1,
      privacyUrl: "https://example.invalid/privacy",
      termsUrl: "https://example.invalid/terms",
      supportUrl: "https://example.invalid/support",
      helpText: { en: "Help", ar: "مساعدة", de: "Hilfe" },
      minAppVersion: "1.0.0",
    },
  });
  const built = buildBlocklistBody({ version: 1, name: "Vela Starter", license: "Original work by project owner", rules: starterRules() });
  if (!built.ok) throw new Error(built.errors.join(";"));
  await prisma.blockList.create({
    data: { version: 1, name: "Vela Starter", license: "Original work by project owner", body: built.body, sha256: built.sha256, ruleCount: built.ruleCount, status: "ACTIVE", activatedAt: new Date() },
  });
  await prisma.shortcut.create({
    data: { key: "youtube", titles: { en: "YouTube", ar: "يوتيوب", de: "YouTube" }, url: "https://m.youtube.com/", iconKey: "youtube", color: "#E53935", order: 0 },
  });
}

export function useSigningKey() {
  const kp = generateSigningKeyPair();
  process.env.CONFIG_SIGNING_PRIVATE_KEY = kp.privateKeyPkcs8B64; // gitleaks:allow (generated per test run)
  return kp;
}
