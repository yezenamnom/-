export const ROLES = ["OWNER", "ADMIN", "READONLY"] as const;
export type RoleName = (typeof ROLES)[number];

const RANK: Record<RoleName, number> = { READONLY: 0, ADMIN: 1, OWNER: 2 };

/** READONLY: view only. ADMIN: edit + publish. OWNER: ADMIN + manage admin users. */
export function hasRole(actual: RoleName, required: RoleName): boolean {
  return RANK[actual] >= RANK[required];
}

export const canEdit = (r: RoleName) => hasRole(r, "ADMIN");
export const canManageUsers = (r: RoleName) => hasRole(r, "OWNER");
