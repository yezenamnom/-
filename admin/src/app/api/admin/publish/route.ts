import { adminRoute } from "@/lib/admin-route";
import { noteInput } from "@/lib/admin-schemas";
import { json, readJson } from "@/lib/http";
import { diffJson } from "@/lib/json-diff";
import { previewDraft, publishRelease } from "@/lib/publish";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

/** Draft preview: assembled from current tables and validated with the signing schema, plus diff vs current release. */
export const GET = adminRoute("READONLY", async () => {
  const { nextVersion, validation, current } = await previewDraft();
  const currentContent = current ? (JSON.parse(current.contentJson) as Record<string, unknown>) : null;
  const draft = validation.content as Record<string, unknown>;
  const strip = (c: Record<string, unknown> | null) => (c ? { ...c, configVersion: undefined } : null);
  return json({
    nextVersion,
    valid: validation.ok,
    issues: validation.ok ? [] : validation.issues,
    draft,
    current: current ? { version: current.version, createdAt: current.createdAt.toISOString(), content: currentContent } : null,
    // configVersion always differs, so it is excluded from the diff.
    diff: diffJson(strip(currentContent), strip(draft)),
  });
});

export const POST = adminRoute("ADMIN", async ({ req, user, ip }) => {
  const { note } = await readJson(req, noteInput);
  const release = await publishRelease({ actorId: user.id, note, ip });
  return json({ version: release.version, createdAt: release.createdAt.toISOString() }, 201);
});
