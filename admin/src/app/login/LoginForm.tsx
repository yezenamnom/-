"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { S } from "@/lib/strings";
import { Feedback, type Msg } from "@/components/Feedback";

export function LoginForm() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<Msg>(null);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setMsg(null);
    try {
      const res = await fetch("/api/admin/auth/login", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ email, password }),
        credentials: "same-origin",
      });
      if (res.ok) {
        router.replace("/");
        router.refresh();
        return;
      }
      const data = (await res.json().catch(() => ({}))) as { message?: string };
      setMsg({ kind: "error", text: data.message ?? S.common.error });
    } catch {
      setMsg({ kind: "error", text: S.common.error });
    } finally {
      setBusy(false);
    }
  }

  return (
    <form onSubmit={submit} noValidate>
      <h2 style={{ marginTop: 0 }}>{S.login.title}</h2>
      <Feedback msg={msg} />
      <div className="field">
        <label htmlFor="email">{S.login.email}</label>
        <input id="email" type="email" autoComplete="username" value={email} onChange={(e) => setEmail(e.target.value)} required />
      </div>
      <div className="field">
        <label htmlFor="password">{S.login.password}</label>
        <input id="password" type="password" autoComplete="current-password" value={password} onChange={(e) => setPassword(e.target.value)} required />
      </div>
      <button className="primary" type="submit" disabled={busy}>
        {busy ? S.common.loading : S.login.submit}
      </button>
    </form>
  );
}
