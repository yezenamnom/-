import { requirePageAuth } from "@/lib/auth/page-session";
import { S } from "@/lib/strings";
import { PasswordForm } from "./PasswordForm";

export default async function AccountPage() {
  const { user, session } = await requirePageAuth();
  return (
    <>
      <h1>{S.account.title}</h1>
      <div className="card">
        <div>{user.email}</div>
        <div className="muted">
          {user.role} · session expires {session.expiresAt.toISOString().slice(0, 16).replace("T", " ")} UTC (or after 12h idle)
        </div>
      </div>
      <PasswordForm />
    </>
  );
}
