/**
 * THE single source of truth for the signed config payload (schemaVersion = 1).
 * Used for: admin input validation, the publish preview, publish, and signing at serve time.
 * Mirrors docs/CONFIG_CONTRACT.md — any change here requires a contract change first.
 */
import { z } from "zod";
import { checkHttpsUrl } from "./hosts";

export const SCHEMA_VERSION = 1 as const;

export const LOCALES = ["en", "ar", "de"] as const;
export type Locale = (typeof LOCALES)[number];

export const ICON_KEYS = [
  "youtube",
  "twitch",
  "tiktok",
  "rumble",
  "facebook",
  "instagram",
  "x",
  "reddit",
  "vimeo",
  "dailymotion",
  "news",
  "generic",
] as const;
export type IconKey = (typeof ICON_KEYS)[number];

export const PLACEMENT_IDS = ["home_banner", "downloads_banner", "tabs_interstitial"] as const;
export type PlacementId = (typeof PLACEMENT_IDS)[number];

export const PLACEMENT_FORMAT: Record<PlacementId, "banner" | "interstitial"> = {
  home_banner: "banner",
  downloads_banner: "banner",
  tabs_interstitial: "interstitial",
};

export const LIMITS = {
  maxShortcuts: 24,
  shortcutTitleMax: 40,
  noticeMessageMax: 280,
  maxNotices: 20,
  helpTextMax: 4000,
  interstitialMinIntervalSecMin: 300,
  interstitialMinIntervalSecMax: 86_400,
  interstitialMaxPerSessionMin: 0,
  interstitialMaxPerSessionMax: 3,
  blocklistMaxRules: 5000,
} as const;

export const AD_UNIT_ID_RE = /^ca-app-pub-\d{16}\/\d{10}$/;
export const SEMVER_RE = /^(0|[1-9]\d{0,4})\.(0|[1-9]\d{0,4})\.(0|[1-9]\d{0,4})$/;
export const KEY_RE = /^[a-z0-9][a-z0-9_-]{0,39}$/;
export const COLOR_RE = /^#[0-9A-Fa-f]{6}$/;
export const ASSET_ID_RE = /^[a-z0-9]{20,40}$/;
export const SHA256_HEX_RE = /^[a-f0-9]{64}$/;

/** Length in Unicode code points (what users perceive as characters). */
export const charLength = (s: string) => [...s].length;

const text = (max: number) =>
  z
    .string()
    .min(1)
    .refine((s) => charLength(s) <= max, { message: `Must be at most ${max} characters` })
    .refine((s) => s.trim().length > 0, { message: "Must not be blank" });

/** Localized text: `en` required, `ar`/`de` optional. */
export const localizedText = (max: number) =>
  z
    .object({
      en: text(max),
      ar: text(max).optional(),
      de: text(max).optional(),
    })
    .strict();

export const httpsUrl = (opts: { requirePublicHost: boolean }) =>
  z.string().superRefine((v, ctx) => {
    const r = checkHttpsUrl(v, opts);
    if (!r.ok) ctx.addIssue({ code: z.ZodIssueCode.custom, message: r.reason });
  });

export const semver = z.string().regex(SEMVER_RE, "Must be a version like 1.2.3");

export const isoDateTime = z.string().datetime({ offset: false });

export const shortcutSchema = z
  .object({
    id: z.string().regex(KEY_RE, "Lowercase letters, digits, '-' or '_' (max 40)"),
    title: localizedText(LIMITS.shortcutTitleMax),
    url: httpsUrl({ requirePublicHost: true }),
    iconKey: z.enum(ICON_KEYS).nullable(),
    iconAssetId: z.string().regex(ASSET_ID_RE).nullable(),
    color: z.string().regex(COLOR_RE, "Color must be #RRGGBB"),
    order: z.number().int().min(0).max(10_000),
  })
  .strict();

export const adUnitId = z.union([z.literal(""), z.string().regex(AD_UNIT_ID_RE, "Ad unit id must match ca-app-pub-<16 digits>/<10 digits>")]);

export const placementSchema = z
  .object({
    id: z.enum(PLACEMENT_IDS),
    format: z.enum(["banner", "interstitial"]),
    enabled: z.boolean(),
    adUnitIdAndroid: adUnitId,
    adUnitIdIos: adUnitId,
  })
  .strict()
  .refine((p) => PLACEMENT_FORMAT[p.id] === p.format, {
    message: "format does not match placement",
    path: ["format"],
  });

export const frequencySchema = z
  .object({
    interstitialMinIntervalSec: z
      .number()
      .int()
      .min(LIMITS.interstitialMinIntervalSecMin)
      .max(LIMITS.interstitialMinIntervalSecMax),
    interstitialMaxPerSession: z
      .number()
      .int()
      .min(LIMITS.interstitialMaxPerSessionMin)
      .max(LIMITS.interstitialMaxPerSessionMax),
  })
  .strict();

export const adsSchema = z
  .object({
    enabled: z.boolean(),
    placements: z
      .array(placementSchema)
      .max(PLACEMENT_IDS.length)
      .refine((ps) => new Set(ps.map((p) => p.id)).size === ps.length, "Duplicate placement id"),
    frequency: frequencySchema,
  })
  .strict();

export const blockingSchema = z
  .object({
    enabledByDefault: z.boolean(),
    listVersion: z.number().int().positive(),
    listPath: z.string(),
    listSha256: z.string().regex(SHA256_HEX_RE),
    ruleCount: z.number().int().min(0).max(LIMITS.blocklistMaxRules),
  })
  .strict()
  .refine((b) => b.listPath === `/api/v1/blocklists/${b.listVersion}`, {
    message: "listPath must be /api/v1/blocklists/{listVersion}",
    path: ["listPath"],
  });

export const contentSchema = z
  .object({
    privacyUrl: httpsUrl({ requirePublicHost: false }),
    termsUrl: httpsUrl({ requirePublicHost: false }),
    supportUrl: httpsUrl({ requirePublicHost: false }),
    helpText: localizedText(LIMITS.helpTextMax),
  })
  .strict();

export const noticeSchema = z
  .object({
    id: z.string().regex(KEY_RE, "Lowercase letters, digits, '-' or '_' (max 40)"),
    severity: z.enum(["info", "update"]),
    message: localizedText(LIMITS.noticeMessageMax),
    minAppVersion: semver.nullable(),
    maxAppVersion: semver.nullable(),
  })
  .strict();

export function compareSemver(a: string, b: string): number {
  const pa = a.split(".").map(Number);
  const pb = b.split(".").map(Number);
  for (let i = 0; i < 3; i++) {
    const d = (pa[i] ?? 0) - (pb[i] ?? 0);
    if (d !== 0) return d;
  }
  return 0;
}

const versionRangeOk = (v: { minAppVersion: string | null; maxAppVersion: string | null }) =>
  v.minAppVersion === null || v.maxAppVersion === null || compareSemver(v.minAppVersion, v.maxAppVersion) <= 0;

/** Fields shared by the stored release content and the signed payload. */
const contentShape = {
  schemaVersion: z.literal(SCHEMA_VERSION),
  configVersion: z.number().int().positive(),
  minAppVersion: semver.nullable(),
  maxAppVersion: semver.nullable(),
  shortcuts: z
    .array(shortcutSchema)
    .max(LIMITS.maxShortcuts)
    .refine((s) => new Set(s.map((x) => x.id)).size === s.length, "Duplicate shortcut id"),
  ads: adsSchema,
  blocking: blockingSchema,
  content: contentSchema,
  notices: z
    .array(noticeSchema.refine(versionRangeOk, "minAppVersion must be <= maxAppVersion"))
    .max(LIMITS.maxNotices)
    .refine((n) => new Set(n.map((x) => x.id)).size === n.length, "Duplicate notice id"),
};

/** What is stored in ConfigRelease.contentJson: the payload without issuedAt/expiresAt. */
export const releaseContentSchema = z
  .object(contentShape)
  .strict()
  .refine(versionRangeOk, { message: "minAppVersion must be <= maxAppVersion", path: ["maxAppVersion"] });

/** The exact payload that gets signed and served. */
export const configPayloadSchema = z
  .object({
    ...contentShape,
    issuedAt: isoDateTime,
    expiresAt: isoDateTime,
  })
  .strict()
  .refine(versionRangeOk, { message: "minAppVersion must be <= maxAppVersion", path: ["maxAppVersion"] })
  .refine((p) => Date.parse(p.expiresAt) > Date.parse(p.issuedAt), {
    message: "expiresAt must be after issuedAt",
    path: ["expiresAt"],
  });

export type ReleaseContent = z.infer<typeof releaseContentSchema>;
export type ConfigPayload = z.infer<typeof configPayloadSchema>;
export type ShortcutPayload = z.infer<typeof shortcutSchema>;
export type NoticePayload = z.infer<typeof noticeSchema>;

export const CONFIG_TTL_MS = 7 * 24 * 60 * 60 * 1000;

/**
 * Build the payload with a stable key order matching the contract
 * (schemaVersion, configVersion, issuedAt, expiresAt, ...).
 */
export function stampPayload(content: ReleaseContent, now: Date): ConfigPayload {
  return {
    schemaVersion: content.schemaVersion,
    configVersion: content.configVersion,
    issuedAt: now.toISOString(),
    expiresAt: new Date(now.getTime() + CONFIG_TTL_MS).toISOString(),
    minAppVersion: content.minAppVersion,
    maxAppVersion: content.maxAppVersion,
    shortcuts: content.shortcuts,
    ads: content.ads,
    blocking: content.blocking,
    content: content.content,
    notices: content.notices,
  };
}
