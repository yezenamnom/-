"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { api, describeError } from "@/components/api-client";
import { useAdmin } from "@/components/AdminContext";

export function ReportStatusSelect({ id, status }: { id: string; status: "NEW" | "TRIAGED" | "CLOSED" }) {
  const router = useRouter();
  const { csrf, canEdit } = useAdmin();
  const [value, setValue] = useState(status);
  const [error, setError] = useState<string | null>(null);
  if (!canEdit) return <span className={`badge ${status}`}>{status}</span>;
  return (
    <>
      <select
        aria-label="Status"
        value={value}
        onChange={async (e) => {
          const next = e.target.value as typeof status;
          setValue(next);
          const r = await api(`/api/admin/reports/${id}`, { method: "PATCH", csrf, body: { status: next } });
          if (!r.ok) {
            setError(describeError(r));
            setValue(status);
          } else router.refresh();
        }}
      >
        <option value="NEW">NEW</option>
        <option value="TRIAGED">TRIAGED</option>
        <option value="CLOSED">CLOSED</option>
      </select>
      {error ? <div className="bad">{error}</div> : null}
    </>
  );
}
