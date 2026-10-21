import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { SESSION_COOKIE, validateSessionToken, type AuthContext } from "./session";
import { hasRole, type RoleName } from "./roles";

/** For server components: resolve the session or redirect to /login; enforce role server-side. */
export async function requirePageAuth(minRole: RoleName = "READONLY"): Promise<AuthContext> {
  const token = (await cookies()).get(SESSION_COOKIE)?.value;
  const auth = await validateSessionToken(token);
  if (!auth) redirect("/login");
  if (!hasRole(auth.user.role, minRole)) redirect("/?denied=1");
  return auth;
}

export async function optionalPageAuth(): Promise<AuthContext | null> {
  const token = (await cookies()).get(SESSION_COOKIE)?.value;
  return validateSessionToken(token);
}
