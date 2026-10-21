import { redirect } from "next/navigation";
import { optionalPageAuth } from "@/lib/auth/page-session";
import { S } from "@/lib/strings";
import { LoginForm } from "./LoginForm";

export default async function LoginPage() {
  if (await optionalPageAuth()) redirect("/");
  return (
    <div className="login-wrap">
      <div className="card">
        <h1>{S.appName}</h1>
        <LoginForm />
      </div>
    </div>
  );
}
