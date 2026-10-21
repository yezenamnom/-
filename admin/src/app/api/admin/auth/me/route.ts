import { adminRoute } from "@/lib/admin-route";
import { json } from "@/lib/http";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export const GET = adminRoute("READONLY", async ({ user, session }) =>
  json({
    user: { id: user.id, email: user.email, role: user.role },
    csrfToken: session.csrfToken,
    session: { expiresAt: session.expiresAt.toISOString(), lastSeenAt: session.lastSeenAt.toISOString() },
  }),
);
