import { prisma } from "../db";
import { audit } from "../audit";
import { verifyAgainstDummy, verifyPassword } from "./password";
import { createSession, destroySessionToken } from "./session";

export const LOGIN_MAX_FAILURES = 5;
export const LOGIN_WINDOW_MS = 15 * 60 * 1000;
export const LOCK_MS = 15 * 60 * 1000;
const ATTEMPT_RETENTION_MS = 30 * 24 * 60 * 60 * 1000;

/** Generic messages only — never reveal whether an account exists, is disabled or is locked. */
export const LOGIN_FAILED_MESSAGE = "Sign-in failed. Check your email and password, or try again later.";
export const LOGIN_RATE_LIMITED_MESSAGE = "Too many attempts. Try again later.";

export type LoginResult =
  | { ok: true; token: string; expiresAt: Date; csrfToken: string }
  | { ok: false; status: 401 | 429 };

export async function attemptLogin(input: {
  email: string;
  password: string;
  ip: string;
  userAgent: string | null;
  previousToken?: string;
  now?: Date;
}): Promise<LoginResult> {
  const now = input.now ?? new Date();
  const email = input.email.trim().toLowerCase();

  // Opportunistic purge of old attempts.
  await prisma.loginAttempt.deleteMany({ where: { at: { lt: new Date(now.getTime() - ATTEMPT_RETENTION_MS) } } });

  // Per ip+email limit (applies to unknown emails too, so it leaks nothing).
  const recentFailures = await prisma.loginAttempt.count({
    where: { ip: input.ip, email, success: false, at: { gt: new Date(now.getTime() - LOGIN_WINDOW_MS) } },
  });
  if (recentFailures >= LOGIN_MAX_FAILURES) {
    await prisma.loginAttempt.create({ data: { ip: input.ip, email, success: false, at: now } });
    return { ok: false, status: 429 };
  }

  const user = await prisma.adminUser.findUnique({ where: { email } });
  const locked = !!user?.lockedUntil && user.lockedUntil.getTime() > now.getTime();
  const passwordOk =
    user && !user.disabled && !locked ? await verifyPassword(user.passwordHash, input.password) : await verifyAgainstDummy(input.password);

  if (!user || !passwordOk) {
    await prisma.loginAttempt.create({ data: { ip: input.ip, email, success: false, at: now } });
    if (user && !locked) {
      const failed = user.failedLoginCount + 1;
      const lockNow = failed >= LOGIN_MAX_FAILURES;
      await prisma.adminUser.update({
        where: { id: user.id },
        data: lockNow
          ? { failedLoginCount: 0, lockedUntil: new Date(now.getTime() + LOCK_MS) }
          : { failedLoginCount: failed },
      });
      await audit({
        actorId: null,
        action: lockNow ? "auth.lockout" : "auth.login_failed",
        entity: "AdminUser",
        entityId: user.id,
        ip: input.ip,
      });
    }
    return { ok: false, status: 401 };
  }

  await prisma.adminUser.update({
    where: { id: user.id },
    data: { failedLoginCount: 0, lockedUntil: null, lastLoginAt: now },
  });
  await prisma.loginAttempt.create({ data: { ip: input.ip, email, success: true, at: now } });
  // Session rotation: any session presented with this request is destroyed; a fresh token is issued.
  await destroySessionToken(input.previousToken);
  const { token, session } = await createSession(user.id, input.userAgent, now);
  await audit({ actorId: user.id, action: "auth.login", entity: "AdminUser", entityId: user.id, ip: input.ip });
  return { ok: true, token, expiresAt: session.expiresAt, csrfToken: session.csrfToken };
}
