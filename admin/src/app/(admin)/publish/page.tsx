import { requirePageAuth } from "@/lib/auth/page-session";
import { previewDraft } from "@/lib/publish";
import { diffJson } from "@/lib/json-diff";
import { S } from "@/lib/strings";
import { PublishPanel } from "./PublishPanel";

export default async function PublishPage() {
  await requirePageAuth();
  const { nextVersion, validation, current } = await previewDraft();
  const currentContent = current ? (JSON.parse(current.contentJson) as Record<string, unknown>) : null;
  const draft = validation.content as Record<string, unknown>;
  const strip = (c: Record<string, unknown> | null) => (c ? { ...c, configVersion: undefined } : null);
  const diff = diffJson(strip(currentContent), strip(draft));
  return (
    <>
      <h1>{S.publish.title}</h1>
      <p className="muted">{S.publish.hint}</p>
      <PublishPanel
        nextVersion={nextVersion}
        valid={validation.ok}
        issues={validation.ok ? [] : validation.issues}
        draftJson={JSON.stringify(draft, null, 2)}
        currentVersion={current?.version ?? null}
        diff={diff.map((d) => ({ path: d.path, kind: d.kind, before: JSON.stringify(d.before), after: JSON.stringify(d.after) }))}
      />
    </>
  );
}
