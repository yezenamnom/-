/**
 * "Vela Starter" blocklist — original work by the project owner.
 * NOT derived from EasyList or any third-party list. Hostnames of well-known ad/tracking
 * services are facts; the rule set, patterns and selection are our own.
 */

/** Ad / tracking hostnames (registrable domains). Subdomains are matched too. */
export const STARTER_BLOCKED_DOMAINS = [
  "doubleclick.net",
  "googlesyndication.com",
  "googleadservices.com",
  "adservice.google.com",
  "googletagservices.com",
  "google-analytics.com",
  "amazon-adsystem.com",
  "adnxs.com",
  "taboola.com",
  "outbrain.com",
  "criteo.com",
  "criteo.net",
  "scorecardresearch.com",
  "moatads.com",
  "pubmatic.com",
  "rubiconproject.com",
  "openx.net",
  "casalemedia.com",
  "adsrvr.org",
  "advertising.com",
  "smartadserver.com",
  "adform.net",
  "bidswitch.net",
  "sharethrough.com",
  "teads.tv",
  "33across.com",
  "contextweb.com",
  "indexww.com",
  "quantserve.com",
  "zedo.com",
  "mgid.com",
  "revcontent.com",
  "propellerads.com",
  "popads.net",
  "popcash.net",
  "exoclick.com",
  "adsterra.com",
  "bluekai.com",
  "krxd.net",
  "demdex.net",
  "everesttech.net",
  "lijit.com",
  "3lift.com",
  "gumgum.com",
  "adroll.com",
  "serving-sys.com",
  "flashtalking.com",
  "doubleverify.com",
  "adsafeprotected.com",
  "yieldmo.com",
] as const;

const escapeHost = (d: string) => d.replace(/\./g, "\\.");

/** Contract-recommended host pattern (WebKit + Java regex compatible); empty resourceTypes = all types. */
export function hostRule(domain: string) {
  return {
    action: "block" as const,
    urlFilter: `^https?://([^/]+\\.)?${escapeHost(domain)}[/:]`,
    resourceTypes: [] as string[],
  };
}

/** Generic cosmetic rules (our own selection of widely used ad container markers). */
export const STARTER_CSS_RULES = [
  { action: "css-display-none" as const, urlFilter: ".*", selector: "ins.adsbygoogle, .adsbygoogle" },
  { action: "css-display-none" as const, urlFilter: ".*", selector: "[id^=\"google_ads_iframe\"], [id^=\"div-gpt-ad\"]" },
  { action: "css-display-none" as const, urlFilter: ".*", selector: "[data-ad-slot], [data-ad-unit], [data-google-query-id]" },
  { action: "css-display-none" as const, urlFilter: ".*", selector: ".ad-banner, .ad-slot, .advertisement, .sponsored-ad" },
  { action: "css-display-none" as const, urlFilter: ".*", selector: "[id^=\"taboola-\"], .trc_related_container, .OUTBRAIN" },
];

export function starterRules() {
  return [...STARTER_BLOCKED_DOMAINS.map(hostRule), ...STARTER_CSS_RULES];
}

export const STARTER_NAME = "Vela Starter";
export const STARTER_LICENSE = "Original work by project owner";
