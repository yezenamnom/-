"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { S } from "@/lib/strings";
import { ICON_KEYS } from "@/lib/config-schema";
import type { ShortcutRow } from "@/lib/queries";
import { api, describeError } from "@/components/api-client";
import { useAdmin } from "@/components/AdminContext";
import { Feedback, type Msg } from "@/components/Feedback";

type Form = {
  id: string | null;
  key: string;
  en: string;
  ar: string;
  de: string;
  url: string;
  iconKey: string;
  iconAssetId: string | null;
  color: string;
  enabled: boolean;
};

const empty: Form = { id: null, key: "", en: "", ar: "", de: "", url: "https://", iconKey: "generic", iconAssetId: null, color: "#2457D6", enabled: true };

function toForm(s: ShortcutRow): Form {
  return {
    id: s.id,
    key: s.key,
    en: s.titles.en ?? "",
    ar: s.titles.ar ?? "",
    de: s.titles.de ?? "",
    url: s.url,
    iconKey: s.iconKey ?? "",
    iconAssetId: s.iconAssetId,
    color: s.color,
    enabled: s.enabled,
  };
}

export function ShortcutsEditor({ items }: { items: ShortcutRow[] }) {
  const router = useRouter();
  const { csrf, canEdit } = useAdmin();
  const [form, setForm] = useState<Form | null>(null);
  const [msg, setMsg] = useState<Msg>(null);
  const [busy, setBusy] = useState(false);

  async function save(e: React.FormEvent) {
    e.preventDefault();
    if (!form) return;
    setBusy(true);
    setMsg(null);
    const body = {
      key: form.key,
      titles: { en: form.en, ar: form.ar, de: form.de },
      url: form.url,
      iconKey: form.iconKey || null,
      iconAssetId: form.iconAssetId,
      color: form.color,
      enabled: form.enabled,
    };
    const r = form.id
      ? await api(`/api/admin/shortcuts/${form.id}`, { method: "PUT", body, csrf })
      : await api("/api/admin/shortcuts", { method: "POST", body, csrf });
    setBusy(false);
    if (!r.ok) return setMsg({ kind: "error", text: describeError(r) });
    setMsg({ kind: "success", text: S.common.saved });
    setForm(null);
    router.refresh();
  }

  async function remove(id: string) {
    if (!window.confirm(S.common.confirmDelete)) return;
    const r = await api(`/api/admin/shortcuts/${id}`, { method: "DELETE", csrf });
    if (!r.ok) return setMsg({ kind: "error", text: describeError(r) });
    router.refresh();
  }

  async function move(index: number, delta: number) {
    const ids = items.map((i) => i.id);
    const j = index + delta;
    if (j < 0 || j >= ids.length) return;
    [ids[index], ids[j]] = [ids[j]!, ids[index]!];
    const r = await api("/api/admin/shortcuts/reorder", { method: "POST", body: { ids }, csrf });
    if (!r.ok) return setMsg({ kind: "error", text: describeError(r) });
    router.refresh();
  }

  async function upload(file: File) {
    if (!form) return;
    const fd = new FormData();
    fd.append("file", file);
    const r = await api<{ id: string }>("/api/admin/assets", { method: "POST", form: fd, csrf });
    if (!r.ok) return setMsg({ kind: "error", text: describeError(r) });
    setForm({ ...form, iconAssetId: r.data.id });
  }

  return (
    <>
      <Feedback msg={msg} />
      {!canEdit ? <div className="alert info">{S.common.readOnly}</div> : null}
      <table data-testid="shortcuts-table">
        <thead>
          <tr>
            <th>#</th>
            <th>Key</th>
            <th>Title</th>
            <th>URL</th>
            <th>Icon</th>
            <th>Status</th>
            {canEdit ? <th /> : null}
          </tr>
        </thead>
        <tbody>
          {items.map((s, i) => (
            <tr key={s.id} data-testid={`shortcut-${s.key}`}>
              <td>{i + 1}</td>
              <td>
                <code>{s.key}</code>
              </td>
              <td>
                <span className="swatch" style={{ background: s.color }} /> {s.titles.en}
                <div className="muted">
                  {s.titles.ar ? <span dir="rtl">{s.titles.ar}</span> : null} {s.titles.de ? `· ${s.titles.de}` : null}
                </div>
              </td>
              <td style={{ wordBreak: "break-all" }}>{s.url}</td>
              <td>
                {s.iconAssetId ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img className="icon-preview" src={`/api/v1/assets/${s.iconAssetId}`} alt="" />
                ) : (
                  s.iconKey ?? "—"
                )}
              </td>
              <td>
                <span className={`badge ${s.enabled ? "on" : ""}`}>{s.enabled ? S.common.enabled : S.common.disabled}</span>
              </td>
              {canEdit ? (
                <td>
                  <div className="row">
                    <button type="button" onClick={() => move(i, -1)} disabled={i === 0} aria-label={S.common.moveUp}>
                      ↑
                    </button>
                    <button type="button" onClick={() => move(i, 1)} disabled={i === items.length - 1} aria-label={S.common.moveDown}>
                      ↓
                    </button>
                    <button type="button" onClick={() => setForm(toForm(s))}>
                      {S.common.edit}
                    </button>
                    <button type="button" className="danger" onClick={() => remove(s.id)}>
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
          <button type="button" className="primary" onClick={() => setForm({ ...empty })} data-testid="new-shortcut">
            {S.shortcuts.new}
          </button>
        </p>
      ) : null}
      {canEdit && form ? (
        <form className="card" onSubmit={save} style={{ marginTop: 16 }} data-testid="shortcut-form">
          <h2 style={{ marginTop: 0 }}>{form.id ? `${S.common.edit}: ${form.key}` : S.shortcuts.new}</h2>
          <div className="cols">
            <div className="field">
              <label htmlFor="sc-key">{S.shortcuts.key}</label>
              <input id="sc-key" type="text" value={form.key} onChange={(e) => setForm({ ...form, key: e.target.value })} required />
            </div>
            <div className="field">
              <label htmlFor="sc-url">{S.shortcuts.url}</label>
              <input id="sc-url" type="url" value={form.url} onChange={(e) => setForm({ ...form, url: e.target.value })} required />
            </div>
          </div>
          <div className="cols">
            <div className="field">
              <label htmlFor="sc-en">{S.shortcuts.titleEn}</label>
              <input id="sc-en" type="text" maxLength={40} value={form.en} onChange={(e) => setForm({ ...form, en: e.target.value })} required />
            </div>
            <div className="field">
              <label htmlFor="sc-ar">{S.shortcuts.titleAr}</label>
              <input id="sc-ar" type="text" dir="rtl" maxLength={40} value={form.ar} onChange={(e) => setForm({ ...form, ar: e.target.value })} />
            </div>
            <div className="field">
              <label htmlFor="sc-de">{S.shortcuts.titleDe}</label>
              <input id="sc-de" type="text" maxLength={40} value={form.de} onChange={(e) => setForm({ ...form, de: e.target.value })} />
            </div>
          </div>
          <div className="cols">
            <div className="field">
              <label htmlFor="sc-icon">{S.shortcuts.iconKey}</label>
              <select id="sc-icon" value={form.iconKey} onChange={(e) => setForm({ ...form, iconKey: e.target.value })}>
                <option value="">— none —</option>
                {ICON_KEYS.map((k) => (
                  <option key={k} value={k}>
                    {k}
                  </option>
                ))}
              </select>
            </div>
            <div className="field">
              <label htmlFor="sc-color">{S.shortcuts.color}</label>
              <div className="row">
                <input id="sc-color" type="color" value={form.color} onChange={(e) => setForm({ ...form, color: e.target.value.toUpperCase() })} />
                <code>{form.color}</code>
              </div>
            </div>
            <div className="field">
              <label htmlFor="sc-upload">{S.shortcuts.iconUpload}</label>
              <input
                id="sc-upload"
                type="file"
                accept="image/png,image/jpeg,image/webp"
                onChange={(e) => {
                  const f = e.target.files?.[0];
                  if (f) void upload(f);
                }}
              />
              {form.iconAssetId ? (
                <div className="row" style={{ marginTop: 6 }}>
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img className="icon-preview" src={`/api/v1/assets/${form.iconAssetId}`} alt="" />
                  <button type="button" onClick={() => setForm({ ...form, iconAssetId: null })}>
                    {S.shortcuts.removeIcon}
                  </button>
                </div>
              ) : null}
            </div>
          </div>
          <div className="field">
            <label className="check">
              <input type="checkbox" checked={form.enabled} onChange={(e) => setForm({ ...form, enabled: e.target.checked })} /> {S.common.enabled}
            </label>
          </div>
          <div className="row">
            <button className="primary" type="submit" disabled={busy}>
              {busy ? S.common.loading : S.common.save}
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
