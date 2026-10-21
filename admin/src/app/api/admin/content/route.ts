import { adminRoute } from "@/lib/admin-route";
import { prisma } from "@/lib/db";
import { audit } from "@/lib/audit";
import { contentInput } from "@/lib/admin-schemas";
import { json, readJson } from "@/lib/http";
import { getContent } from "@/lib/queries";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export const GET = adminRoute("READONLY", async () => json(await getContent()));

export const PUT = adminRoute("ADMIN", async ({ req, user, ip }) => {
  const input = await readJson(req, contentInput);
  const before = await getContent();
  await prisma.contentSettings.upsert({ where: { id: 1 }, create: { id: 1, ...input }, update: input });
  const after = await getContent();
  await audit({ actorId: user.id, action: "content.update", entity: "ContentSettings", entityId: "1", before, after, ip });
  return json(after);
});
