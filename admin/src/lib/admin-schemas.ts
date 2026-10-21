/**
 * Input schemas for /api/admin/*. Field rules are built from the same building blocks as the
 * signed payload (config-schema.ts), so anything saveable is publishable.
 */
import { z } from "zod";
import {
  adUnitId,
  COLOR_RE,
  frequencySchema,
  httpsUrl,
  ICON_KEYS,
  KEY_RE,
  LIMITS,
  localizedText,
  PLACEMENT_IDS,
  ASSET_ID_RE,
  semver,
  compareSemver,
} from "./config-schema";
import { PASSWORD_MAX, PASSWORD_MIN } from "./auth/password";

const blankToUndefined = (v: unknown) => (typeof v === "string" && v.trim() === "" ? undefined : typeof v === "string" ? v.trim() : v);
const blankToNull = (v: unknown) => (typeof v === "string" && v.trim() === "" ? null : typeof v === "string" ? v.trim() : v);

export const localizedInput = (max: number) =>
  z.preprocess((v) => {
    if (!v || typeof v !== "object" || Array.isArray(v)) return v;
    const o = v as Record<string, unknown>;
    return { en: typeof o.en === "string" ? o.en.trim() : o.en, ar: blankToUndefined(o.ar), de: blankToUndefined(o.de) };
  }, localizedText(max));

const optionalSemver = z.preprocess(blankToNull, semver.nullable());

const versionRange = <T extends { minAppVersion: string | null; maxAppVersion: string | null }>(v: T) =>
  v.minAppVersion === null || v.maxAppVersion === null || compareSemver(v.minAppVersion, v.maxAppVersion) <= 0;

export const shortcutInput = z
  .object({
    key: z.string().trim().regex(KEY_RE, "Key: lowercase letters, digits, '-' or '_' (max 40)"),
    titles: localizedInput(LIMITS.shortcutTitleMax),
    url: z.string().trim().pipe(httpsUrl({ requirePublicHost: true })),
    iconKey: z.preprocess(blankToNull, z.enum(ICON_KEYS).nullable()),
    iconAssetId: z.preprocess(blankToNull, z.string().regex(ASSET_ID_RE).nullable()),
    color: z.string().trim().regex(COLOR_RE, "Color must be #RRGGBB"),
    enabled: z.boolean(),
  })
  .strict();
export type ShortcutInput = z.infer<typeof shortcutInput>;

export const reorderInput = z.object({ ids: z.array(z.string().min(1).max(40)).min(1).max(500) }).strict();

export const adsInput = z
  .object({
    globalEnabled: z.boolean(),
    frequency: frequencySchema,
    placements: z
      .array(
        z
          .object({
            key: z.enum(PLACEMENT_IDS),
            enabled: z.boolean(),
            adUnitIdAndroid: z.string().trim().pipe(adUnitId),
            adUnitIdIos: z.string().trim().pipe(adUnitId),
          })
          .strict(),
      )
      .max(PLACEMENT_IDS.length)
      .refine((ps) => new Set(ps.map((p) => p.key)).size === ps.length, "Duplicate placement"),
  })
  .strict();

export const contentInput = z
  .object({
    privacyUrl: z.string().trim().pipe(httpsUrl({ requirePublicHost: false })),
    termsUrl: z.string().trim().pipe(httpsUrl({ requirePublicHost: false })),
    supportUrl: z.string().trim().pipe(httpsUrl({ requirePublicHost: false })),
    helpText: localizedInput(LIMITS.helpTextMax),
    minAppVersion: optionalSemver,
    maxAppVersion: optionalSemver,
    blockingEnabledByDefault: z.boolean(),
  })
  .strict()
  .refine(versionRange, { message: "minAppVersion must be <= maxAppVersion", path: ["maxAppVersion"] });

export const noticeInput = z
  .object({
    key: z.string().trim().regex(KEY_RE, "Key: lowercase letters, digits, '-' or '_' (max 40)"),
    severity: z.enum(["info", "update"]),
    message: localizedInput(LIMITS.noticeMessageMax),
    minAppVersion: optionalSemver,
    maxAppVersion: optionalSemver,
    active: z.boolean(),
  })
  .strict()
  .refine(versionRange, { message: "minAppVersion must be <= maxAppVersion", path: ["maxAppVersion"] });

export const blocklistCreateInput = z
  .object({
    name: z.string().trim().min(1).max(100),
    license: z.string().trim().min(1).max(200),
    rulesText: z.string().min(2).max(1024 * 1024 + 1024),
  })
  .strict();

export const noteInput = z.object({ note: z.string().trim().max(500).default("") }).strict();

export const reportStatusInput = z.object({ status: z.enum(["NEW", "TRIAGED", "CLOSED"]) }).strict();

const email = z.string().trim().toLowerCase().email().max(254);
const password = z.string().min(PASSWORD_MIN).max(PASSWORD_MAX);

export const loginInput = z.object({ email: z.string().trim().max(254), password: z.string().min(1).max(PASSWORD_MAX) }).strict();

export const userCreateInput = z
  .object({ email, role: z.enum(["OWNER", "ADMIN", "READONLY"]), password })
  .strict();

export const userUpdateInput = z
  .object({
    role: z.enum(["OWNER", "ADMIN", "READONLY"]).optional(),
    disabled: z.boolean().optional(),
    password: password.optional(),
    unlock: z.literal(true).optional(),
  })
  .strict()
  .refine((v) => Object.keys(v).length > 0, "Nothing to update");

export const changeOwnPasswordInput = z.object({ currentPassword: z.string().min(1).max(PASSWORD_MAX), newPassword: password }).strict();

export const pageQuery = z.object({
  page: z.coerce.number().int().min(1).max(100_000).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(50),
});
