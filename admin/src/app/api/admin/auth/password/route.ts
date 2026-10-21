import { adminRoute } from "@/lib/admin-route";
import { prisma } from "@/lib/db";
import { audit } from "@/lib/audit";
import { changeOwnPasswordInput } from "@/lib/admin-schemas";
import { hashPassword, verifyPassword } from "@/lib/auth/password";
import { HttpError, json, readJson } from "@/lib/http";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export const POST = adminRoute("READONLY", async ({ req, user, session, ip }) => {
  const input = await readJson(req, changeOwnPasswordInput, 4 * 1024);
  if (!(await verifyPassword(user.passwordHash, input.currentPassword))) {
    throw new HttpError(400, "wrong_password", "Current password is incorrect");
  }
  const passwordHash = await hashPassword(input.newPassword);
  await prisma.$transaction([
    prisma.adminUser.update({ where: { id: user.id }, data: { passwordHash } }),
    // Sign out every other session of this user.
    prisma.session.deleteMany({ where: { userId: user.id, id: { not: session.id } } }),
  ]);
  await audit({ actorId: user.id, action: "auth.password_changed", entity: "AdminUser", entityId: user.id, ip });
  return json({ ok: true });
});
