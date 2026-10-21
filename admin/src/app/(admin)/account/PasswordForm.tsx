"use client";

import { useState } from "react";
import { S } from "@/lib/strings";
import { api, describeError } from "@/components/api-client";
import { useAdmin } from "@/components/AdminContext";
import { Feedback, type Msg } from "@/components/Feedback";

export function PasswordForm() {
  const { csrf } = useAdmin();
  const [currentPassword, setCurrent] = useState("");
  const [newPassword, setNext] = useState("");
  const [msg, setMsg] = useState<Msg>(null);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    const r = await api("/api/admin/auth/password", { method: "POST", csrf, body: { currentPassword, newPassword } });
    setMsg(r.ok ? { kind: "success", text: S.common.saved } : { kind: "error", text: describeError(r) });
    if (r.ok) {
      setCurrent("");
      setNext("");
    }
  }

  return (
    <form className="card" onSubmit={submit}>
      <h2 style={{ marginTop: 0 }}>{S.account.change}</h2>
      <Feedback msg={msg} />
      <div className="cols">
        <div className="field">
          <label htmlFor="pw-cur">{S.account.current}</label>
          <input id="pw-cur" type="password" autoComplete="current-password" value={currentPassword} onChange={(e) => setCurrent(e.target.value)} />
        </div>
        <div className="field">
          <label htmlFor="pw-new">{S.account.next}</label>
          <input id="pw-new" type="password" autoComplete="new-password" value={newPassword} onChange={(e) => setNext(e.target.value)} />
        </div>
      </div>
      <button className="primary" type="submit">
        {S.common.save}
      </button>
    </form>
  );
}
