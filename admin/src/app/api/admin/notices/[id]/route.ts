import { adminRoute } from "@/lib/admin-route";
import { prisma } from "@/lib/db";
import { audit } from "@/lib/audit";
import { noticeInput } from "@/lib/admin-schemas";
import { HttpError, json, readJson } from "@/lib/http";
import { LIMITS } from "@/lib/config-schema";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export const PUT = adminRoute<{ id: string }>("ADMIN", async ({ req, user, ip, params }) => {
  const before = await prisma.notice.findUnique({ where: { id: params.id } });
  if (!before) throw new HttpError(404, "not_found");
  const input = await readJson(req, noticeInput);
  if (input.active && !before.active && (await prisma.notice.count({ where: { active: true } })) >= LIMITS.maxNotices) {
    throw new HttpError(400, "validation_failed", `At most ${LIMITS.maxNotices} active notices`);
  }
  const after = await prisma.notice.update({ where: { id: params.id }, data: input });
  await audit({ actorId: user.id, action: "notice.update", entity: "Notice", entityId: after.id, before, after, ip });
  return json({ item: after });
});

export const DELETE = adminRoute<{ id: string }>("ADMIN", async ({ user, ip, params }) => {
  const before = await prisma.notice.findUnique({ where: { id: params.id } });
  if (!before) throw new HttpError(404, "not_found");
  await prisma.notice.delete({ where: { id: params.id } });
  await audit({ actorId: user.id, action: "notice.delete", entity: "Notice", entityId: before.id, before, ip });
  return json({ ok: true });
});
