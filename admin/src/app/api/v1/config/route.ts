import { NextResponse } from "next/server";
import { buildSignedEnvelope, countConfigFetch } from "@/lib/config-serve";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET(req: Request) {
  try {
    const url = new URL(req.url);
    const p = url.searchParams.get("platform");
    const platform = p === "android" || p === "ios" ? p : "unknown";
    // appVersion is accepted but not stored (contract: aggregated daily counter only).
    const result = await buildSignedEnvelope();
    if (result.status !== 200) {
      return NextResponse.json({ error: result.error }, { status: result.status, headers: { "Cache-Control": "no-store" } });
    }
    await countConfigFetch(platform).catch(() => undefined);
    return NextResponse.json(result.envelope, {
      headers: { "Cache-Control": "public, max-age=60", "X-Config-Version": String(result.configVersion) },
    });
  } catch {
    return NextResponse.json({ error: "internal_error" }, { status: 500, headers: { "Cache-Control": "no-store" } });
  }
}
