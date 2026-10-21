import { Prisma } from "@prisma/client";
import { adminRoute } from "@/lib/admin-route";
import { prisma } from "@/lib/db";
import { audit } from "@/lib/audit";
import { blocklistCreateInput } from "@/lib/admin-schemas";
import { buildBlocklistBody, parseRulesText } from "@/lib/blocklist";
import { HttpError, json, readJson } from "@/lib/http";
import { listBlocklists } from "@/lib/queries";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export const GET = adminRoute("READONLY", async () => json({ items: await listBlocklists() }));

/** Create a new DRAFT version from pasted JSON rules. Version = max + 1. */
export const POST = adminRoute("ADMIN", async ({ req, user, ip }) => {
  const input = await readJson(req, blocklistCreateInput, 1024 * 1024 + 8 * 1024);
  const parsed = parseRulesText(input.rulesText);
  if (!parsed.ok) throw new HttpError(400, "invalid_blocklist", "Blocklist is invalid", parsed.errors);
  for (let attempt = 0; ; attempt++) {
    const agg = await prisma.blockList.aggregate({ _max: { version: true } });
    const version = (agg._max.version ?? 0) + 1;
    const built = buildBlocklistBody({ version, name: input.name, license: input.license, rules: parsed.rules });
    if (!built.ok) throw new HttpError(400, "invalid_blocklist", "Blocklist is invalid", built.errors);
    try {
      const created = await prisma.blockList.create({
        data: {
          version,
          name: input.name,
          license: input.license,
          body: built.body,
          sha256: built.sha256,
          ruleCount: built.ruleCount,
          status: "DRAFT",
          createdById: user.id,
        },
        select: { id: true, version: true, sha256: true, ruleCount: true, status: true },
      });
      await audit({ actorId: user.id, action: "blocklist.create", entity: "BlockList", entityId: String(version), after: created, ip });
      return json({ item: created }, 201);
    } catch (e) {
      if (!(e instanceof Prisma.PrismaClientKnownRequestError && e.code === "P2002") || attempt >= 3) throw e;
    }
  }
});
