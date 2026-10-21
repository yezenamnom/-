import { adminRoute } from "@/lib/admin-route";
import { prisma } from "@/lib/db";
import { audit } from "@/lib/audit";
import { noticeInput } from "@/lib/admin-schemas";
import { HttpError, json, readJson } from "@/lib/http";
import { listNotices } from "@/lib/queries";
import { LIMITS } from "@/lib/config-schema";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export const GET = adminRoute("READONLY", async () => json({ items: await listNotices() }));

export const POST = adminRoute("ADMIN", async ({ req, user, ip }) => {
  const input = await readJson(req, noticeInput);
  if (input.active && (await prisma.notice.count({ where: { active: true } })) >= LIMITS.maxNotices) {
    throw new HttpError(400, "validation_failed", `At most ${LIMITS.maxNotices} active notices`);
  }
  const created = await prisma.notice.create({ data: input });
  await audit({ actorId: user.id, action: "notice.create", entity: "Notice", entityId: created.id, after: created, ip });
  return json({ item: created }, 201);
});
