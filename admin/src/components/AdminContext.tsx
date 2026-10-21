"use client";

import { createContext, useContext } from "react";
import type { RoleName } from "@/lib/auth/roles";

export type AdminInfo = { csrf: string; email: string; role: RoleName; canEdit: boolean; isOwner: boolean };

const Ctx = createContext<AdminInfo | null>(null);

export function AdminProvider({ value, children }: { value: AdminInfo; children: React.ReactNode }) {
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useAdmin(): AdminInfo {
  const v = useContext(Ctx);
  if (!v) throw new Error("useAdmin outside AdminProvider");
  return v;
}
