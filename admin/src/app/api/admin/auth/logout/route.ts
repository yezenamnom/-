import { NextResponse } from "next/server";
import { adminRoute } from "@/lib/admin-route";
import { prisma } from "@/lib/db";
import { audit } from "@/lib/audit";
import { SESSION_COOKIE, sessionCookieOptions } from "@/lib/auth/session";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export const POST = adminRoute("READONLY", async ({ session, user, ip }) => {
  await prisma.session.delete({ where: { id: session.id } }).catch(() => undefined);
  await audit({ actorId: user.id, action: "auth.logout", entity: "AdminUser", entityId: user.id, ip });
  const res = NextResponse.json({ ok: true }, { headers: { "Cache-Control": "no-store" } });
  res.cookies.set(SESSION_COOKIE, "", { ...sessionCookieOptions(new Date(0)), maxAge: 0 });
  return res;
});
