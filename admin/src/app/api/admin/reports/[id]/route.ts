import { adminRoute } from "@/lib/admin-route";
import { prisma } from "@/lib/db";
import { audit } from "@/lib/audit";
import { reportStatusInput } from "@/lib/admin-schemas";
import { HttpError, json, readJson } from "@/lib/http";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export const PATCH = adminRoute<{ id: string }>("ADMIN", async ({ req, user, ip, params }) => {
  const { status } = await readJson(req, reportStatusInput);
  const before = await prisma.userReport.findUnique({ where: { id: params.id }, select: { id: true, status: true } });
  if (!before) throw new HttpError(404, "not_found");
  const after = await prisma.userReport.update({ where: { id: params.id }, data: { status }, select: { id: true, status: true } });
  await audit({ actorId: user.id, action: "report.status", entity: "UserReport", entityId: params.id, before, after, ip });
  return json({ item: after });
});
