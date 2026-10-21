import { adminRoute } from "@/lib/admin-route";
import { prisma } from "@/lib/db";
import { audit } from "@/lib/audit";
import { HttpError, json } from "@/lib/http";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

/** Archive a DRAFT or ACTIVE version. Archived lists that were once active stay downloadable (old configs reference them). */
export const POST = adminRoute<{ version: string }>("ADMIN", async ({ user, ip, params }) => {
  if (!/^[1-9]\d{0,8}$/.test(params.version)) throw new HttpError(404, "not_found");
  const version = Number(params.version);
  const target = await prisma.blockList.findUnique({ where: { version } });
  if (!target) throw new HttpError(404, "not_found");
  if (target.status === "ARCHIVED") return json({ ok: true });
  await prisma.blockList.update({ where: { id: target.id }, data: { status: "ARCHIVED" } });
  await audit({
    actorId: user.id,
    action: "blocklist.archive",
    entity: "BlockList",
    entityId: String(version),
    before: { status: target.status },
    after: { status: "ARCHIVED" },
    ip,
  });
  return json({ ok: true });
});
