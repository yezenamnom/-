import { beforeEach, describe, expect, it } from "vitest";
import { prisma } from "@/lib/db";
import { POST } from "@/app/api/v1/reports/route";
import * as adminReports from "@/app/api/admin/reports/route";
import * as reportById from "@/app/api/admin/reports/[id]/route";
import { ctx, makeUser, req, resetDb } from "./helpers";

beforeEach(resetDb);

const good = { category: "site_broken", message: "Video does not play", appVersion: "1.0.0", platform: "android", locale: "ar", siteHost: "Example.com" };

function post(body: unknown, ip = "203.0.113.10") {
  return POST(
    new Request("http://admin.test/api/v1/reports", {
      method: "POST",
      headers: { "content-type": "application/json", "x-forwarded-for": ip },
      body: JSON.stringify(body),
    }),
  );
}

describe("POST /api/v1/reports", () => {
  it("creates a report (201) and stores a lower-cased host", async () => {
    const r = await post(good);
    expect(r.status).toBe(201);
    const { id } = await r.json();
    const row = await prisma.userReport.findUniqueOrThrow({ where: { id } });
    expect(row.siteHost).toBe("example.com");
    expect(row.status).toBe("NEW");
  });

  it("validates input strictly", async () => {
    const cases: unknown[] = [
      { ...good, siteHost: "https://example.com" },
      { ...good, siteHost: "example.com/path" },
      { ...good, siteHost: "example.com?q=1" },
      { ...good, siteHost: "example.com:8080" },
      { ...good, category: "spam" },
      { ...good, platform: "windows" },
      { ...good, message: "" },
      { ...good, message: "x".repeat(2001) },
      { ...good, url: "https://example.com/secret" },
      { ...good, appVersion: "latest" },
    ];
    for (const c of cases) expect((await post(c)).status, JSON.stringify(c)).toBe(400);
    const { siteHost: _omit, ...noHost } = good;
    expect((await post(noHost)).status).toBe(201);
    const bad = await POST(new Request("http://admin.test/api/v1/reports", { method: "POST", headers: { "content-type": "application/json" }, body: "{not json" }));
    expect(bad.status).toBe(400);
  });

  it("rate-limits to 5/hour per IP using a salted hash (no raw IP stored)", async () => {
    for (let i = 0; i < 5; i++) expect((await post(good, "198.51.100.1")).status).toBe(201);
    const limited = await post(good, "198.51.100.1");
    expect(limited.status).toBe(429);
    expect((await post(good, "198.51.100.2")).status).toBe(201);
    const rows = await prisma.reportRateLimit.findMany();
    expect(JSON.stringify(rows)).not.toContain("198.51.100");
    expect(rows.every((r) => /^[a-f0-9]{64}$/.test(r.ipHash))).toBe(true);
  });

  it("purges rate-limit rows older than 24h", async () => {
    await prisma.reportRateLimit.create({ data: { ipHash: "f".repeat(64), windowStart: new Date(Date.now() - 25 * 3600_000), count: 5 } });
    await post(good);
    expect(await prisma.reportRateLimit.count({ where: { ipHash: "f".repeat(64) } })).toBe(0);
  });

  it("admins list and triage reports; READONLY cannot change status", async () => {
    const { id } = await (await post(good)).json();
    const ro = await makeUser("READONLY");
    const admin = await makeUser("ADMIN");
    const list = await adminReports.GET(req("GET", "/api/admin/reports?status=NEW", { who: ro }), ctx());
    expect((await list.json()).total).toBe(1);
    expect((await reportById.PATCH(req("PATCH", `/api/admin/reports/${id}`, { who: ro, body: { status: "CLOSED" } }), ctx({ id }))).status).toBe(403);
    expect((await reportById.PATCH(req("PATCH", `/api/admin/reports/${id}`, { who: admin, body: { status: "CLOSED" } }), ctx({ id }))).status).toBe(200);
    expect((await prisma.userReport.findUniqueOrThrow({ where: { id } })).status).toBe("CLOSED");
  });
});
