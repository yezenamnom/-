import { LOCALES, type Locale } from "./config-schema";

export type LocalizedInput = Partial<Record<Locale, string>>;

/** Normalise stored localized JSON: keep only known locales with non-blank strings (trimmed). */
export function cleanLocalized(value: unknown): LocalizedInput {
  const out: LocalizedInput = {};
  if (value && typeof value === "object" && !Array.isArray(value)) {
    for (const l of LOCALES) {
      const v = (value as Record<string, unknown>)[l];
      if (typeof v === "string" && v.trim()) out[l] = v.trim();
    }
  }
  return out;
}
