import { requirePageAuth } from "@/lib/auth/page-session";
import { listShortcuts } from "@/lib/queries";
import { S } from "@/lib/strings";
import { ShortcutsEditor } from "./ShortcutsEditor";

export default async function ShortcutsPage() {
  await requirePageAuth();
  const items = await listShortcuts();
  return (
    <>
      <h1>{S.shortcuts.title}</h1>
      <p className="muted">{S.shortcuts.hint}</p>
      <ShortcutsEditor items={items} />
    </>
  );
}
