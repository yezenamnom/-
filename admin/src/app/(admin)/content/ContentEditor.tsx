"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { S } from "@/lib/strings";
import type { ContentView } from "@/lib/queries";
import { api, describeError } from "@/components/api-client";
import { useAdmin } from "@/components/AdminContext";
import { Feedback, type Msg } from "@/components/Feedback";

export function ContentEditor({ initial }: { initial: ContentView }) {
  const router = useRouter();
  const { csrf, canEdit } = useAdmin();
  const [s, setS] = useState({
    privacyUrl: initial.privacyUrl,
    termsUrl: initial.termsUrl,
    supportUrl: initial.supportUrl,
    en: initial.helpText.en ?? "",
    ar: initial.helpText.ar ?? "",
    de: initial.helpText.de ?? "",
    minAppVersion: initial.minAppVersion ?? "",
    maxAppVersion: initial.maxAppVersion ?? "",
    blockingEnabledByDefault: initial.blockingEnabledByDefault,
  });
  const [msg, setMsg] = useState<Msg>(null);
  const [busy, setBusy] = useState(false);

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    const r = await api("/api/admin/content", {
      method: "PUT",
      csrf,
      body: {
        privacyUrl: s.privacyUrl,
        termsUrl: s.termsUrl,
        supportUrl: s.supportUrl,
        helpText: { en: s.en, ar: s.ar, de: s.de },
        minAppVersion: s.minAppVersion,
        maxAppVersion: s.maxAppVersion,
        blockingEnabledByDefault: s.blockingEnabledByDefault,
      },
    });
    setBusy(false);
    setMsg(r.ok ? { kind: "success", text: S.common.saved } : { kind: "error", text: describeError(r) });
    if (r.ok) router.refresh();
  }

  const input = (id: keyof typeof s, label: string, type = "text", dir?: "rtl") => (
    <div className="field">
      <label htmlFor={`ct-${id}`}>{label}</label>
      <input id={`ct-${id}`} type={type} dir={dir} value={String(s[id])} onChange={(e) => setS({ ...s, [id]: e.target.value })} />
    </div>
  );

  return (
    <form onSubmit={save}>
      <Feedback msg={msg} />
      {!canEdit ? <div className="alert info">{S.common.readOnly}</div> : null}
      <fieldset disabled={!canEdit} style={{ border: 0, padding: 0, margin: 0 }}>
        <div className="card">
          {input("privacyUrl", S.content.privacy, "url")}
          {input("termsUrl", S.content.terms, "url")}
          {input("supportUrl", S.content.support, "url")}
        </div>
        <div className="card">
          <h2 style={{ marginTop: 0 }}>{S.content.help}</h2>
          {(["en", "ar", "de"] as const).map((l) => (
            <div className="field" key={l}>
              <label htmlFor={`ct-help-${l}`}>{l}</label>
              <textarea id={`ct-help-${l}`} dir={l === "ar" ? "rtl" : undefined} rows={4} value={s[l]} onChange={(e) => setS({ ...s, [l]: e.target.value })} style={{ fontFamily: "inherit", fontSize: 14 }} />
            </div>
          ))}
        </div>
        <div className="card">
          <h2 style={{ marginTop: 0 }}>{S.content.compat}</h2>
          <div className="cols">
            {input("minAppVersion", S.content.minApp)}
            {input("maxAppVersion", S.content.maxApp)}
          </div>
          <label className="check">
            <input type="checkbox" checked={s.blockingEnabledByDefault} onChange={(e) => setS({ ...s, blockingEnabledByDefault: e.target.checked })} />
            {S.content.blockingDefault}
          </label>
        </div>
        {canEdit ? (
          <button className="primary" type="submit" disabled={busy}>
            {busy ? S.common.loading : S.common.save}
          </button>
        ) : null}
      </fieldset>
    </form>
  );
}
