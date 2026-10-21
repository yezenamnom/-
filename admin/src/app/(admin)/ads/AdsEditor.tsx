"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { S } from "@/lib/strings";
import { LIMITS, PLACEMENT_FORMAT, PLACEMENT_IDS } from "@/lib/config-schema";
import type { AdsView } from "@/lib/queries";
import { api, describeError } from "@/components/api-client";
import { useAdmin } from "@/components/AdminContext";
import { Feedback, type Msg } from "@/components/Feedback";

export function AdsEditor({ initial }: { initial: AdsView }) {
  const router = useRouter();
  const { csrf, canEdit } = useAdmin();
  const [state, setState] = useState(() => ({
    globalEnabled: initial.globalEnabled,
    minInterval: String(initial.frequency.interstitialMinIntervalSec),
    maxPerSession: String(initial.frequency.interstitialMaxPerSession),
    placements: PLACEMENT_IDS.map(
      (key) =>
        initial.placements.find((p) => p.key === key) ?? { key, format: PLACEMENT_FORMAT[key], enabled: false, adUnitIdAndroid: "", adUnitIdIos: "" },
    ),
  }));
  const [msg, setMsg] = useState<Msg>(null);
  const [busy, setBusy] = useState(false);

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    const r = await api("/api/admin/ads", {
      method: "PUT",
      csrf,
      body: {
        globalEnabled: state.globalEnabled,
        frequency: { interstitialMinIntervalSec: Number(state.minInterval), interstitialMaxPerSession: Number(state.maxPerSession) },
        placements: state.placements.map((p) => ({ key: p.key, enabled: p.enabled, adUnitIdAndroid: p.adUnitIdAndroid, adUnitIdIos: p.adUnitIdIos })),
      },
    });
    setBusy(false);
    setMsg(r.ok ? { kind: "success", text: S.common.saved } : { kind: "error", text: describeError(r) });
    if (r.ok) router.refresh();
  }

  const setP = (i: number, patch: Partial<(typeof state.placements)[number]>) =>
    setState({ ...state, placements: state.placements.map((p, j) => (j === i ? { ...p, ...patch } : p)) });

  return (
    <form onSubmit={save}>
      <Feedback msg={msg} />
      {!canEdit ? <div className="alert info">{S.common.readOnly}</div> : null}
      <fieldset disabled={!canEdit} style={{ border: 0, padding: 0, margin: 0 }}>
        <div className="card">
          <label className="check">
            <input type="checkbox" checked={state.globalEnabled} onChange={(e) => setState({ ...state, globalEnabled: e.target.checked })} />
            {S.ads.global}
          </label>
        </div>
        <div className="card">
          <h2 style={{ marginTop: 0 }}>{S.ads.frequency}</h2>
          <div className="cols">
            <div className="field">
              <label htmlFor="ad-min">{S.ads.minInterval}</label>
              <input
                id="ad-min"
                type="number"
                min={LIMITS.interstitialMinIntervalSecMin}
                max={LIMITS.interstitialMinIntervalSecMax}
                value={state.minInterval}
                onChange={(e) => setState({ ...state, minInterval: e.target.value })}
              />
            </div>
            <div className="field">
              <label htmlFor="ad-max">{S.ads.maxPerSession}</label>
              <input
                id="ad-max"
                type="number"
                min={LIMITS.interstitialMaxPerSessionMin}
                max={LIMITS.interstitialMaxPerSessionMax}
                value={state.maxPerSession}
                onChange={(e) => setState({ ...state, maxPerSession: e.target.value })}
              />
            </div>
          </div>
        </div>
        <h2>{S.ads.placements}</h2>
        {state.placements.map((p, i) => (
          <div className="card" key={p.key}>
            <div className="row" style={{ justifyContent: "space-between" }}>
              <strong>
                {p.key} <span className="muted">({p.format})</span>
              </strong>
              <label className="check">
                <input type="checkbox" checked={p.enabled} onChange={(e) => setP(i, { enabled: e.target.checked })} /> {S.common.enabled}
              </label>
            </div>
            <div className="cols" style={{ marginTop: 8 }}>
              <div className="field">
                <label htmlFor={`${p.key}-a`}>{S.ads.android}</label>
                <input id={`${p.key}-a`} type="text" value={p.adUnitIdAndroid} onChange={(e) => setP(i, { adUnitIdAndroid: e.target.value })} placeholder="ca-app-pub-0000000000000000/0000000000" />
              </div>
              <div className="field">
                <label htmlFor={`${p.key}-i`}>{S.ads.ios}</label>
                <input id={`${p.key}-i`} type="text" value={p.adUnitIdIos} onChange={(e) => setP(i, { adUnitIdIos: e.target.value })} placeholder="ca-app-pub-0000000000000000/0000000000" />
              </div>
            </div>
          </div>
        ))}
        {canEdit ? (
          <button className="primary" type="submit" disabled={busy}>
            {busy ? S.common.loading : S.common.save}
          </button>
        ) : null}
      </fieldset>
    </form>
  );
}
