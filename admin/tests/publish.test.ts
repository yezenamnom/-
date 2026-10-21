import { beforeEach, describe, expect, it } from "vitest";
import { createHash } from "node:crypto";
import { prisma } from "@/lib/db";
import { loadRawPublicKey, verifyEnvelope } from "@/lib/signing";
import { configPayloadSchema } from "@/lib/config-schema";
import * as publish from "@/app/api/admin/publish/route";
import * as rollback from "@/app/api/admin/releases/[version]/rollback/route";
import * as shortcutById from "@/app/api/admin/shortcuts/[id]/route";
import * as blocklists from "@/app/api/admin/blocklists/route";
import * as activate from "@/app/api/admin/blocklists/[version]/activate/route";
import { GET as configGet } from "@/app/api/v1/config/route";
import { GET as blocklistGet } from "@/app/api/v1/blocklists/[version]/route";
import { GET as healthGet } from "@/app/api/v1/health/route";
import { ctx, makeUser, req, resetDb, seedPublishable, useSigningKey } from "./helpers";

beforeEach(async () => {
  await resetDb();
});

async function fetchConfig(query = "") {
  return configGet(new Request(`http://admin.test/api/v1/config${query}`));
}

describe("publish + serve", () => {
  it("health", async () => {
    const r = healthGet();
    expect(await r.json()).toMatchObject({ status: "ok" });
  });

  it("404 when nothing published, 503 when key missing", async () => {
    useSigningKey();
    const r = await fetchConfig();
    expect(r.status).toBe(404);
    expect(await r.json()).toEqual({ error: "no_published_config" });
    await seedPublishable();
    const admin = await makeUser("ADMIN");
    expect((await publish.POST(req("POST", "/api/admin/publish", { who: admin, body: { note: "v1" } }), ctx())).status).toBe(201);
    delete process.env.CONFIG_SIGNING_PRIVATE_KEY;
    expect((await fetchConfig()).status).toBe(503);
  });

  it("refuses to publish an invalid draft (no active blocklist)", async () => {
    await seedPublishable();
    await prisma.blockList.updateMany({ data: { status: "ARCHIVED" } });
    const admin = await makeUser("ADMIN");
    const r = await publish.POST(req("POST", "/api/admin/publish", { who: admin, body: { note: "" } }), ctx());
    expect(r.status).toBe(422);
    expect(await prisma.configRelease.count()).toBe(0);
  });

  it("publishes incrementing versions; envelope verifies and matches schema; counts fetches", async () => {
    const kp = useSigningKey();
    await seedPublishable();
    const admin = await makeUser("ADMIN");
    const preview = await publish.GET(req("GET", "/api/admin/publish", { who: admin }), ctx());
    const pj = await preview.json();
    expect(pj).toMatchObject({ nextVersion: 1, valid: true });

    const p1 = await publish.POST(req("POST", "/api/admin/publish", { who: admin, body: { note: "first" } }), ctx());
    expect(await p1.json()).toMatchObject({ version: 1 });
    const p2 = await publish.POST(req("POST", "/api/admin/publish", { who: admin, body: { note: "second" } }), ctx());
    expect(await p2.json()).toMatchObject({ version: 2 });
    expect(await prisma.configRelease.count({ where: { isCurrent: true } })).toBe(1);

    const res = await fetchConfig("?platform=android&appVersion=1.0.0");
    expect(res.status).toBe(200);
    expect(res.headers.get("cache-control")).toMatch(/max-age=\d+/);
    const env = await res.json();
    expect(Object.keys(env)).toEqual(["keyId", "payload", "signature"]);
    const v = verifyEnvelope(env, loadRawPublicKey(kp.publicKeyRawB64url));
    expect(v.ok).toBe(true);
    if (!v.ok) return;
    const payload = configPayloadSchema.parse(JSON.parse(v.payloadJson));
    expect(payload.configVersion).toBe(2);
    expect(Date.parse(payload.expiresAt) - Date.parse(payload.issuedAt)).toBe(7 * 24 * 3600 * 1000);
    expect(payload.shortcuts.map((s) => s.id)).toEqual(["youtube"]);

    // listSha256 matches the exact served bytes.
    const bl = await blocklistGet(new Request("http://admin.test/api/v1/blocklists/1"), ctx({ version: "1" }));
    expect(bl.status).toBe(200);
    expect(bl.headers.get("content-type")).toMatch(/application\/json/);
    expect(bl.headers.get("cache-control")).toMatch(/immutable/);
    const bytes = Buffer.from(await bl.arrayBuffer());
    expect(createHash("sha256").update(bytes).digest("hex")).toBe(payload.blocking.listSha256);

    await fetchConfig("?platform=ios");
    await fetchConfig();
    const stats = await prisma.dailyStat.findMany();
    expect(stats.reduce((s, r) => s + r.configFetches, 0)).toBe(3);
    expect(stats.map((s) => s.platform).sort()).toEqual(["android", "ios", "unknown"]);
  });

  it("rollback creates a NEW version with the old content", async () => {
    useSigningKey();
    await seedPublishable();
    const admin = await makeUser("ADMIN");
    await publish.POST(req("POST", "/api/admin/publish", { who: admin, body: { note: "v1" } }), ctx());
    const sc = await prisma.shortcut.findFirstOrThrow();
    await shortcutById.PUT(
      req("PUT", `/api/admin/shortcuts/${sc.id}`, {
        who: admin,
        body: { key: "youtube", titles: { en: "YT changed" }, url: "https://m.youtube.com/", iconKey: "youtube", iconAssetId: null, color: "#E53935", enabled: true },
      }),
      ctx({ id: sc.id }),
    );
    await publish.POST(req("POST", "/api/admin/publish", { who: admin, body: { note: "v2" } }), ctx());
    const rb = await rollback.POST(req("POST", "/api/admin/releases/1/rollback", { who: admin, body: { note: "" } }), ctx({ version: "1" }));
    expect(rb.status).toBe(201);
    expect(await rb.json()).toEqual({ version: 3, rolledBackFromVersion: 1 });
    const [v1, v3] = await Promise.all([
      prisma.configRelease.findUniqueOrThrow({ where: { version: 1 } }),
      prisma.configRelease.findUniqueOrThrow({ where: { version: 3 } }),
    ]);
    expect(v3.isCurrent).toBe(true);
    const c1 = JSON.parse(v1.contentJson);
    const c3 = JSON.parse(v3.contentJson);
    expect(c3.configVersion).toBe(3);
    expect({ ...c3, configVersion: 1 }).toEqual(c1);
    expect(c3.shortcuts[0].title.en).toBe("YouTube");
    const missing = await rollback.POST(req("POST", "/api/admin/releases/99/rollback", { who: admin, body: {} }), ctx({ version: "99" }));
    expect(missing.status).toBe(404);
    expect(await prisma.auditLog.count({ where: { action: { in: ["config.publish", "config.rollback"] } } })).toBe(3);
  });

  it("blocklist versions: create validates, DRAFT not served, activate archives previous", async () => {
    await seedPublishable();
    const admin = await makeUser("ADMIN");
    const bad = await blocklists.POST(
      req("POST", "/api/admin/blocklists", { who: admin, body: { name: "x", license: "y", rulesText: '[{"action":"block","urlFilter":"a|b"}]' } }),
      ctx(),
    );
    expect(bad.status).toBe(400);
    const ok = await blocklists.POST(
      req("POST", "/api/admin/blocklists", {
        who: admin,
        body: { name: "Next", license: "Original work by project owner", rulesText: '[{"action":"block","urlFilter":"^https?://([^/]+\\\\.)?ads\\\\.example\\\\.com[/:]"}]' },
      }),
      ctx(),
    );
    expect(ok.status).toBe(201);
    expect((await ok.json()).item).toMatchObject({ version: 2, status: "DRAFT", ruleCount: 1 });
    expect((await blocklistGet(new Request("http://admin.test/api/v1/blocklists/2"), ctx({ version: "2" }))).status).toBe(404);
    expect((await activate.POST(req("POST", "/api/admin/blocklists/2/activate", { who: admin }), ctx({ version: "2" }))).status).toBe(200);
    const lists = await prisma.blockList.findMany({ orderBy: { version: "asc" } });
    expect(lists.map((l) => l.status)).toEqual(["ARCHIVED", "ACTIVE"]);
    // Archived lists that were active stay downloadable for older configs.
    expect((await blocklistGet(new Request("http://admin.test/api/v1/blocklists/1"), ctx({ version: "1" }))).status).toBe(200);
    expect((await blocklistGet(new Request("http://admin.test/api/v1/blocklists/abc"), ctx({ version: "abc" }))).status).toBe(404);
  });
});
