import { adminRoute } from "@/lib/admin-route";
import { prisma } from "@/lib/db";
import { HttpError, json } from "@/lib/http";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export const GET = adminRoute<{ version: string }>("READONLY", async ({ params }) => {
  if (!/^[1-9]\d{0,8}$/.test(params.version)) throw new HttpError(404, "not_found");
  const r = await prisma.configRelease.findUnique({
    where: { version: Number(params.version) },
    include: { createdBy: { select: { email: true } } },
  });
  if (!r) throw new HttpError(404, "not_found");
  return json({
    item: {
      version: r.version,
      note: r.note,
      createdAt: r.createdAt.toISOString(),
      createdBy: r.createdBy?.email ?? null,
      rolledBackFromVersion: r.rolledBackFromVersion,
      isCurrent: r.isCurrent,
      content: JSON.parse(r.contentJson),
    },
  });
});
