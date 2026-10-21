"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { S } from "@/lib/strings";
import type { ReleaseRow } from "@/lib/queries";
import { api, describeError } from "@/components/api-client";
import { useAdmin } from "@/components/AdminContext";
import { Feedback, type Msg } from "@/components/Feedback";

export function ReleasesTable({ items }: { items: ReleaseRow[] }) {
  const router = useRouter();
  const { csrf, canEdit } = useAdmin();
  const [msg, setMsg] = useState<Msg>(null);
  const [viewing, setViewing] = useState<{ version: number; json: string } | null>(null);

  async function rollback(version: number) {
    if (!window.confirm(`${S.releases.rollbackConfirm}${version}?`)) return;
    const r = await api<{ version: number }>(`/api/admin/releases/${version}/rollback`, { method: "POST", csrf, body: { note: "" } });
    if (!r.ok) return setMsg({ kind: "error", text: describeError(r) });
    setMsg({ kind: "success", text: `${S.publish.published} v${r.data.version}` });
    router.refresh();
  }

  async function view(version: number) {
    const r = await api<{ item: { content: unknown } }>(`/api/admin/releases/${version}`, { csrf });
    if (!r.ok) return setMsg({ kind: "error", text: describeError(r) });
    setViewing({ version, json: JSON.stringify(r.data.item.content, null, 2) });
  }

  return (
    <>
      <Feedback msg={msg} />
      <table data-testid="releases-table">
        <thead>
          <tr>
            <th>{S.releases.version}</th>
            <th>{S.releases.note}</th>
            <th>{S.releases.by}</th>
            <th>{S.releases.at}</th>
            <th />
          </tr>
        </thead>
        <tbody>
          {items.length === 0 ? (
            <tr>
              <td colSpan={5} className="muted">
                {S.common.none}
              </td>
            </tr>
          ) : null}
          {items.map((r) => (
            <tr key={r.version}>
              <td>
                v{r.version} {r.isCurrent ? <span className="badge current">{S.releases.current}</span> : null}
                {r.rolledBackFromVersion ? (
                  <div className="muted">
                    {S.releases.from}
                    {r.rolledBackFromVersion}
                  </div>
                ) : null}
              </td>
              <td>{r.note}</td>
              <td>{r.createdBy ?? "—"}</td>
              <td>{new Date(r.createdAt).toISOString().slice(0, 19).replace("T", " ")}</td>
              <td>
                <div className="row">
                  <button type="button" onClick={() => view(r.version)}>
                    {S.blocklists.view}
                  </button>
                  {canEdit && !r.isCurrent ? (
                    <button type="button" onClick={() => rollback(r.version)}>
                      {S.releases.rollback}
                    </button>
                  ) : null}
                </div>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      {viewing ? (
        <div className="card" style={{ marginTop: 16 }}>
          <div className="row" style={{ justifyContent: "space-between" }}>
            <strong>v{viewing.version}</strong>
            <button type="button" onClick={() => setViewing(null)}>
              ×
            </button>
          </div>
          <pre className="json">{viewing.json}</pre>
        </div>
      ) : null}
    </>
  );
}
