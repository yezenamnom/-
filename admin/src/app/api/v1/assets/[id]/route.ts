import { NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { ASSET_ID_RE } from "@/lib/config-schema";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET(_req: Request, ctx: { params: Promise<{ id: string }> }) {
  const { id } = await ctx.params;
  if (!ASSET_ID_RE.test(id)) return NextResponse.json({ error: "not_found" }, { status: 404 });
  try {
    const asset = await prisma.asset.findUnique({ where: { id } });
    if (!asset) return NextResponse.json({ error: "not_found" }, { status: 404 });
    return new NextResponse(Buffer.from(asset.bytes), {
      status: 200,
      headers: {
        "Content-Type": asset.mime,
        "Cache-Control": "public, max-age=31536000, immutable",
        ETag: `"${asset.sha256}"`,
        "Content-Security-Policy": "default-src 'none'; sandbox",
        "Content-Disposition": "inline",
      },
    });
  } catch {
    return NextResponse.json({ error: "internal_error" }, { status: 500 });
  }
}
