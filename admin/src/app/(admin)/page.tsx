import { requirePageAuth } from "@/lib/auth/page-session";
import { systemStatus } from "@/lib/queries";
import { S } from "@/lib/strings";

export default async function DashboardPage({ searchParams }: { searchParams: Promise<Record<string, string | undefined>> }) {
  await requirePageAuth();
  const sp = await searchParams;
  const st = await systemStatus();
  return (
    <>
      <h1>{S.dashboard.title}</h1>
      {sp.denied ? <div className="alert error">{S.common.forbidden}</div> : null}
      <div className="grid">
        <div className="card stat">
          <div className="label">{S.dashboard.db}</div>
          <div className={`value ${st.dbOk ? "ok" : "bad"}`} data-testid="db-status">{st.dbOk ? S.dashboard.ok : S.dashboard.down}</div>
        </div>
        <div className="card stat">
          <div className="label">{S.dashboard.signingKey}</div>
          <div className={`value ${st.signingKeyConfigured ? "ok" : "bad"}`} data-testid="signing-key">
            {st.signingKeyConfigured ? S.common.yes : S.common.no}
          </div>
          <div className="muted">
            {S.dashboard.keyId}: {st.keyId}
          </div>
        </div>
        <div className="card stat">
          <div className="label">{S.dashboard.currentConfig}</div>
          <div className="value" data-testid="current-version">{st.current ? `v${st.current.version}` : S.dashboard.noRelease}</div>
          {st.current ? <div className="muted">{new Date(st.current.createdAt).toUTCString()}</div> : null}
        </div>
        <div className="card stat">
          <div className="label">{S.dashboard.openReports}</div>
          <div className="value">{st.openReports ?? "—"}</div>
        </div>
        <div className="card stat">
          <div className="label">{S.dashboard.activeBlocklist}</div>
          <div className="value">{st.activeBlocklist ? `v${st.activeBlocklist.version} (${st.activeBlocklist.ruleCount} rules)` : S.common.none}</div>
        </div>
        <div className="card stat">
          <div className="label">{S.dashboard.admob}</div>
          <div className="value muted" data-testid="admob">{S.dashboard.notConnected}</div>
          <div className="muted">{S.dashboard.admobHint}</div>
        </div>
      </div>
      <h2>{S.dashboard.fetches}</h2>
      {st.fetches ? (
        <table>
          <thead>
            <tr>
              <th>Date (UTC)</th>
              <th>Android</th>
              <th>iOS</th>
              <th>Unknown</th>
              <th>Total</th>
            </tr>
          </thead>
          <tbody>
            {st.fetches.days.map((d) => (
              <tr key={d.date}>
                <td>{d.date}</td>
                <td>{d.android}</td>
                <td>{d.ios}</td>
                <td>{d.unknown}</td>
                <td>{d.total}</td>
              </tr>
            ))}
            <tr>
              <td colSpan={4}>
                <strong>Total</strong>
              </td>
              <td>
                <strong data-testid="fetch-total">{st.fetches.total}</strong>
              </td>
            </tr>
          </tbody>
        </table>
      ) : (
        <p className="muted">—</p>
      )}
    </>
  );
}
