import { adminRoute } from "@/lib/admin-route";
import { prisma } from "@/lib/db";
import { audit } from "@/lib/audit";
import { reorderInput } from "@/lib/admin-schemas";
import { HttpError, json, readJson } from "@/lib/http";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

/** Body: { ids: [...] } — the complete list of shortcut ids in the desired order. */
export const POST = adminRoute("ADMIN", async ({ req, user, ip }) => {
  const { ids } = await readJson(req, reorderInput);
  const existing = await prisma.shortcut.findMany({ select: { id: true, order: true }, orderBy: { order: "asc" } });
  const known = new Set(existing.map((s) => s.id));
  if (ids.length !== existing.length || new Set(ids).size !== ids.length || !ids.every((id) => known.has(id))) {
    throw new HttpError(400, "validation_failed", "ids must list every shortcut exactly once");
  }
  await prisma.$transaction(ids.map((id, order) => prisma.shortcut.update({ where: { id }, data: { order } })));
  await audit({ actorId: user.id, action: "shortcut.reorder", entity: "Shortcut", before: existing.map((s) => s.id), after: ids, ip });
  return json({ ok: true });
});
