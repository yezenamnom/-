import { beforeEach, describe, expect, it } from "vitest";
import { prisma } from "@/lib/db";
import { hashPassword, verifyPassword } from "@/lib/auth/password";
import { attemptLogin } from "@/lib/auth/login";
import { createSession, SESSION_IDLE_MS, validateSessionToken } from "@/lib/auth/session";
import { sha256HexOf } from "@/lib/auth/tokens";
import { POST as loginRoute } from "@/app/api/admin/auth/login/route";
import { POST as logoutRoute } from "@/app/api/admin/auth/logout/route";
import { GET as meRoute } from "@/app/api/admin/auth/me/route";
import { ctx, makeUser, req, resetDb, TEST_PASSWORD } from "./helpers";

beforeEach(resetDb);

describe("passwords", () => {
  it("uses argon2id and verifies", async () => {
    const h = await hashPassword("a-long-enough-password");
    expect(h.startsWith("$argon2id$")).toBe(true);
    expect(await verifyPassword(h, "a-long-enough-password")).toBe(true);
    expect(await verifyPassword(h, "wrong")).toBe(false);
    expect(await verifyPassword("garbage", "x")).toBe(false);
  });
});

describe("login", () => {
  it("succeeds, rotates the session, stores only a token hash, sets a strict HttpOnly cookie", async () => {
    const { user, token: oldToken } = await makeUser("ADMIN", "a@test.dev");
    const res = await loginRoute(
      req("POST", "/api/admin/auth/login", { body: { email: "A@test.dev", password: TEST_PASSWORD }, headers: { cookie: `vela_admin=${oldToken}` } }),
    );
    expect(res.status).toBe(200);
    const setCookie = res.headers.get("set-cookie") ?? "";
    expect(setCookie).toMatch(/vela_admin=/);
    expect(setCookie).toMatch(/HttpOnly/i);
    expect(setCookie).toMatch(/SameSite=Strict/i);
    const newToken = /vela_admin=([^;]+)/.exec(setCookie)![1]!;
    expect(newToken).not.toBe(oldToken);
    expect(await validateSessionToken(oldToken)).toBeNull(); // rotated
    const sessions = await prisma.session.findMany({ where: { userId: user.id } });
    expect(sessions).toHaveLength(1);
    expect(sessions[0]!.tokenHash).toBe(sha256HexOf(newToken));
    expect(JSON.stringify(sessions)).not.toContain(newToken);
  });

  it("sets Secure cookie in production", async () => {
    await makeUser("ADMIN", "p@test.dev");
    process.env.APP_ENV = "production";
    try {
      const res = await loginRoute(req("POST", "/api/admin/auth/login", { body: { email: "p@test.dev", password: TEST_PASSWORD } }));
      expect(res.headers.get("set-cookie")).toMatch(/Secure/);
    } finally {
      process.env.APP_ENV = "development";
    }
  });

  it("returns the same generic error for unknown user and wrong password", async () => {
    await makeUser("ADMIN", "b@test.dev");
    const r1 = await loginRoute(req("POST", "/api/admin/auth/login", { body: { email: "b@test.dev", password: "nope" } }));
    const r2 = await loginRoute(req("POST", "/api/admin/auth/login", { body: { email: "nobody@test.dev", password: "nope" } }));
    expect(r1.status).toBe(401);
    expect(r2.status).toBe(401);
    expect(await r1.json()).toEqual(await r2.json());
  });

  it("rejects cross-origin login", async () => {
    const r = await loginRoute(req("POST", "/api/admin/auth/login", { body: { email: "x@test.dev", password: "x" }, origin: "https://evil.example" }));
    expect(r.status).toBe(403);
  });

  it("locks the account for 15 minutes after 5 failures (even from different IPs)", async () => {
    const { user } = await makeUser("ADMIN", "c@test.dev");
    const now = new Date();
    for (let i = 0; i < 5; i++) {
      const r = await attemptLogin({ email: "c@test.dev", password: "bad", ip: `203.0.113.${i}`, userAgent: null, now });
      expect(r.ok).toBe(false);
    }
    const locked = await prisma.adminUser.findUniqueOrThrow({ where: { id: user.id } });
    expect(locked.lockedUntil!.getTime()).toBe(now.getTime() + 15 * 60 * 1000);
    // Correct password is refused while locked, with the generic 401.
    const during = await attemptLogin({ email: "c@test.dev", password: TEST_PASSWORD, ip: "198.51.100.9", userAgent: null, now: new Date(now.getTime() + 60_000) });
    expect(during).toEqual({ ok: false, status: 401 });
    const after = await attemptLogin({ email: "c@test.dev", password: TEST_PASSWORD, ip: "198.51.100.9", userAgent: null, now: new Date(now.getTime() + 16 * 60_000) });
    expect(after.ok).toBe(true);
    expect(await prisma.auditLog.count({ where: { action: "auth.lockout" } })).toBe(1);
  });

  it("rate-limits per ip+email (429) after 5 failures", async () => {
    for (let i = 0; i < 5; i++) await attemptLogin({ email: "ghost@test.dev", password: "bad", ip: "203.0.113.7", userAgent: null });
    const r = await attemptLogin({ email: "ghost@test.dev", password: "bad", ip: "203.0.113.7", userAgent: null });
    expect(r).toEqual({ ok: false, status: 429 });
    const other = await attemptLogin({ email: "ghost@test.dev", password: "bad", ip: "203.0.113.8", userAgent: null });
    expect(other).toEqual({ ok: false, status: 401 });
  });

  it("refuses disabled users", async () => {
    const { user } = await makeUser("ADMIN", "d@test.dev");
    await prisma.adminUser.update({ where: { id: user.id }, data: { disabled: true } });
    expect((await attemptLogin({ email: "d@test.dev", password: TEST_PASSWORD, ip: "1.1.1.1", userAgent: null })).ok).toBe(false);
  });
});

describe("sessions", () => {
  it("expire after 12h idle and after 7d absolute; are deleted", async () => {
    const { user } = await makeUser("ADMIN");
    const t0 = new Date();
    const { token } = await createSession(user.id, null, t0);
    expect(await validateSessionToken(token, new Date(t0.getTime() + SESSION_IDLE_MS - 1000))).not.toBeNull();
    expect(await validateSessionToken(token, new Date(t0.getTime() + 2 * SESSION_IDLE_MS + 1000))).toBeNull();
    expect(await prisma.session.count({ where: { tokenHash: sha256HexOf(token) } })).toBe(0);

    const { token: t2 } = await createSession(user.id, null, t0);
    // Keep it active every 6h up to 7 days: absolute expiry still applies.
    let alive = true;
    for (let h = 6; h <= 7 * 24 + 6 && alive; h += 6) {
      alive = (await validateSessionToken(t2, new Date(t0.getTime() + h * 3600_000))) !== null;
      if (alive) expect(h).toBeLessThan(7 * 24);
    }
    expect(alive).toBe(false);
  });

  it("logout destroys the session and clears the cookie", async () => {
    const who = await makeUser("READONLY");
    const res = await logoutRoute(req("POST", "/api/admin/auth/logout", { who }), ctx());
    expect(res.status).toBe(200);
    expect(res.headers.get("set-cookie")).toMatch(/vela_admin=;/);
    expect((await meRoute(req("GET", "/api/admin/auth/me", { who }), ctx())).status).toBe(401);
  });
});
