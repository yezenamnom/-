import { adminRoute } from "@/lib/admin-route";
import { json } from "@/lib/http";
import { systemStatus } from "@/lib/queries";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

// AdMob earnings are intentionally not reported: no AdMob API integration exists ("Not connected").
export const GET = adminRoute("READONLY", async () => json({ ...(await systemStatus()), admob: { connected: false } }));
