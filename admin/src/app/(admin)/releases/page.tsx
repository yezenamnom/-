import { requirePageAuth } from "@/lib/auth/page-session";
import { listReleases } from "@/lib/queries";
import { S } from "@/lib/strings";
import { ReleasesTable } from "./ReleasesTable";

export default async function ReleasesPage() {
  await requirePageAuth();
  return (
    <>
      <h1>{S.releases.title}</h1>
      <ReleasesTable items={await listReleases(200)} />
    </>
  );
}
