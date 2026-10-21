import { requirePageAuth } from "@/lib/auth/page-session";
import { canEdit, canManageUsers } from "@/lib/auth/roles";
import { AdminProvider } from "@/components/AdminContext";
import { Nav } from "@/components/Nav";

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const { user, session } = await requirePageAuth();
  const info = {
    csrf: session.csrfToken,
    email: user.email,
    role: user.role,
    canEdit: canEdit(user.role),
    isOwner: canManageUsers(user.role),
  };
  return (
    <AdminProvider value={info}>
      <div className="shell">
        <Nav />
        <main className="main">{children}</main>
      </div>
    </AdminProvider>
  );
}
