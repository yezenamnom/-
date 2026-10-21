/**
 * Host/URL safety helpers shared by the config schema and admin inputs.
 * Pure functions — no DNS lookups, no network access.
 */

const LABEL = "[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?";
export const HOSTNAME_RE = new RegExp(`^(?=.{1,253}$)${LABEL}(?:\\.${LABEL})*$`);

const BLOCKED_SUFFIXES = [
  "localhost",
  "local",
  "internal",
  "lan",
  "localdomain",
  "home.arpa",
  "intranet",
];

function parseIPv4(host: string): number[] | null {
  const m = /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/.exec(host);
  if (!m) return null;
  const parts = m.slice(1).map(Number);
  return parts.every((n) => n >= 0 && n <= 255) ? parts : null;
}

function inRange(ip: number[], base: number[], bits: number): boolean {
  const toInt = (p: number[]) => ((p[0]! << 24) >>> 0) + (p[1]! << 16) + (p[2]! << 8) + p[3]!;
  const mask = bits === 0 ? 0 : (~0 << (32 - bits)) >>> 0;
  return ((toInt(ip) & mask) >>> 0) === ((toInt(base) & mask) >>> 0);
}

const PRIVATE_V4: Array<[number[], number]> = [
  [[0, 0, 0, 0], 8],
  [[10, 0, 0, 0], 8],
  [[100, 64, 0, 0], 10],
  [[127, 0, 0, 0], 8],
  [[169, 254, 0, 0], 16],
  [[172, 16, 0, 0], 12],
  [[192, 0, 0, 0], 24],
  [[192, 0, 2, 0], 24],
  [[192, 168, 0, 0], 16],
  [[198, 18, 0, 0], 15],
  [[198, 51, 100, 0], 24],
  [[203, 0, 113, 0], 24],
  [[224, 0, 0, 0], 4],
  [[240, 0, 0, 0], 4],
];

/**
 * True when `hostname` (as produced by WHATWG URL parsing, i.e. lower-cased and with
 * numeric IPv4 forms normalised) is a public host: not localhost, not a private/reserved
 * IPv4 address, not an IPv6 literal, not a single-label or internal-only name.
 */
export function isPublicHostname(rawHost: string): boolean {
  let host = rawHost.toLowerCase();
  if (host.endsWith(".")) host = host.slice(0, -1);
  if (!host) return false;
  if (host.startsWith("[") || host.includes(":")) return false; // IPv6 literals rejected outright
  const v4 = parseIPv4(host);
  if (v4) return !PRIVATE_V4.some(([base, bits]) => inRange(v4, base, bits));
  if (/^[0-9.]+$/.test(host)) return false; // malformed numeric host
  if (!HOSTNAME_RE.test(host)) return false;
  if (!host.includes(".")) return false;
  return !BLOCKED_SUFFIXES.some((s) => host === s || host.endsWith(`.${s}`));
}

export type HttpsUrlCheck = { ok: true; url: URL } | { ok: false; reason: string };

/** https-only absolute URL, no credentials, length-capped. Optionally requires a public host. */
export function checkHttpsUrl(value: string, opts: { requirePublicHost: boolean }): HttpsUrlCheck {
  if (value.length > 2048) return { ok: false, reason: "URL is too long (max 2048)" };
  if (/\s/.test(value)) return { ok: false, reason: "URL must not contain whitespace" };
  let url: URL;
  try {
    url = new URL(value);
  } catch {
    return { ok: false, reason: "Invalid URL" };
  }
  if (url.protocol !== "https:") return { ok: false, reason: "Only https:// URLs are allowed" };
  if (url.username || url.password) return { ok: false, reason: "URL must not contain credentials" };
  if (!url.hostname) return { ok: false, reason: "URL must have a host" };
  if (opts.requirePublicHost && !isPublicHostname(url.hostname)) {
    return { ok: false, reason: "URL host must be a public hostname (no localhost/private IPs)" };
  }
  return { ok: true, url };
}

/** Bare hostname check (no scheme, port, path, query). Input is lower-cased by the caller. */
export function isBareHostname(value: string): boolean {
  return HOSTNAME_RE.test(value) || parseIPv4(value) !== null;
}
