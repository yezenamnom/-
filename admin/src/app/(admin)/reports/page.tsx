import Link from "next/link";
import { requirePageAuth } from "@/lib/auth/page-session";
import { listReports } from "@/lib/queries";
import { S } from "@/lib/strings";
import { ReportStatusSelect } from "./ReportStatusSelect";

const STATUSES = ["NEW", "TRIAGED", "CLOSED"] as const;

export default async function ReportsPage({ searchParams }: { searchParams: Promise<Record<string, string | undefined>> }) {
  await requirePageAuth();
  const sp = await searchParams;
  const status = STATUSES.find((s) => s === sp.status);
  const page = Math.max(1, Math.min(100_000, Number.parseInt(sp.page ?? "1", 10) || 1));
  const data = await listReports({ status, page, pageSize: 50 });
  const pages = Math.max(1, Math.ceil(data.total / data.pageSize));
  const q = (p: number) => `/reports?${new URLSearchParams({ ...(status ? { status } : {}), page: String(p) })}`;
  return (
    <>
      <h1>{S.reports.title}</h1>
      <div className="row" style={{ marginBottom: 12 }}>
        <Link className="btn" href="/reports">
          {S.reports.all}
        </Link>
        {STATUSES.map((s) => (
          <Link key={s} className="btn" href={`/reports?status=${s}`}>
            {s}
          </Link>
        ))}
        <span className="muted">{data.total} total</span>
      </div>
      <table>
        <thead>
          <tr>
            <th>Created</th>
            <th>Category</th>
            <th>Message</th>
            <th>App</th>
            <th>Site</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          {data.items.length === 0 ? (
            <tr>
              <td colSpan={6} className="muted">
                {S.common.none}
              </td>
            </tr>
          ) : null}
          {data.items.map((r) => (
            <tr key={r.id}>
              <td>{r.createdAt.slice(0, 16).replace("T", " ")}</td>
              <td>{r.category}</td>
              <td style={{ whiteSpace: "pre-wrap", maxWidth: 420 }}>{r.message}</td>
              <td>
                {r.platform} {r.appVersion}
                <div className="muted">{r.locale}</div>
              </td>
              <td>{r.siteHost ?? "—"}</td>
              <td>
                <ReportStatusSelect id={r.id} status={r.status} />
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      <div className="row" style={{ marginTop: 12 }}>
        {page > 1 ? (
          <Link className="btn" href={q(page - 1)}>
            {S.common.prev}
          </Link>
        ) : null}
        <span className="muted">
          {S.common.page} {page} / {pages}
        </span>
        {page < pages ? (
          <Link className="btn" href={q(page + 1)}>
            {S.common.next}
          </Link>
        ) : null}
      </div>
    </>
  );
}
