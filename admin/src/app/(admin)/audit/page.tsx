import Link from "next/link";
import { requirePageAuth } from "@/lib/auth/page-session";
import { listAudit } from "@/lib/queries";
import { S } from "@/lib/strings";

export default async function AuditPage({ searchParams }: { searchParams: Promise<Record<string, string | undefined>> }) {
  await requirePageAuth();
  const sp = await searchParams;
  const page = Math.max(1, Math.min(100_000, Number.parseInt(sp.page ?? "1", 10) || 1));
  const data = await listAudit({ page, pageSize: 50 });
  const pages = Math.max(1, Math.ceil(data.total / data.pageSize));
  return (
    <>
      <h1>{S.audit.title}</h1>
      <table data-testid="audit-table">
        <thead>
          <tr>
            <th>At (UTC)</th>
            <th>Actor</th>
            <th>Action</th>
            <th>Entity</th>
            <th>IP</th>
            <th>Details</th>
          </tr>
        </thead>
        <tbody>
          {data.items.map((a) => (
            <tr key={a.id}>
              <td>{a.at.slice(0, 19).replace("T", " ")}</td>
              <td>{a.actor ?? "—"}</td>
              <td>
                <code>{a.action}</code>
              </td>
              <td>
                {a.entity}
                {a.entityId ? <div className="muted">{a.entityId}</div> : null}
              </td>
              <td>{a.ip ?? ""}</td>
              <td>
                {a.before || a.after ? (
                  <details>
                    <summary>diff</summary>
                    <pre className="json">{JSON.stringify({ before: a.before, after: a.after }, null, 2)}</pre>
                  </details>
                ) : null}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      <div className="row" style={{ marginTop: 12 }}>
        {page > 1 ? (
          <Link className="btn" href={`/audit?page=${page - 1}`}>
            {S.common.prev}
          </Link>
        ) : null}
        <span className="muted">
          {S.common.page} {page} / {pages} ({data.total})
        </span>
        {page < pages ? (
          <Link className="btn" href={`/audit?page=${page + 1}`}>
            {S.common.next}
          </Link>
        ) : null}
      </div>
    </>
  );
}
