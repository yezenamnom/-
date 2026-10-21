import { z } from "zod";
import { adminRoute } from "@/lib/admin-route";
import { pageQuery } from "@/lib/admin-schemas";
import { json } from "@/lib/http";
import { listReports } from "@/lib/queries";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

const query = pageQuery.extend({ status: z.enum(["NEW", "TRIAGED", "CLOSED"]).optional() });

export const GET = adminRoute("READONLY", async ({ req }) => {
  const q = query.parse(Object.fromEntries(new URL(req.url).searchParams));
  return json(await listReports(q));
});
