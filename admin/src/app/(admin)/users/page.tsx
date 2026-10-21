import { requirePageAuth } from "@/lib/auth/page-session";
import { listUsers } from "@/lib/queries";
import { S } from "@/lib/strings";
import { UsersEditor } from "./UsersEditor";

export default async function UsersPage() {
  const { user } = await requirePageAuth("OWNER");
  return (
    <>
      <h1>{S.users.title}</h1>
      <UsersEditor items={await listUsers()} selfId={user.id} />
    </>
  );
}
