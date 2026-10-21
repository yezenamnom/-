import { requirePageAuth } from "@/lib/auth/page-session";
import { listBlocklists } from "@/lib/queries";
import { S } from "@/lib/strings";
import { BlocklistsEditor } from "./BlocklistsEditor";

export default async function BlocklistsPage() {
  await requirePageAuth();
  return (
    <>
      <h1>{S.blocklists.title}</h1>
      <p className="muted">{S.blocklists.hint}</p>
      <BlocklistsEditor items={await listBlocklists()} />
    </>
  );
}
