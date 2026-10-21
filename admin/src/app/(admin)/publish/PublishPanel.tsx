"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { S } from "@/lib/strings";
import { api, describeError } from "@/components/api-client";
import { useAdmin } from "@/components/AdminContext";
import { Feedback, type Msg } from "@/components/Feedback";

type Props = {
  nextVersion: number;
  valid: boolean;
  issues: Array<{ path: string; message: string }>;
  draftJson: string;
  currentVersion: number | null;
  diff: Array<{ path: string; kind: "added" | "removed" | "changed"; before?: string; after?: string }>;
};

export function PublishPanel(p: Props) {
  const router = useRouter();
  const { csrf, canEdit } = useAdmin();
  const [note, setNote] = useState("");
  const [msg, setMsg] = useState<Msg>(null);
  const [busy, setBusy] = useState(false);

  async function publish(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    const r = await api<{ version: number }>("/api/admin/publish", { method: "POST", csrf, body: { note } });
    setBusy(false);
    if (!r.ok) return setMsg({ kind: "error", text: describeError(r) });
    setMsg({ kind: "success", text: `${S.publish.published} v${r.data.version}` });
    setNote("");
    router.refresh();
  }

  return (
    <>
      <Feedback msg={msg} />
      <div className="card">
        <div className="row" style={{ justifyContent: "space-between" }}>
          <div>
            {S.publish.nextVersion}: <strong data-testid="next-version">v{p.nextVersion}</strong>
            <span className="muted"> · current: {p.currentVersion ? `v${p.currentVersion}` : "—"}</span>
          </div>
          {p.valid ? <span className="ok" data-testid="draft-valid">{S.publish.valid}</span> : null}
        </div>
        {!p.valid ? (
          <div className="alert error" style={{ marginTop: 12 }} data-testid="draft-invalid">
            {S.publish.invalid}
            {"\n"}
            {p.issues.map((i) => `• ${i.path ? `${i.path}: ` : ""}${i.message}`).join("\n")}
          </div>
        ) : null}
      </div>
      <h2>{S.publish.diff}</h2>
      {p.diff.length === 0 ? (
        <p className="muted">{S.publish.noChanges}</p>
      ) : (
        <table>
          <thead>
            <tr>
              <th>Path</th>
              <th>Change</th>
              <th>Before</th>
              <th>After</th>
            </tr>
          </thead>
          <tbody>
            {p.diff.slice(0, 300).map((d) => (
              <tr key={`${d.kind}:${d.path}`} className={`diff-${d.kind}`}>
                <td>
                  <code>{d.path}</code>
                </td>
                <td>{d.kind}</td>
                <td style={{ wordBreak: "break-all" }}>{d.before ?? ""}</td>
                <td style={{ wordBreak: "break-all" }}>{d.after ?? ""}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
      {canEdit ? (
        <form className="card" onSubmit={publish} style={{ marginTop: 16 }}>
          <div className="field">
            <label htmlFor="pub-note">{S.publish.note}</label>
            <input id="pub-note" type="text" maxLength={500} value={note} onChange={(e) => setNote(e.target.value)} />
          </div>
          <button className="primary" type="submit" disabled={busy || !p.valid} data-testid="publish-button">
            {busy ? S.common.loading : S.publish.publish}
          </button>
        </form>
      ) : (
        <div className="alert info" style={{ marginTop: 16 }}>
          {S.common.readOnly}
        </div>
      )}
      <h2>{S.publish.preview}</h2>
      <pre className="json" data-testid="draft-json">
        {p.draftJson}
      </pre>
    </>
  );
}
