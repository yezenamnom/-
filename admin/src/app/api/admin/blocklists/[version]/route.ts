import { adminRoute } from "@/lib/admin-route";
import { prisma } from "@/lib/db";
import { HttpError, json } from "@/lib/http";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export const GET = adminRoute<{ version: string }>("READONLY", async ({ params }) => {
  if (!/^[1-9]\d{0,8}$/.test(params.version)) throw new HttpError(404, "not_found");
  const list = await prisma.blockList.findUnique({ where: { version: Number(params.version) } });
  if (!list) throw new HttpError(404, "not_found");
  return json({
    item: {
      version: list.version,
      name: list.name,
      license: list.license,
      status: list.status,
      sha256: list.sha256,
      ruleCount: list.ruleCount,
      createdAt: list.createdAt.toISOString(),
      activatedAt: list.activatedAt?.toISOString() ?? null,
      body: list.body,
    },
  });
});
