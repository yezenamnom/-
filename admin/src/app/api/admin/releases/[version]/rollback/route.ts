import { adminRoute } from "@/lib/admin-route";
import { noteInput } from "@/lib/admin-schemas";
import { HttpError, json, readJson } from "@/lib/http";
import { rollbackRelease } from "@/lib/publish";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

/** Creates a NEW release (max + 1) whose content is that of {version}. */
export const POST = adminRoute<{ version: string }>("ADMIN", async ({ req, user, ip, params }) => {
  if (!/^[1-9]\d{0,8}$/.test(params.version)) throw new HttpError(404, "not_found");
  const { note } = await readJson(req, noteInput);
  const release = await rollbackRelease({ fromVersion: Number(params.version), actorId: user.id, note, ip });
  return json({ version: release.version, rolledBackFromVersion: release.rolledBackFromVersion }, 201);
});
