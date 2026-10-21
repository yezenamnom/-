import { adminRoute } from "@/lib/admin-route";
import { prisma } from "@/lib/db";
import { audit } from "@/lib/audit";
import { userCreateInput } from "@/lib/admin-schemas";
import { hashPassword } from "@/lib/auth/password";
import { json, readJson } from "@/lib/http";
import { listUsers } from "@/lib/queries";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export const GET = adminRoute("OWNER", async () => json({ items: await listUsers() }));

export const POST = adminRoute("OWNER", async ({ req, user, ip }) => {
  const input = await readJson(req, userCreateInput, 4 * 1024);
  const created = await prisma.adminUser.create({
    data: { email: input.email, role: input.role, passwordHash: await hashPassword(input.password) },
    select: { id: true, email: true, role: true, disabled: true },
  });
  await audit({ actorId: user.id, action: "user.create", entity: "AdminUser", entityId: created.id, after: created, ip });
  return json({ item: created }, 201);
});
