import { NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { reportIpSalt } from "@/lib/env";
import { clientIp, HttpError, readJson, zodIssues } from "@/lib/http";
import { consumeReportQuota, hashIp, reportInput } from "@/lib/reports";
import { ZodError } from "zod";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

const H = { "Cache-Control": "no-store" };

export async function POST(req: Request) {
  try {
    const salt = reportIpSalt();
    if (!salt) return NextResponse.json({ error: "reports_unavailable" }, { status: 503, headers: H });
    const input = await readJson(req, reportInput, 16 * 1024);
    const allowed = await consumeReportQuota(hashIp(clientIp(req), salt));
    if (!allowed) {
      return NextResponse.json({ error: "rate_limited" }, { status: 429, headers: { ...H, "Retry-After": "3600" } });
    }
    const report = await prisma.userReport.create({
      data: {
        category: input.category,
        message: input.message.trim(),
        appVersion: input.appVersion,
        platform: input.platform,
        locale: input.locale,
        siteHost: input.siteHost ?? null,
      },
    });
    return NextResponse.json({ id: report.id }, { status: 201, headers: H });
  } catch (e) {
    if (e instanceof HttpError) {
      return NextResponse.json({ error: e.code, ...(e.details ? { details: e.details } : {}) }, { status: e.status, headers: H });
    }
    if (e instanceof ZodError) return NextResponse.json({ error: "validation_failed", details: zodIssues(e) }, { status: 400, headers: H });
    return NextResponse.json({ error: "internal_error" }, { status: 500, headers: H });
  }
}
