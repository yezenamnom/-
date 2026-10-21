/**
 * Blocklist validation + canonical serialisation (CONFIG_CONTRACT.md, "GET /api/v1/blocklists/{version}").
 * The serialised body is stored verbatim and served byte-for-byte; listSha256 is over those bytes.
 */
import { createHash } from "node:crypto";
import { z } from "zod";
import { HOSTNAME_RE } from "./hosts";
import { LIMITS } from "./config-schema";

export const BLOCKLIST_FORMAT = "vela-blocklist" as const;
export const BLOCKLIST_FORMAT_VERSION = 1 as const;
export const BLOCKLIST_MAX_BYTES = 1024 * 1024;
export const URL_FILTER_MAX = 512;
export const SELECTOR_MAX = 1000;

export const RESOURCE_TYPES = [
  "document",
  "image",
  "style-sheet",
  "script",
  "font",
  "raw",
  "svg-document",
  "media",
] as const;

/** v1: `ignore-previous-rules` is intentionally unsupported (not applied by flutter_inappwebview on Android). */
export const RULE_ACTIONS = ["block", "css-display-none"] as const;

/** Why a urlFilter is outside the WebKit Content Rule regex subset, or null when OK. */
export function urlFilterProblem(f: string): string | null {
  if (f.length === 0) return "urlFilter must not be empty";
  if (f.length > URL_FILTER_MAX) return `urlFilter longer than ${URL_FILTER_MAX}`;
  if (!/^[\x20-\x7E]+$/.test(f)) return "urlFilter must be printable ASCII";
  if (f.includes("|")) return "urlFilter must not contain '|' (alternation unsupported)";
  if (f.includes("{") || f.includes("}")) return "urlFilter must not contain '{' or '}' (counted repetition unsupported)";
  if (f.includes("(?")) return "urlFilter must not contain '(?' (lookarounds/non-capturing groups unsupported)";
  if (/\\[dDwWsSbB1-9]/.test(f)) return "urlFilter must not use \\d \\w \\s \\b (or upper-case variants / back-references)";
  try {
    new RegExp(f);
  } catch {
    return "urlFilter is not a valid regular expression";
  }
  return null;
}

/** Contract whitelist: ASCII letters/digits, space and . # _ - [ ] = ^ $ * ~ : ( ) , > + " */
export const SELECTOR_ALLOWED_RE = /^[A-Za-z0-9 .#_\-[\]=^$*~:(),>+"]+$/;

/** Why a CSS selector is unsafe/invalid for css-display-none, or null when OK. */
export function selectorProblem(s: string): string | null {
  if (s.trim().length === 0) return "selector must not be empty";
  if (s.length > SELECTOR_MAX) return `selector longer than ${SELECTOR_MAX}`;
  if (!SELECTOR_ALLOWED_RE.test(s)) {
    return "selector contains a forbidden character (allowed: ASCII letters/digits, space and . # _ - [ ] = ^ $ * ~ : ( ) , > + \")";
  }
  const lower = s.toLowerCase();
  for (const bad of ["url(", "expression("]) {
    if (lower.includes(bad)) return `selector must not contain '${bad}'`;
  }
  return null;
}

const domainEntry = z
  .string()
  .max(253)
  .transform((d) => d.toLowerCase())
  .refine(
    (d) => HOSTNAME_RE.test(d.startsWith("*") ? d.slice(1).replace(/^\./, "") : d),
    "Invalid domain: a hostname, or '*' + suffix (e.g. *example.com)",
  );

const ruleInput = z
  .object({
    action: z.enum(RULE_ACTIONS),
    urlFilter: z.string().superRefine((f, ctx) => {
      const p = urlFilterProblem(f);
      if (p) ctx.addIssue({ code: z.ZodIssueCode.custom, message: p });
    }),
    resourceTypes: z
      .array(z.enum(RESOURCE_TYPES))
      .max(RESOURCE_TYPES.length)
      .refine((a) => new Set(a).size === a.length, "Duplicate resource type")
      .optional(),
    selector: z
      .string()
      .superRefine((s, ctx) => {
        const p = selectorProblem(s);
        if (p) ctx.addIssue({ code: z.ZodIssueCode.custom, message: p });
      })
      .optional(),
    ifDomain: z.array(domainEntry).max(1000).optional(),
    unlessDomain: z.array(domainEntry).max(1000).optional(),
  })
  .strict()
  .superRefine((r, ctx) => {
    const issue = (message: string, path: string) => ctx.addIssue({ code: z.ZodIssueCode.custom, message, path: [path] });
    if (r.action === "block") {
      // Android matches these against the REQUEST host, WebKit against the PAGE host → forbidden for block rules.
      if ((r.ifDomain?.length ?? 0) > 0) issue("block rules must not use ifDomain (must be empty or absent)", "ifDomain");
      if ((r.unlessDomain?.length ?? 0) > 0) issue("block rules must not use unlessDomain (must be empty or absent)", "unlessDomain");
      if (r.selector !== undefined) issue("selector is only allowed for css-display-none", "selector");
    } else {
      if (!r.selector) issue("css-display-none requires selector", "selector");
      if (r.urlFilter !== ".*") issue("css-display-none urlFilter must be \".*\"", "urlFilter");
      if (r.resourceTypes !== undefined) issue("resourceTypes is not allowed for css-display-none", "resourceTypes");
      if ((r.unlessDomain?.length ?? 0) > 0) issue("css-display-none supports ifDomain (page domains) only", "unlessDomain");
    }
  });

export type BlockRule = z.infer<typeof ruleInput>;

export const rulesSchema = z.array(ruleInput).max(LIMITS.blocklistMaxRules, `At most ${LIMITS.blocklistMaxRules} rules`);

export const blocklistMetaSchema = z
  .object({
    name: z.string().trim().min(1).max(100),
    license: z.string().trim().min(1).max(200),
  })
  .strict();

export type BlocklistBuildResult =
  | { ok: true; body: string; sha256: string; ruleCount: number }
  | { ok: false; errors: string[] };

export function sha256Hex(data: string | Buffer): string {
  return createHash("sha256").update(typeof data === "string" ? Buffer.from(data, "utf8") : data).digest("hex");
}

/** Accepts the pasted JSON text: either a rules array or an object with a `rules` array. */
export function parseRulesText(text: string): { ok: true; rules: unknown } | { ok: false; errors: string[] } {
  if (Buffer.byteLength(text, "utf8") > BLOCKLIST_MAX_BYTES) return { ok: false, errors: ["Input larger than 1 MB"] };
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    return { ok: false, errors: ["Input is not valid JSON"] };
  }
  if (Array.isArray(parsed)) return { ok: true, rules: parsed };
  if (parsed && typeof parsed === "object" && Array.isArray((parsed as { rules?: unknown }).rules)) {
    return { ok: true, rules: (parsed as { rules: unknown }).rules };
  }
  return { ok: false, errors: ["Expected a JSON array of rules or an object with a 'rules' array"] };
}

function formatIssues(err: z.ZodError, max = 20): string[] {
  const out = err.issues.slice(0, max).map((i) => `${i.path.length ? `rules[${i.path.join("].")}` : "rules"}: ${i.message}`.replace("].]", "]"));
  if (err.issues.length > max) out.push(`… and ${err.issues.length - max} more`);
  return out;
}

/** Validate rules and produce the exact body bytes that will be served. */
export function buildBlocklistBody(input: {
  version: number;
  name: string;
  license: string;
  rules: unknown;
}): BlocklistBuildResult {
  const meta = blocklistMetaSchema.safeParse({ name: input.name, license: input.license });
  if (!meta.success) return { ok: false, errors: meta.error.issues.map((i) => `${i.path.join(".")}: ${i.message}`) };
  const rules = rulesSchema.safeParse(input.rules);
  if (!rules.success) return { ok: false, errors: formatIssues(rules.error) };

  const normalized = rules.data.map((r) => {
    const out: Record<string, unknown> = { action: r.action, urlFilter: r.urlFilter };
    if (r.resourceTypes) out.resourceTypes = r.resourceTypes;
    if (r.selector !== undefined) out.selector = r.selector;
    if (r.ifDomain) out.ifDomain = r.ifDomain;
    if (r.unlessDomain) out.unlessDomain = r.unlessDomain;
    return out;
  });
  const body = JSON.stringify({
    format: BLOCKLIST_FORMAT,
    formatVersion: BLOCKLIST_FORMAT_VERSION,
    version: input.version,
    name: meta.data.name,
    license: meta.data.license,
    rules: normalized,
  });
  if (Buffer.byteLength(body, "utf8") > BLOCKLIST_MAX_BYTES) return { ok: false, errors: ["Serialized list larger than 1 MB"] };
  return { ok: true, body, sha256: sha256Hex(body), ruleCount: normalized.length };
}
