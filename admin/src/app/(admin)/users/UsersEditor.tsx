"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { S } from "@/lib/strings";
import type { UserRow } from "@/lib/queries";
import { api, describeError } from "@/components/api-client";
import { useAdmin } from "@/components/AdminContext";
import { Feedback, type Msg } from "@/components/Feedback";

const ROLES = ["OWNER", "ADMIN", "READONLY"] as const;

export function UsersEditor({ items, selfId }: { items: UserRow[]; selfId: string }) {
  const router = useRouter();
  const { csrf } = useAdmin();
  const [msg, setMsg] = useState<Msg>(null);
  const [email, setEmail] = useState("");
  const [role, setRole] = useState<(typeof ROLES)[number]>("READONLY");
  const [password, setPassword] = useState("");

  async function patch(id: string, body: Record<string, unknown>) {
    const r = await api(`/api/admin/users/${id}`, { method: "PATCH", csrf, body });
    setMsg(r.ok ? { kind: "success", text: S.common.saved } : { kind: "error", text: describeError(r) });
    if (r.ok) router.refresh();
  }

  async function create(e: React.FormEvent) {
    e.preventDefault();
    const r = await api("/api/admin/users", { method: "POST", csrf, body: { email, role, password } });
    if (!r.ok) return setMsg({ kind: "error", text: describeError(r) });
    setMsg({ kind: "success", text: S.common.saved });
    setEmail("");
    setPassword("");
    router.refresh();
  }

  return (
    <>
      <Feedback msg={msg} />
      <table>
        <thead>
          <tr>
            <th>{S.users.email}</th>
            <th>{S.users.role}</th>
            <th>Status</th>
            <th>Last login</th>
            <th />
          </tr>
        </thead>
        <tbody>
          {items.map((u) => (
            <tr key={u.id}>
              <td>{u.email}</td>
              <td>
                <select aria-label={S.users.role} value={u.role} onChange={(e) => patch(u.id, { role: e.target.value })}>
                  {ROLES.map((r) => (
                    <option key={r} value={r}>
                      {r}
                    </option>
                  ))}
                </select>
              </td>
              <td>
                {u.disabled ? <span className="bad">{S.common.disabled}</span> : <span className="ok">{S.common.active}</span>}
                {u.lockedUntil ? <div className="warn">{S.users.locked}</div> : null}
              </td>
              <td>{u.lastLoginAt ? u.lastLoginAt.slice(0, 16).replace("T", " ") : "—"}</td>
              <td>
                <div className="row">
                  {u.id !== selfId ? (
                    <button type="button" onClick={() => patch(u.id, { disabled: !u.disabled })}>
                      {u.disabled ? S.users.enable : S.users.disable}
                    </button>
                  ) : null}
                  {u.lockedUntil ? (
                    <button type="button" onClick={() => patch(u.id, { unlock: true })}>
                      {S.users.unlock}
                    </button>
                  ) : null}
                  <button
                    type="button"
                    onClick={() => {
                      const pw = window.prompt(S.users.password);
                      if (pw) void patch(u.id, { password: pw });
                    }}
                  >
                    {S.users.resetPassword}
                  </button>
                </div>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      <form className="card" onSubmit={create} style={{ marginTop: 16 }}>
        <h2 style={{ marginTop: 0 }}>{S.users.new}</h2>
        <div className="cols">
          <div className="field">
            <label htmlFor="u-email">{S.users.email}</label>
            <input id="u-email" type="email" autoComplete="off" value={email} onChange={(e) => setEmail(e.target.value)} />
          </div>
          <div className="field">
            <label htmlFor="u-role">{S.users.role}</label>
            <select id="u-role" value={role} onChange={(e) => setRole(e.target.value as (typeof ROLES)[number])}>
              {ROLES.map((r) => (
                <option key={r} value={r}>
                  {r}
                </option>
              ))}
            </select>
          </div>
          <div className="field">
            <label htmlFor="u-pw">{S.users.password}</label>
            <input id="u-pw" type="password" autoComplete="new-password" value={password} onChange={(e) => setPassword(e.target.value)} />
          </div>
        </div>
        <button className="primary" type="submit">
          {S.common.create}
        </button>
      </form>
    </>
  );
}
