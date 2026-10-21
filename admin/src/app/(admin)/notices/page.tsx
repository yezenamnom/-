import { requirePageAuth } from "@/lib/auth/page-session";
import { listNotices } from "@/lib/queries";
import { S } from "@/lib/strings";
import { NoticesEditor } from "./NoticesEditor";

export default async function NoticesPage() {
  await requirePageAuth();
  return (
    <>
      <h1>{S.notices.title}</h1>
      <NoticesEditor items={await listNotices()} />
    </>
  );
}
