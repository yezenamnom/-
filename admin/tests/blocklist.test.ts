import { describe, expect, it } from "vitest";
import { buildBlocklistBody, parseRulesText, selectorProblem, sha256Hex, urlFilterProblem } from "@/lib/blocklist";
import { starterRules } from "../prisma/seed-data/starter-blocklist";

const meta = { version: 1, name: "Test", license: "Original work by project owner" };
const blockRule = { action: "block", urlFilter: "^https?://([^/]+\\.)?doubleclick\\.net[/:]", resourceTypes: [] };

describe("blocklist validator", () => {
  it("accepts the starter list and serialises deterministically", () => {
    const a = buildBlocklistBody({ ...meta, rules: starterRules() });
    const b = buildBlocklistBody({ ...meta, rules: starterRules() });
    expect(a.ok).toBe(true);
    if (!a.ok || !b.ok) return;
    expect(a.body).toBe(b.body);
    expect(a.sha256).toBe(sha256Hex(Buffer.from(a.body, "utf8")));
    expect(a.ruleCount).toBeGreaterThanOrEqual(30);
    expect(a.ruleCount).toBeLessThanOrEqual(60);
    const parsed = JSON.parse(a.body);
    expect(parsed).toMatchObject({ format: "vela-blocklist", formatVersion: 1, version: 1 });
  });

  it("rejects forbidden urlFilter constructs", () => {
    for (const f of ["a|b", "a{2}", "x}", "(?=a)", "(?:a)", "\\d+", "\\w", "\\s", "\\bfoo", "\\1", "", "x".repeat(513), "é", "[unclosed"]) {
      expect(urlFilterProblem(f), f).not.toBeNull();
    }
    expect(urlFilterProblem("^https?://([^/]+\\.)?ads\\.example\\.com[/:]")).toBeNull();
  });

  it("enforces selector whitelist", () => {
    for (const s of [
      "a{color:red}",
      ".x'y",
      "div\\31",
      "<script>",
      "@import x",
      "a;b",
      "a/b",
      "div[style=\"background:url(x)\"]",
      ".x:expression(alert(1))",
      "x".repeat(1001),
      " ",
    ]) {
      expect(selectorProblem(s), s).not.toBeNull();
    }
    expect(selectorProblem(".ad-banner, #x > div[data-ad-slot^=\"a\"] + span ~ p:not(.y)")).toBeNull();
  });

  it("enforces the per-action rules from the contract", () => {
    const r = (rules: unknown[]) => buildBlocklistBody({ ...meta, rules }).ok;
    expect(r([blockRule])).toBe(true);
    expect(r([{ ...blockRule, action: "ignore-previous-rules" }])).toBe(false);
    expect(r([{ ...blockRule, ifDomain: ["example.com"] }])).toBe(false);
    expect(r([{ ...blockRule, unlessDomain: ["example.com"] }])).toBe(false);
    expect(r([{ ...blockRule, ifDomain: [], unlessDomain: [] }])).toBe(true);
    expect(r([{ ...blockRule, resourceTypes: ["popup"] }])).toBe(false);
    expect(r([{ ...blockRule, resourceTypes: ["script", "script"] }])).toBe(false);
    expect(r([{ ...blockRule, selector: ".x" }])).toBe(false);
    expect(r([{ ...blockRule, extra: 1 }])).toBe(false);
    expect(r([{ action: "css-display-none", urlFilter: ".*", selector: ".ad", ifDomain: ["*example.com", "news.example.org"] }])).toBe(true);
    expect(r([{ action: "css-display-none", urlFilter: "^https://x", selector: ".ad" }])).toBe(false);
    expect(r([{ action: "css-display-none", urlFilter: ".*" }])).toBe(false);
    expect(r([{ action: "css-display-none", urlFilter: ".*", selector: ".ad", ifDomain: ["not a domain"] }])).toBe(false);
  });

  it("enforces rule count and size caps", () => {
    expect(buildBlocklistBody({ ...meta, rules: Array.from({ length: 5001 }, () => blockRule) }).ok).toBe(false);
    expect(buildBlocklistBody({ ...meta, rules: Array.from({ length: 5000 }, () => blockRule) }).ok).toBe(true);
    const big = Array.from({ length: 5000 }, () => ({ action: "css-display-none", urlFilter: ".*", selector: ".a".repeat(150) }));
    const res = buildBlocklistBody({ ...meta, rules: big });
    expect(res.ok).toBe(false);
    expect(parseRulesText("not json").ok).toBe(false);
    expect(parseRulesText('{"rules":[]}').ok).toBe(true);
    expect(parseRulesText("[]").ok).toBe(true);
    expect(parseRulesText('{"x":1}').ok).toBe(false);
  });
});
