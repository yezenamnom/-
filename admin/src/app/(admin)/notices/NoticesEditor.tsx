"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { S } from "@/lib/strings";
import type { NoticeRow } from "@/lib/queries";
import { api, describeError } from "@/components/api-client";
import { useAdmin } from "@/components/AdminContext";
import { Feedback, type Msg } from "@/components/Feedback";

type Form = { id: string | null; key: string; severity: "info" | "update"; en: string; ar: string; de: string; minAppVersion: string; maxAppVersion: string; active: boolean };
const empty: Form = { id: null, key: "", severity: "info", en: "", ar: "", de: "", minAppVersion: "", maxAppVersion: "", active: true };

export function NoticesEditor({ items }: { items: NoticeRow[] }) {
  const router = useRouter();
  const { csrf, canEdit } = useAdmin();
  const [form, setForm] = useState<Form | null>(null);
  const [msg, setMsg] = useState<Msg>(null);

  async function save(e: React.FormEvent) {
    e.preventDefault();
    if (!form) return;
    const body = {
      key: form.key,
      severity: form.severity,
      message: { en: form.en, ar: form.ar, de: form.de },
      minAppVersion: form.minAppVersion,
      maxAppVersion: form.maxAppVersion,
      active: form.active,
    };
    const r = form.id
      ? await api(`/api/admin/notices/${form.id}`, { method: "PUT", body, csrf })
      : await api("/api/admin/notices", { method: "POST", body, csrf });
    if (!r.ok) return setMsg({ kind: "error", text: describeError(r) });
    setMsg({ kind: "success", text: S.common.saved });
    setForm(null);
    router.refresh();
  }

  async function remove(id: string) {
    if (!window.confirm(S.common.confirmDelete)) return;
    const r = await api(`/api/admin/notices/${id}`, { method: "DELETE", csrf });
    if (!r.ok) return setMsg({ kind: "error", text: describeError(r) });
    router.refresh();
  }

  return (
    <>
      <Feedback msg={msg} />
      {!canEdit ? <div className="alert info">{S.common.readOnly}</div> : null}
      <table>
        <thead>
          <tr>
            <th>Key</th>
            <th>Severity</th>
            <th>Message (en)</th>
            <th>App versions</th>
            <th>Status</th>
            {canEdit ? <th /> : null}
          </tr>
        </thead>
        <tbody>
          {items.length === 0 ? (
            <tr>
              <td colSpan={6} className="muted">
                {S.common.none}
              </td>
            </tr>
          ) : null}
          {items.map((n) => (
            <tr key={n.id}>
              <td>
                <code>{n.key}</code>
              </td>
              <td>{n.severity}</td>
              <td>{n.message.en}</td>
              <td>
                {n.minAppVersion ?? "*"} – {n.maxAppVersion ?? "*"}
              </td>
              <td>
                <span className={`badge ${n.active ? "on" : ""}`}>{n.active ? S.common.active : S.common.disabled}</span>
              </td>
              {canEdit ? (
                <td>
                  <div className="row">
                    <button
                      type="button"
                      onClick={() =>
                        setForm({
                          id: n.id,
                          key: n.key,
                          severity: n.severity,
                          en: n.message.en ?? "",
                          ar: n.message.ar ?? "",
                          de: n.message.de ?? "",
                          minAppVersion: n.minAppVersion ?? "",
                          maxAppVersion: n.maxAppVersion ?? "",
                          active: n.active,
                        })
                      }
                    >
                      {S.common.edit}
                    </button>
                    <button type="button" className="danger" onClick={() => remove(n.id)}>
                      {S.common.delete}
                    </button>
                  </div>
                </td>
              ) : null}
            </tr>
          ))}
        </tbody>
      </table>
      {canEdit && !form ? (
        <p>
          <button type="button" className="primary" onClick={() => setForm({ ...empty })}>
            {S.notices.new}
          </button>
        </p>
      ) : null}
      {canEdit && form ? (
        <form className="card" onSubmit={save} style={{ marginTop: 16 }}>
          <div className="cols">
            <div className="field">
              <label htmlFor="nt-key">{S.notices.key}</label>
              <input id="nt-key" type="text" value={form.key} onChange={(e) => setForm({ ...form, key: e.target.value })} />
            </div>
            <div className="field">
              <label htmlFor="nt-sev">{S.notices.severity}</label>
              <select id="nt-sev" value={form.severity} onChange={(e) => setForm({ ...form, severity: e.target.value as Form["severity"] })}>
                <option value="info">info</option>
                <option value="update">update</option>
              </select>
            </div>
            <div className="field">
              <label htmlFor="nt-min">{S.notices.minApp}</label>
              <input id="nt-min" type="text" value={form.minAppVersion} onChange={(e) => setForm({ ...form, minAppVersion: e.target.value })} placeholder="1.0.0" />
            </div>
            <div className="field">
              <label htmlFor="nt-max">{S.notices.maxApp}</label>
              <input id="nt-max" type="text" value={form.maxAppVersion} onChange={(e) => setForm({ ...form, maxAppVersion: e.target.value })} placeholder="1.9.9" />
            </div>
          </div>
          {(["en", "ar", "de"] as const).map((l) => (
            <div className="field" key={l}>
              <label htmlFor={`nt-${l}`}>
                {S.notices.message} ({l}, ≤ 280)
              </label>
              <input id={`nt-${l}`} type="text" dir={l === "ar" ? "rtl" : undefined} maxLength={280} value={form[l]} onChange={(e) => setForm({ ...form, [l]: e.target.value })} />
            </div>
          ))}
          <label className="check field">
            <input type="checkbox" checked={form.active} onChange={(e) => setForm({ ...form, active: e.target.checked })} /> {S.common.active}
          </label>
          <div className="row">
            <button className="primary" type="submit">
              {S.common.save}
            </button>
            <button type="button" onClick={() => setForm(null)}>
              {S.common.cancel}
            </button>
          </div>
        </form>
      ) : null}
    </>
  );
}
