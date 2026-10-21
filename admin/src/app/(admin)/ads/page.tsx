import { requirePageAuth } from "@/lib/auth/page-session";
import { getAds } from "@/lib/queries";
import { S } from "@/lib/strings";
import { AdsEditor } from "./AdsEditor";

export default async function AdsPage() {
  await requirePageAuth();
  return (
    <>
      <h1>{S.ads.title}</h1>
      <p className="muted">{S.ads.testIdsNote}</p>
      <AdsEditor initial={await getAds()} />
    </>
  );
}
