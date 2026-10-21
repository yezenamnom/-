"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { S } from "@/lib/strings";
import type { BlocklistRow } from "@/lib/queries";
import { api, describeError } from "@/components/api-client";
import { useAdmin } from "@/components/AdminContext";
import { Feedback, type Msg } from "@/components/Feedback";

export function BlocklistsEditor({ items }: { items: BlocklistRow[] }) {
  const router = useRouter();
  const { csrf, canEdit } = useAdmin();
  const [msg, setMsg] = useState<Msg>(null);
  const [busy, setBusy] = useState(false);
  const [name, setName] = useState(items[0]?.name ?? "Vela Starter");
  const [license, setLicense] = useState(items[0]?.license ?? "Original work by project owner");
  const [rulesText, setRulesText] = useState("");
  const [viewing, setViewing] = useState<{ version: number; body: string } | null>(null);

  async function create(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    const r = await api<{ item: { version: number; ruleCount: number } }>("/api/admin/blocklists", {
      method: "POST",
      csrf,
      body: { name, license, rulesText },
    });
    setBusy(false);
    if (!r.ok) return setMsg({ kind: "error", text: describeError(r) });
    setMsg({ kind: "success", text: `Created v${r.data.item.version} (${r.data.item.ruleCount} rules)` });
    setRulesText("");
    router.refresh();
  }

  async function action(version: number, act: "activate" | "archive") {
    const r = await api(`/api/admin/blocklists/${version}/${act}`, { method: "POST", csrf });
    setMsg(r.ok ? { kind: "success", text: `v${version}: ${act}d` } : { kind: "error", text: describeError(r) });
    if (r.ok) router.refresh();
  }

  async function view(version: number) {
    const r = await api<{ item: { body: string } }>(`/api/admin/blocklists/${version}`, { csrf });
    if (!r.ok) return setMsg({ kind: "error", text: describeError(r) });
    let pretty = r.data.item.body;
    try {
      pretty = JSON.stringify(JSON.parse(pretty), null, 2);
    } catch {
      /* keep raw */
    }
    setViewing({ version, body: pretty });
  }

  return (
    <>
      <Feedback msg={msg} />
      {!canEdit ? <div className="alert info">{S.common.readOnly}</div> : null}
      <table>
        <thead>
          <tr>
            <th>Version</th>
            <th>Name</th>
            <th>Rules</th>
            <th>Status</th>
            <th>SHA-256</th>
            <th>Created</th>
            <th />
          </tr>
        </thead>
        <tbody>
          {items.map((b) => (
            <tr key={b.version}>
              <td>v{b.version}</td>
              <td>
                {b.name}
                <div className="muted">{b.license}</div>
              </td>
              <td>{b.ruleCount}</td>
              <td>
                <span className={`badge ${b.status}`}>{b.status}</span>
              </td>
              <td>
                <code title={b.sha256}>{b.sha256.slice(0, 12)}…</code>
              </td>
              <td>
                {new Date(b.createdAt).toISOString().slice(0, 16).replace("T", " ")}
                <div className="muted">{b.createdBy ?? ""}</div>
              </td>
              <td>
                <div className="row">
                  <button type="button" onClick={() => view(b.version)}>
                    {S.blocklists.view}
                  </button>
                  {canEdit && b.status !== "ACTIVE" ? (
                    <button type="button" onClick={() => action(b.version, "activate")}>
                      {S.blocklists.activate}
                    </button>
                  ) : null}
                  {canEdit && b.status !== "ARCHIVED" ? (
                    <button type="button" onClick={() => action(b.version, "archive")}>
                      {S.blocklists.archive}
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
          <pre className="json">{viewing.body}</pre>
        </div>
      ) : null}
      {canEdit ? (
        <form className="card" onSubmit={create} style={{ marginTop: 16 }}>
          <h2 style={{ marginTop: 0 }}>New version</h2>
          <div className="cols">
            <div className="field">
              <label htmlFor="bl-name">{S.blocklists.name}</label>
              <input id="bl-name" type="text" value={name} onChange={(e) => setName(e.target.value)} />
            </div>
            <div className="field">
              <label htmlFor="bl-license">{S.blocklists.license}</label>
              <input id="bl-license" type="text" value={license} onChange={(e) => setLicense(e.target.value)} />
            </div>
          </div>
          <div className="field">
            <label htmlFor="bl-rules">{S.blocklists.rules}</label>
            <textarea id="bl-rules" rows={14} value={rulesText} onChange={(e) => setRulesText(e.target.value)} spellCheck={false} />
          </div>
          <button className="primary" type="submit" disabled={busy || !rulesText.trim()}>
            {busy ? S.common.loading : S.blocklists.create}
          </button>
        </form>
      ) : null}
    </>
  );
}
