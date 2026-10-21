import { requirePageAuth } from "@/lib/auth/page-session";
import { getContent } from "@/lib/queries";
import { S } from "@/lib/strings";
import { ContentEditor } from "./ContentEditor";

export default async function ContentPage() {
  await requirePageAuth();
  return (
    <>
      <h1>{S.content.title}</h1>
      <ContentEditor initial={await getContent()} />
    </>
  );
}
