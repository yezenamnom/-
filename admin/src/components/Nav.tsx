"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useState } from "react";
import { S } from "@/lib/strings";
import { api } from "./api-client";
import { useAdmin } from "./AdminContext";

const LINKS: Array<{ href: string; label: string; ownerOnly?: boolean }> = [
  { href: "/", label: S.nav.dashboard },
  { href: "/shortcuts", label: S.nav.shortcuts },
  { href: "/ads", label: S.nav.ads },
  { href: "/blocklists", label: S.nav.blocklists },
  { href: "/content", label: S.nav.content },
  { href: "/notices", label: S.nav.notices },
  { href: "/publish", label: S.nav.publish },
  { href: "/releases", label: S.nav.releases },
  { href: "/reports", label: S.nav.reports },
  { href: "/audit", label: S.nav.audit },
  { href: "/users", label: S.nav.users, ownerOnly: true },
  { href: "/account", label: S.nav.account },
];

export function Nav() {
  const pathname = usePathname();
  const router = useRouter();
  const admin = useAdmin();
  const [busy, setBusy] = useState(false);

  async function logout() {
    setBusy(true);
    await api("/api/admin/auth/logout", { method: "POST", csrf: admin.csrf });
    router.replace("/login");
    router.refresh();
  }

  return (
    <nav className="sidebar" aria-label="Main">
      <div className="brand">{S.appName}</div>
      {LINKS.filter((l) => !l.ownerOnly || admin.isOwner).map((l) => (
        <Link key={l.href} href={l.href} aria-current={pathname === l.href ? "page" : undefined}>
          {l.label}
        </Link>
      ))}
      <div className="who">
        <div data-testid="current-user">{admin.email}</div>
        <div>
          Role: <strong data-testid="current-role">{admin.role}</strong>
        </div>
        <button type="button" onClick={logout} disabled={busy} style={{ marginTop: 8 }} data-testid="logout">
          {S.nav.logout}
        </button>
      </div>
    </nav>
  );
}
