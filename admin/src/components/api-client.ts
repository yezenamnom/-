"use client";

export type ApiResult<T = unknown> = { ok: true; status: number; data: T } | { ok: false; status: number; error: string; message: string; details?: unknown };

/** Browser → /api/admin/* helper. Adds the per-session CSRF header to every non-GET call. */
export async function api<T = unknown>(path: string, opts: { method?: string; body?: unknown; csrf: string; form?: FormData }): Promise<ApiResult<T>> {
  const method = opts.method ?? "GET";
  const headers: Record<string, string> = {};
  if (method !== "GET") headers["x-csrf-token"] = opts.csrf;
  let body: BodyInit | undefined;
  if (opts.form) body = opts.form;
  else if (opts.body !== undefined) {
    headers["content-type"] = "application/json";
    body = JSON.stringify(opts.body);
  }
  let res: Response;
  try {
    res = await fetch(path, { method, headers, body, credentials: "same-origin", cache: "no-store" });
  } catch {
    return { ok: false, status: 0, error: "network", message: "Network error" };
  }
  let data: unknown = null;
  try {
    data = await res.json();
  } catch {
    data = null;
  }
  if (res.ok) return { ok: true, status: res.status, data: data as T };
  const d = (data ?? {}) as { error?: string; message?: string; details?: unknown };
  if (res.status === 401 && typeof window !== "undefined") window.location.href = "/login";
  return { ok: false, status: res.status, error: d.error ?? "error", message: d.message ?? d.error ?? `HTTP ${res.status}`, details: d.details };
}

export function describeError(r: { message: string; details?: unknown }): string {
  if (Array.isArray(r.details) && r.details.length) {
    const lines = r.details.slice(0, 15).map((d) =>
      typeof d === "string" ? d : `${(d as { path?: string }).path ? `${(d as { path: string }).path}: ` : ""}${(d as { message?: string }).message ?? ""}`,
    );
    return `${r.message}\n${lines.join("\n")}`;
  }
  return r.message;
}
