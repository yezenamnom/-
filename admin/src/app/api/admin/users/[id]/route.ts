import { adminRoute } from "@/lib/admin-route";
import { prisma } from "@/lib/db";
import { audit } from "@/lib/audit";
import { userUpdateInput } from "@/lib/admin-schemas";
import { hashPassword } from "@/lib/auth/password";
import { HttpError, json, readJson } from "@/lib/http";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

const pub = { id: true, email: true, role: true, disabled: true, lockedUntil: true } as const;

export const PATCH = adminRoute<{ id: string }>("OWNER", async ({ req, user, session, ip, params }) => {
  const input = await readJson(req, userUpdateInput, 4 * 1024);
  const before = await prisma.adminUser.findUnique({ where: { id: params.id }, select: pub });
  if (!before) throw new HttpError(404, "not_found");

  const losesOwner = before.role === "OWNER" && !before.disabled && ((input.role && input.role !== "OWNER") || input.disabled === true);
  if (losesOwner) {
    const owners = await prisma.adminUser.count({ where: { role: "OWNER", disabled: false } });
    if (owners <= 1) throw new HttpError(409, "last_owner", "Cannot demote or disable the last active OWNER");
  }
  if (params.id === user.id && input.disabled === true) throw new HttpError(409, "self_disable", "You cannot disable yourself");

  const data: Record<string, unknown> = {};
  if (input.role) data.role = input.role;
  if (input.disabled !== undefined) data.disabled = input.disabled;
  if (input.password) data.passwordHash = await hashPassword(input.password);
  if (input.unlock || input.password) Object.assign(data, { lockedUntil: null, failedLoginCount: 0 });

  const after = await prisma.$transaction(async (tx) => {
    const u = await tx.adminUser.update({ where: { id: params.id }, data, select: pub });
    // Any change to role/status/password revokes that user's sessions (the acting owner keeps the current one).
    if (input.disabled || input.password || input.role) {
      await tx.session.deleteMany({ where: { userId: params.id, id: { not: session.id } } });
    }
    return u;
  });
  await audit({
    actorId: user.id,
    action: "user.update",
    entity: "AdminUser",
    entityId: params.id,
    before,
    after: { ...after, passwordChanged: !!input.password },
    ip,
  });
  return json({ item: after });
});
