import { NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET(_req: Request, ctx: { params: Promise<{ version: string }> }) {
  const { version: raw } = await ctx.params;
  if (!/^[1-9]\d{0,8}$/.test(raw)) return NextResponse.json({ error: "not_found" }, { status: 404 });
  try {
    const list = await prisma.blockList.findUnique({ where: { version: Number(raw) } });
    // Only lists that have been activated (ACTIVE, or ARCHIVED after being active) are public.
    if (!list || list.status === "DRAFT" || !list.activatedAt) {
      return NextResponse.json({ error: "not_found" }, { status: 404 });
    }
    // Exact stored bytes; listSha256 in the signed config is over these bytes.
    return new NextResponse(Buffer.from(list.body, "utf8"), {
      status: 200,
      headers: {
        "Content-Type": "application/json",
        "Cache-Control": "public, max-age=31536000, immutable",
        ETag: `"${list.sha256}"`,
        "X-Content-SHA256": list.sha256,
      },
    });
  } catch {
    return NextResponse.json({ error: "internal_error" }, { status: 500 });
  }
}
