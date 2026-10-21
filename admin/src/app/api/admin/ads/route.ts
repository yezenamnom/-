import { adminRoute } from "@/lib/admin-route";
import { prisma } from "@/lib/db";
import { audit } from "@/lib/audit";
import { adsInput } from "@/lib/admin-schemas";
import { json, readJson } from "@/lib/http";
import { getAds } from "@/lib/queries";
import { PLACEMENT_FORMAT } from "@/lib/config-schema";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export const GET = adminRoute("READONLY", async () => json(await getAds()));

export const PUT = adminRoute("ADMIN", async ({ req, user, ip }) => {
  const input = await readJson(req, adsInput);
  const before = await getAds();
  await prisma.$transaction([
    prisma.adSettings.upsert({
      where: { id: 1 },
      create: { id: 1, globalEnabled: input.globalEnabled, ...input.frequency },
      update: { globalEnabled: input.globalEnabled, ...input.frequency },
    }),
    ...input.placements.map((p) =>
      prisma.adPlacement.upsert({
        where: { key: p.key },
        create: { key: p.key, format: PLACEMENT_FORMAT[p.key], enabled: p.enabled, adUnitIdAndroid: p.adUnitIdAndroid, adUnitIdIos: p.adUnitIdIos },
        update: { format: PLACEMENT_FORMAT[p.key], enabled: p.enabled, adUnitIdAndroid: p.adUnitIdAndroid, adUnitIdIos: p.adUnitIdIos },
      }),
    ),
  ]);
  const after = await getAds();
  await audit({ actorId: user.id, action: "ads.update", entity: "AdSettings", entityId: "1", before, after, ip });
  return json(after);
});
