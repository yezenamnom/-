import type { AdminUser, Session } from "@prisma/client";
import { prisma } from "../db";
import { isSecureDeployment } from "../env";
import { newToken, sha256HexOf } from "./tokens";

export const SESSION_COOKIE = "vela_admin";
export const SESSION_IDLE_MS = 12 * 60 * 60 * 1000;
export const SESSION_ABSOLUTE_MS = 7 * 24 * 60 * 60 * 1000;
const TOUCH_INTERVAL_MS = 60 * 1000;

export type AuthContext = { session: Session; user: AdminUser };

export async function createSession(userId: string, userAgent: string | null, now = new Date()) {
  const token = newToken(32);
  const csrfToken = newToken(32);
  const expiresAt = new Date(now.getTime() + SESSION_ABSOLUTE_MS);
  const session = await prisma.session.create({
    data: {
      tokenHash: sha256HexOf(token),
      userId,
      csrfToken,
      expiresAt,
      lastSeenAt: now,
      createdAt: now,
      userAgent: userAgent?.slice(0, 300) ?? null,
    },
  });
  return { token, session };
}

export function isSessionExpired(s: Pick<Session, "expiresAt" | "lastSeenAt">, now = new Date()): boolean {
  return now.getTime() >= s.expiresAt.getTime() || now.getTime() - s.lastSeenAt.getTime() >= SESSION_IDLE_MS;
}

/** Resolve a raw cookie token into a live session + enabled user, or null. Expired sessions are deleted. */
export async function validateSessionToken(token: string | undefined | null, now = new Date()): Promise<AuthContext | null> {
  if (!token || token.length < 20 || token.length > 100) return null;
  const session = await prisma.session.findUnique({ where: { tokenHash: sha256HexOf(token) }, include: { user: true } });
  if (!session) return null;
  if (isSessionExpired(session, now) || session.user.disabled) {
    await prisma.session.delete({ where: { id: session.id } }).catch(() => undefined);
    return null;
  }
  if (now.getTime() - session.lastSeenAt.getTime() > TOUCH_INTERVAL_MS) {
    await prisma.session.update({ where: { id: session.id }, data: { lastSeenAt: now } }).catch(() => undefined);
  }
  const { user, ...rest } = session;
  return { session: rest, user };
}

export async function destroySessionToken(token: string | undefined | null): Promise<void> {
  if (!token) return;
  await prisma.session.deleteMany({ where: { tokenHash: sha256HexOf(token) } });
}

export async function purgeExpiredSessions(now = new Date()): Promise<void> {
  await prisma.session.deleteMany({
    where: { OR: [{ expiresAt: { lte: now } }, { lastSeenAt: { lte: new Date(now.getTime() - SESSION_IDLE_MS) } }] },
  });
}

export function sessionCookieOptions(expires: Date) {
  return {
    httpOnly: true,
    sameSite: "strict" as const,
    secure: isSecureDeployment(),
    path: "/",
    expires,
  };
}

export function readCookie(req: Request, name: string): string | undefined {
  const header = req.headers.get("cookie");
  if (!header) return undefined;
  for (const part of header.split(";")) {
    const idx = part.indexOf("=");
    if (idx < 0) continue;
    if (part.slice(0, idx).trim() === name) {
      try {
        return decodeURIComponent(part.slice(idx + 1).trim());
      } catch {
        return undefined;
      }
    }
  }
  return undefined;
}
