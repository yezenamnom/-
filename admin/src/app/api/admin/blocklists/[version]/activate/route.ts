import { adminRoute } from "@/lib/admin-route";
import { prisma } from "@/lib/db";
import { audit } from "@/lib/audit";
import { HttpError, json } from "@/lib/http";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

/** Make this version the ACTIVE list (the previously active one becomes ARCHIVED). Takes effect on next publish. */
export const POST = adminRoute<{ version: string }>("ADMIN", async ({ user, ip, params }) => {
  if (!/^[1-9]\d{0,8}$/.test(params.version)) throw new HttpError(404, "not_found");
  const version = Number(params.version);
  const result = await prisma.$transaction(async (tx) => {
    const target = await tx.blockList.findUnique({ where: { version } });
    if (!target) throw new HttpError(404, "not_found");
    if (target.status === "ACTIVE") return { version, previous: version };
    const prev = await tx.blockList.findFirst({ where: { status: "ACTIVE" } });
    if (prev) await tx.blockList.update({ where: { id: prev.id }, data: { status: "ARCHIVED" } });
    await tx.blockList.update({
      where: { id: target.id },
      data: { status: "ACTIVE", activatedAt: target.activatedAt ?? new Date() },
    });
    return { version, previous: prev?.version ?? null };
  });
  await audit({
    actorId: user.id,
    action: "blocklist.activate",
    entity: "BlockList",
    entityId: String(version),
    before: { activeVersion: result.previous },
    after: { activeVersion: version },
    ip,
  });
  return json({ ok: true, activeVersion: version });
});
