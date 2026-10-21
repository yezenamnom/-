import { adminRoute } from "@/lib/admin-route";
import { json } from "@/lib/http";
import { listReleases } from "@/lib/queries";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export const GET = adminRoute("READONLY", async () => json({ items: await listReleases(200) }));
