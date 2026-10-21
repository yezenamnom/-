import { NextResponse } from "next/server";
import { attemptLogin, LOGIN_FAILED_MESSAGE, LOGIN_RATE_LIMITED_MESSAGE } from "@/lib/auth/login";
import { readCookie, SESSION_COOKIE, sessionCookieOptions } from "@/lib/auth/session";
import { loginInput } from "@/lib/admin-schemas";
import { clientIp, errorJson, handleError, originAllowed, readJson } from "@/lib/http";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function POST(req: Request) {
  try {
    if (!originAllowed(req)) return errorJson(403, "bad_origin");
    const input = await readJson(req, loginInput, 4 * 1024);
    const result = await attemptLogin({
      email: input.email,
      password: input.password,
      ip: clientIp(req),
      userAgent: req.headers.get("user-agent"),
      previousToken: readCookie(req, SESSION_COOKIE),
    });
    if (!result.ok) {
      return result.status === 429
        ? errorJson(429, "rate_limited", LOGIN_RATE_LIMITED_MESSAGE)
        : errorJson(401, "login_failed", LOGIN_FAILED_MESSAGE);
    }
    const res = NextResponse.json({ ok: true, csrfToken: result.csrfToken }, { headers: { "Cache-Control": "no-store" } });
    res.cookies.set(SESSION_COOKIE, result.token, sessionCookieOptions(result.expiresAt));
    return res;
  } catch (e) {
    return handleError(e);
  }
}
