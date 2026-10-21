import { beforeEach, describe, expect, it } from "vitest";
import { prisma } from "@/lib/db";
import * as shortcuts from "@/app/api/admin/shortcuts/route";
import * as shortcutById from "@/app/api/admin/shortcuts/[id]/route";
import * as ads from "@/app/api/admin/ads/route";
import * as publish from "@/app/api/admin/publish/route";
import * as users from "@/app/api/admin/users/route";
import * as userById from "@/app/api/admin/users/[id]/route";
import * as content from "@/app/api/admin/content/route";
import * as blocklists from "@/app/api/admin/blocklists/route";
import * as audit from "@/app/api/admin/audit/route";
import { ctx, makeUser, req, resetDb } from "./helpers";

beforeEach(resetDb);

const newShortcut = {
  key: "vimeo",
  titles: { en: "Vimeo", ar: "", de: "Vimeo" },
  url: "https://vimeo.com/",
  iconKey: "vimeo",
  iconAssetId: null,
  color: "#1AB7EA",
  enabled: true,
};

describe("authentication", () => {
  it("returns 401 for unauthenticated GET and POST", async () => {
    expect((await shortcuts.GET(req("GET", "/api/admin/shortcuts"), ctx())).status).toBe(401);
    expect((await shortcuts.POST(req("POST", "/api/admin/shortcuts", { body: newShortcut }), ctx())).status).toBe(401);
    expect((await users.GET(req("GET", "/api/admin/users"), ctx())).status).toBe(401);
    expect((await shortcuts.GET(req("GET", "/api/admin/shortcuts", { headers: { cookie: "vela_admin=forged-token-value-1234567890" } }), ctx())).status).toBe(401);
  });
});

describe("CSRF + Origin", () => {
  it("rejects missing or invalid CSRF token with 403", async () => {
    const who = await makeUser("ADMIN");
    const missing = await shortcuts.POST(req("POST", "/api/admin/shortcuts", { who, body: newShortcut, csrf: null }), ctx());
    expect(missing.status).toBe(403);
    expect((await missing.json()).error).toBe("csrf_failed");
    const wrong = await shortcuts.POST(req("POST", "/api/admin/shortcuts", { who, body: newShortcut, csrf: "x".repeat(43) }), ctx());
    expect(wrong.status).toBe(403);
    // Another user's token is not valid for this session.
    const other = await makeUser("ADMIN");
    expect((await shortcuts.POST(req("POST", "/api/admin/shortcuts", { who, body: newShortcut, csrf: other.csrf }), ctx())).status).toBe(403);
    expect(await prisma.shortcut.count()).toBe(0);
  });

  it("rejects missing or foreign Origin with 403", async () => {
    const who = await makeUser("ADMIN");
    expect((await shortcuts.POST(req("POST", "/api/admin/shortcuts", { who, body: newShortcut, origin: null }), ctx())).status).toBe(403);
    expect((await shortcuts.POST(req("POST", "/api/admin/shortcuts", { who, body: newShortcut, origin: "https://evil.example" }), ctx())).status).toBe(403);
    expect((await shortcuts.POST(req("POST", "/api/admin/shortcuts", { who, body: newShortcut }), ctx())).status).toBe(201);
  });
});

describe("roles", () => {
  it("READONLY can read but cannot mutate anything", async () => {
    const ro = await makeUser("READONLY");
    expect((await shortcuts.GET(req("GET", "/api/admin/shortcuts", { who: ro }), ctx())).status).toBe(200);
    expect((await audit.GET(req("GET", "/api/admin/audit", { who: ro }), ctx())).status).toBe(200);
    expect((await shortcuts.POST(req("POST", "/api/admin/shortcuts", { who: ro, body: newShortcut }), ctx())).status).toBe(403);
    expect((await ads.PUT(req("PUT", "/api/admin/ads", { who: ro, body: {} }), ctx())).status).toBe(403);
    expect((await publish.POST(req("POST", "/api/admin/publish", { who: ro, body: { note: "" } }), ctx())).status).toBe(403);
    expect((await content.PUT(req("PUT", "/api/admin/content", { who: ro, body: {} }), ctx())).status).toBe(403);
    expect((await blocklists.POST(req("POST", "/api/admin/blocklists", { who: ro, body: {} }), ctx())).status).toBe(403);
    const s = await prisma.shortcut.create({ data: { key: "x", titles: { en: "X" }, url: "https://x.com/", color: "#000000" } });
    expect((await shortcutById.DELETE(req("DELETE", `/api/admin/shortcuts/${s.id}`, { who: ro }), ctx({ id: s.id }))).status).toBe(403);
    expect(await prisma.shortcut.count()).toBe(1);
  });

  it("ADMIN can edit but cannot manage users", async () => {
    const admin = await makeUser("ADMIN");
    expect((await shortcuts.POST(req("POST", "/api/admin/shortcuts", { who: admin, body: newShortcut }), ctx())).status).toBe(201);
    expect((await users.GET(req("GET", "/api/admin/users", { who: admin }), ctx())).status).toBe(403);
    expect(
      (await users.POST(req("POST", "/api/admin/users", { who: admin, body: { email: "n@test.dev", role: "OWNER", password: "a-long-password-1" } }), ctx())).status,
    ).toBe(403);
    expect((await userById.PATCH(req("PATCH", `/api/admin/users/${admin.user.id}`, { who: admin, body: { role: "OWNER" } }), ctx({ id: admin.user.id }))).status).toBe(403);
    expect((await prisma.adminUser.findUniqueOrThrow({ where: { id: admin.user.id } })).role).toBe("ADMIN");
  });

  it("OWNER manages users; cannot remove the last owner; disabling revokes sessions", async () => {
    const owner = await makeUser("OWNER");
    const created = await users.POST(req("POST", "/api/admin/users", { who: owner, body: { email: "new@test.dev", role: "READONLY", password: "a-long-password-1" } }), ctx());
    expect(created.status).toBe(201);
    const id = (await created.json()).item.id as string;
    expect((await userById.PATCH(req("PATCH", `/api/admin/users/${id}`, { who: owner, body: { role: "ADMIN" } }), ctx({ id }))).status).toBe(200);
    const target = await makeUser("ADMIN");
    const dis = await userById.PATCH(req("PATCH", `/api/admin/users/${target.user.id}`, { who: owner, body: { disabled: true } }), ctx({ id: target.user.id }));
    expect(dis.status).toBe(200);
    expect(await prisma.session.count({ where: { userId: target.user.id } })).toBe(0);
    expect((await shortcuts.GET(req("GET", "/api/admin/shortcuts", { who: target }), ctx())).status).toBe(401);
    const demoteSelf = await userById.PATCH(req("PATCH", `/api/admin/users/${owner.user.id}`, { who: owner, body: { role: "ADMIN" } }), ctx({ id: owner.user.id }));
    expect(demoteSelf.status).toBe(409);
    const weak = await users.POST(req("POST", "/api/admin/users", { who: owner, body: { email: "w@test.dev", role: "ADMIN", password: "short" } }), ctx());
    expect(weak.status).toBe(400);
  });

  it("every mutation is audited", async () => {
    const admin = await makeUser("ADMIN");
    await shortcuts.POST(req("POST", "/api/admin/shortcuts", { who: admin, body: newShortcut }), ctx());
    const log = await prisma.auditLog.findFirstOrThrow({ where: { action: "shortcut.create" } });
    expect(log.actorId).toBe(admin.user.id);
    expect(log.after).toMatchObject({ key: "vimeo" });
  });
});

describe("input validation", () => {
  it("rejects invalid shortcut input (http, private host, bad icon key)", async () => {
    const admin = await makeUser("ADMIN");
    for (const patch of [{ url: "http://vimeo.com/" }, { url: "https://192.168.1.1/" }, { iconKey: "evil" }, { titles: { en: "" } }, { key: "Bad Key" }]) {
      const r = await shortcuts.POST(req("POST", "/api/admin/shortcuts", { who: admin, body: { ...newShortcut, ...patch } }), ctx());
      expect(r.status, JSON.stringify(patch)).toBe(400);
    }
  });

  it("rejects ad frequency outside the safe caps and bad unit ids", async () => {
    const admin = await makeUser("ADMIN");
    const base = { globalEnabled: true, frequency: { interstitialMinIntervalSec: 600, interstitialMaxPerSession: 1 }, placements: [] };
    expect((await ads.PUT(req("PUT", "/api/admin/ads", { who: admin, body: base }), ctx())).status).toBe(200);
    expect((await ads.PUT(req("PUT", "/api/admin/ads", { who: admin, body: { ...base, frequency: { interstitialMinIntervalSec: 120, interstitialMaxPerSession: 1 } } }), ctx())).status).toBe(400);
    expect((await ads.PUT(req("PUT", "/api/admin/ads", { who: admin, body: { ...base, frequency: { interstitialMinIntervalSec: 600, interstitialMaxPerSession: 5 } } }), ctx())).status).toBe(400);
    const badId = { ...base, placements: [{ key: "home_banner", enabled: true, adUnitIdAndroid: "ca-app-pub-1/2", adUnitIdIos: "" }] };
    expect((await ads.PUT(req("PUT", "/api/admin/ads", { who: admin, body: badId }), ctx())).status).toBe(400);
  });
});
