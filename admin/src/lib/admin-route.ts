/**
 * Wrapper for every /api/admin/* route handler. Enforces, server-side and in this order:
 *   1. Origin/Host check for non-GET requests      → 403 bad_origin
 *   2. valid session cookie                         → 401 unauthenticated
 *   3. x-csrf-token == session.csrfToken (non-GET) → 403 csrf_failed
 *   4. role >= required role                        → 403 forbidden
 */
import type { NextResponse } from "next/server";
import { readCookie, SESSION_COOKIE, validateSessionToken, type AuthContext } from "./auth/session";
import { hasRole, type RoleName } from "./auth/roles";
import { safeEqual } from "./auth/tokens";
import { clientIp, errorJson, handleError, originAllowed } from "./http";

export type AdminCtx<P> = AuthContext & { req: Request; params: P; ip: string };

type RouteContext<P> = { params: Promise<P> };

export function adminRoute<P extends Record<string, string> = Record<string, never>>(
  minRole: RoleName,
  fn: (ctx: AdminCtx<P>) => Promise<Response | NextResponse>,
) {
  return async (req: Request, routeCtx: RouteContext<P>): Promise<Response> => {
    try {
      const mutating = !["GET", "HEAD", "OPTIONS"].includes(req.method.toUpperCase());
      if (mutating && !originAllowed(req)) return errorJson(403, "bad_origin");
      const auth = await validateSessionToken(readCookie(req, SESSION_COOKIE));
      if (!auth) return errorJson(401, "unauthenticated");
      if (mutating) {
        const token = req.headers.get("x-csrf-token") ?? "";
        if (!token || !safeEqual(token, auth.session.csrfToken)) return errorJson(403, "csrf_failed");
      }
      if (!hasRole(auth.user.role, minRole)) return errorJson(403, "forbidden");
      const params = ((await routeCtx?.params) ?? {}) as P;
      return await fn({ ...auth, req, params, ip: clientIp(req) });
    } catch (e) {
      return handleError(e);
    }
  };
}
