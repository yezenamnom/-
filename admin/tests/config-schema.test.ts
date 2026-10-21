import { describe, expect, it } from "vitest";
import { configPayloadSchema, releaseContentSchema, stampPayload, type ReleaseContent } from "@/lib/config-schema";
import { isPublicHostname } from "@/lib/hosts";

const good: ReleaseContent = {
  schemaVersion: 1,
  configVersion: 12,
  minAppVersion: "1.0.0",
  maxAppVersion: null,
  shortcuts: [
    { id: "youtube", title: { en: "YouTube", ar: "يوتيوب", de: "YouTube" }, url: "https://m.youtube.com/", iconKey: "youtube", iconAssetId: null, color: "#E53935", order: 0 },
  ],
  ads: {
    enabled: true,
    placements: [
      { id: "home_banner", format: "banner", enabled: true, adUnitIdAndroid: "ca-app-pub-3940256099942544/9214589741", adUnitIdIos: "ca-app-pub-3940256099942544/2435281174" },
      { id: "tabs_interstitial", format: "interstitial", enabled: false, adUnitIdAndroid: "", adUnitIdIos: "" },
    ],
    frequency: { interstitialMinIntervalSec: 600, interstitialMaxPerSession: 1 },
  },
  blocking: { enabledByDefault: true, listVersion: 3, listPath: "/api/v1/blocklists/3", listSha256: "a".repeat(64), ruleCount: 120 },
  content: {
    privacyUrl: "https://example.invalid/privacy",
    termsUrl: "https://example.invalid/terms",
    supportUrl: "https://example.invalid/support",
    helpText: { en: "Help" },
  },
  notices: [{ id: "update-1-2", severity: "info", message: { en: "Update" }, minAppVersion: null, maxAppVersion: "1.1.9" }],
};

const clone = (): ReleaseContent => JSON.parse(JSON.stringify(good));
const bad = (mut: (c: ReleaseContent) => void) => {
  const c = clone();
  mut(c);
  return releaseContentSchema.safeParse(c).success;
};

describe("config schema", () => {
  it("accepts the contract example", () => {
    expect(releaseContentSchema.safeParse(good).success).toBe(true);
    const payload = stampPayload(good, new Date("2026-10-21T10:00:00.000Z"));
    expect(configPayloadSchema.safeParse(payload).success).toBe(true);
    expect(Object.keys(payload).slice(0, 4)).toEqual(["schemaVersion", "configVersion", "issuedAt", "expiresAt"]);
    expect(payload.expiresAt).toBe("2026-10-28T10:00:00.000Z");
  });

  it("rejects http and non-public shortcut URLs", () => {
    expect(bad((c) => (c.shortcuts[0]!.url = "http://m.youtube.com/"))).toBe(false);
    for (const u of [
      "https://localhost/",
      "https://127.0.0.1/",
      "https://10.1.2.3/",
      "https://192.168.0.1/",
      "https://172.16.5.4/",
      "https://169.254.169.254/latest/meta-data",
      "https://[::1]/",
      "https://0x7f000001/",
      "https://router/",
      "https://printer.local/",
      "https://svc.internal/",
      "https://user:pw@example.com/",
      "javascript:alert(1)",
    ]) {
      expect(bad((c) => (c.shortcuts[0]!.url = u)), u).toBe(false);
    }
    expect(bad((c) => (c.shortcuts[0]!.url = "https://8.8.8.8/"))).toBe(true);
  });

  it("enforces shortcut limits", () => {
    expect(bad((c) => (c.shortcuts = Array.from({ length: 25 }, (_, i) => ({ ...good.shortcuts[0]!, id: `s${i}` }))))).toBe(false);
    expect(bad((c) => (c.shortcuts = Array.from({ length: 24 }, (_, i) => ({ ...good.shortcuts[0]!, id: `s${i}` }))))).toBe(true);
    expect(bad((c) => (c.shortcuts[0]!.title = { en: "x".repeat(41) }))).toBe(false);
    expect(bad((c) => (c.shortcuts[0]!.title = { en: "ي".repeat(40) }))).toBe(true);
    expect(bad((c) => (c.shortcuts[0]!.title = { ar: "x" } as never))).toBe(false);
    expect(bad((c) => (c.shortcuts[0]!.iconKey = "evil" as never))).toBe(false);
    expect(bad((c) => (c.shortcuts[0]!.color = "red"))).toBe(false);
    expect(bad((c) => c.shortcuts.push({ ...good.shortcuts[0]! }))).toBe(false); // duplicate id
  });

  it("enforces ad caps and formats", () => {
    expect(bad((c) => (c.ads.frequency.interstitialMinIntervalSec = 299))).toBe(false);
    expect(bad((c) => (c.ads.frequency.interstitialMinIntervalSec = 300))).toBe(true);
    expect(bad((c) => (c.ads.frequency.interstitialMaxPerSession = 4))).toBe(false);
    expect(bad((c) => (c.ads.frequency.interstitialMaxPerSession = -1))).toBe(false);
    expect(bad((c) => (c.ads.frequency.interstitialMaxPerSession = 0))).toBe(true);
    expect(bad((c) => (c.ads.placements[0]!.format = "interstitial"))).toBe(false);
    expect(bad((c) => (c.ads.placements[0]!.id = "sidebar" as never))).toBe(false);
    expect(bad((c) => (c.ads.placements[0]!.adUnitIdAndroid = "ca-app-pub-123/456"))).toBe(false);
  });

  it("rejects http content URLs, bad notices, unknown keys and bad blocking path", () => {
    expect(bad((c) => (c.content.privacyUrl = "http://example.com/privacy"))).toBe(false);
    expect(bad((c) => (c.notices[0]!.severity = "critical" as never))).toBe(false);
    expect(bad((c) => (c.notices[0]!.message = { en: "x".repeat(281) }))).toBe(false);
    expect(bad((c) => ((c as unknown as Record<string, unknown>).script = "alert(1)"))).toBe(false);
    expect(bad((c) => (c.blocking.listPath = "https://evil.example/list"))).toBe(false);
    expect(bad((c) => ((c as { schemaVersion: number }).schemaVersion = 2))).toBe(false);
    expect(bad((c) => ((c.minAppVersion = "2.0.0"), (c.maxAppVersion = "1.0.0")))).toBe(false);
  });

  it("classifies hostnames", () => {
    expect(isPublicHostname("example.com")).toBe(true);
    expect(isPublicHostname("100.64.0.1")).toBe(false);
    expect(isPublicHostname("localhost.")).toBe(false);
    expect(isPublicHostname("foo.localhost")).toBe(false);
  });
});
