import { NextResponse, type NextRequest } from "next/server";

/**
 * Per-request nonce-based CSP. Next.js picks the nonce up from the request's
 * Content-Security-Policy header and applies it to its own inline bootstrap scripts,
 * so no 'unsafe-inline' is needed for scripts. ('unsafe-eval' only in `next dev`.)
 */
export function middleware(req: NextRequest) {
  const isApi = req.nextUrl.pathname.startsWith("/api/");
  if (isApi) {
    const res = NextResponse.next();
    res.headers.set("Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'; sandbox");
    return res;
  }
  const nonce = btoa(crypto.randomUUID());
  const dev = process.env.NODE_ENV !== "production";
  const csp = [
    "default-src 'self'",
    `script-src 'self' 'nonce-${nonce}' 'strict-dynamic'${dev ? " 'unsafe-eval'" : ""}`,
    "style-src 'self' 'unsafe-inline'",
    "img-src 'self' data: blob:",
    "font-src 'self'",
    "connect-src 'self'",
    "object-src 'none'",
    "base-uri 'none'",
    "form-action 'self'",
    "frame-ancestors 'none'",
  ].join("; ");
  const requestHeaders = new Headers(req.headers);
  requestHeaders.set("x-nonce", nonce);
  requestHeaders.set("Content-Security-Policy", csp);
  const res = NextResponse.next({ request: { headers: requestHeaders } });
  res.headers.set("Content-Security-Policy", csp);
  return res;
}

export const config = {
  matcher: [{ source: "/((?!_next/static|_next/image|favicon.ico).*)" }],
};
