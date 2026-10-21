export type DiffEntry = { path: string; kind: "added" | "removed" | "changed"; before?: unknown; after?: unknown };

function flatten(value: unknown, prefix: string, out: Map<string, unknown>): void {
  if (Array.isArray(value)) {
    if (value.length === 0) out.set(prefix, []);
    value.forEach((v, i) => flatten(v, `${prefix}[${i}]`, out));
  } else if (value && typeof value === "object") {
    const entries = Object.entries(value as Record<string, unknown>);
    if (entries.length === 0) out.set(prefix, {});
    for (const [k, v] of entries) flatten(v, prefix ? `${prefix}.${k}` : k, out);
  } else {
    out.set(prefix, value);
  }
}

/** Leaf-level diff between two JSON values (paths like `shortcuts[0].url`). */
export function diffJson(before: unknown, after: unknown): DiffEntry[] {
  const a = new Map<string, unknown>();
  const b = new Map<string, unknown>();
  if (before !== undefined && before !== null) flatten(before, "", a);
  if (after !== undefined && after !== null) flatten(after, "", b);
  const out: DiffEntry[] = [];
  for (const [k, v] of b) {
    if (!a.has(k)) out.push({ path: k, kind: "added", after: v });
    else if (JSON.stringify(a.get(k)) !== JSON.stringify(v)) out.push({ path: k, kind: "changed", before: a.get(k), after: v });
  }
  for (const [k, v] of a) if (!b.has(k)) out.push({ path: k, kind: "removed", before: v });
  return out;
}
