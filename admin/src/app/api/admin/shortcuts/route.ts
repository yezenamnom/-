import { adminRoute } from "@/lib/admin-route";
import { prisma } from "@/lib/db";
import { audit } from "@/lib/audit";
import { shortcutInput } from "@/lib/admin-schemas";
import { HttpError, json, readJson } from "@/lib/http";
import { listShortcuts } from "@/lib/queries";
import { LIMITS } from "@/lib/config-schema";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export const GET = adminRoute("READONLY", async () => json({ items: await listShortcuts() }));

export const POST = adminRoute("ADMIN", async ({ req, user, ip }) => {
  const input = await readJson(req, shortcutInput);
  if (input.iconAssetId && !(await prisma.asset.findUnique({ where: { id: input.iconAssetId }, select: { id: true } }))) {
    throw new HttpError(400, "validation_failed", "Unknown icon asset");
  }
  if (input.enabled && (await prisma.shortcut.count({ where: { enabled: true } })) >= LIMITS.maxShortcuts) {
    throw new HttpError(400, "validation_failed", `At most ${LIMITS.maxShortcuts} enabled shortcuts`);
  }
  const max = await prisma.shortcut.aggregate({ _max: { order: true } });
  const created = await prisma.shortcut.create({
    data: { ...input, order: (max._max.order ?? -1) + 1 },
  });
  await audit({ actorId: user.id, action: "shortcut.create", entity: "Shortcut", entityId: created.id, after: created, ip });
  return json({ item: created }, 201);
});
