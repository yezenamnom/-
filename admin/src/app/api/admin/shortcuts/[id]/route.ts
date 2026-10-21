import { adminRoute } from "@/lib/admin-route";
import { prisma } from "@/lib/db";
import { audit } from "@/lib/audit";
import { shortcutInput } from "@/lib/admin-schemas";
import { HttpError, json, readJson } from "@/lib/http";
import { LIMITS } from "@/lib/config-schema";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export const PUT = adminRoute<{ id: string }>("ADMIN", async ({ req, user, ip, params }) => {
  const before = await prisma.shortcut.findUnique({ where: { id: params.id } });
  if (!before) throw new HttpError(404, "not_found");
  const input = await readJson(req, shortcutInput);
  if (input.iconAssetId && !(await prisma.asset.findUnique({ where: { id: input.iconAssetId }, select: { id: true } }))) {
    throw new HttpError(400, "validation_failed", "Unknown icon asset");
  }
  if (input.enabled && !before.enabled && (await prisma.shortcut.count({ where: { enabled: true } })) >= LIMITS.maxShortcuts) {
    throw new HttpError(400, "validation_failed", `At most ${LIMITS.maxShortcuts} enabled shortcuts`);
  }
  const after = await prisma.shortcut.update({ where: { id: params.id }, data: input });
  await audit({ actorId: user.id, action: "shortcut.update", entity: "Shortcut", entityId: after.id, before, after, ip });
  return json({ item: after });
});

export const DELETE = adminRoute<{ id: string }>("ADMIN", async ({ user, ip, params }) => {
  const before = await prisma.shortcut.findUnique({ where: { id: params.id } });
  if (!before) throw new HttpError(404, "not_found");
  await prisma.shortcut.delete({ where: { id: params.id } });
  await audit({ actorId: user.id, action: "shortcut.delete", entity: "Shortcut", entityId: before.id, before, ip });
  return json({ ok: true });
});
