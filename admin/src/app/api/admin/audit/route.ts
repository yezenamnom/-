import { adminRoute } from "@/lib/admin-route";
import { pageQuery } from "@/lib/admin-schemas";
import { json } from "@/lib/http";
import { listAudit } from "@/lib/queries";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export const GET = adminRoute("READONLY", async ({ req }) => {
  const q = pageQuery.parse(Object.fromEntries(new URL(req.url).searchParams));
  return json(await listAudit(q));
});
