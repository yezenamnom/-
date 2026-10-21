/**
 * Draft building, publishing and rollback of config releases.
 * The draft is validated with the SAME schema (releaseContentSchema) used at signing time.
 */
import { Prisma, type PrismaClient } from "@prisma/client";
import { prisma } from "./db";
import { audit } from "./audit";
import { PLACEMENT_IDS, releaseContentSchema, SCHEMA_VERSION, type ReleaseContent } from "./config-schema";
import { cleanLocalized } from "./localized";
import { HttpError, zodIssues } from "./http";

type Tx = Prisma.TransactionClient | PrismaClient;

/** Assemble the (unvalidated) release content from the current tables. */
export async function assembleDraft(tx: Tx, configVersion: number): Promise<{ content: unknown; problems: string[] }> {
  const problems: string[] = [];
  const [shortcuts, adSettings, placements, activeList, content, notices] = await Promise.all([
    tx.shortcut.findMany({ where: { enabled: true }, orderBy: [{ order: "asc" }, { key: "asc" }] }),
    tx.adSettings.findUnique({ where: { id: 1 } }),
    tx.adPlacement.findMany(),
    tx.blockList.findFirst({ where: { status: "ACTIVE" } }),
    tx.contentSettings.findUnique({ where: { id: 1 } }),
    tx.notice.findMany({ where: { active: true }, orderBy: [{ createdAt: "asc" }, { key: "asc" }] }),
  ]);
  if (!adSettings) problems.push("Ad settings are missing (run the seed).");
  if (!activeList) problems.push("No ACTIVE blocklist. Activate a blocklist version before publishing.");
  if (!content) problems.push("Content settings are missing (privacy/terms/support URLs).");

  const placementOrder = (k: string) => PLACEMENT_IDS.indexOf(k as (typeof PLACEMENT_IDS)[number]);
  const draft = {
    schemaVersion: SCHEMA_VERSION,
    configVersion,
    minAppVersion: content?.minAppVersion ?? null,
    maxAppVersion: content?.maxAppVersion ?? null,
    shortcuts: shortcuts.map((s, i) => ({
      id: s.key,
      title: cleanLocalized(s.titles),
      url: s.url,
      iconKey: s.iconKey,
      iconAssetId: s.iconAssetId,
      color: s.color,
      order: i,
    })),
    ads: {
      enabled: adSettings?.globalEnabled ?? false,
      placements: [...placements]
        .sort((a, b) => placementOrder(a.key) - placementOrder(b.key))
        .map((p) => ({
          id: p.key,
          format: p.format,
          enabled: p.enabled,
          adUnitIdAndroid: p.adUnitIdAndroid,
          adUnitIdIos: p.adUnitIdIos,
        })),
      frequency: {
        interstitialMinIntervalSec: adSettings?.interstitialMinIntervalSec ?? 600,
        interstitialMaxPerSession: adSettings?.interstitialMaxPerSession ?? 1,
      },
    },
    blocking: activeList
      ? {
          enabledByDefault: content?.blockingEnabledByDefault ?? true,
          listVersion: activeList.version,
          listPath: `/api/v1/blocklists/${activeList.version}`,
          listSha256: activeList.sha256,
          ruleCount: activeList.ruleCount,
        }
      : null,
    content: content
      ? {
          privacyUrl: content.privacyUrl,
          termsUrl: content.termsUrl,
          supportUrl: content.supportUrl,
          helpText: cleanLocalized(content.helpText),
        }
      : null,
    notices: notices.map((n) => ({
      id: n.key,
      severity: n.severity,
      message: cleanLocalized(n.message),
      minAppVersion: n.minAppVersion,
      maxAppVersion: n.maxAppVersion,
    })),
  };
  return { content: draft, problems };
}

export type DraftValidation =
  | { ok: true; content: ReleaseContent }
  | { ok: false; content: unknown; issues: Array<{ path: string; message: string }> };

export function validateDraft(content: unknown, problems: string[] = []): DraftValidation {
  const parsed = releaseContentSchema.safeParse(content);
  if (parsed.success && problems.length === 0) return { ok: true, content: parsed.data };
  return {
    ok: false,
    content,
    issues: [
      ...problems.map((message) => ({ path: "", message })),
      ...(parsed.success ? [] : zodIssues(parsed.error)),
    ],
  };
}

export async function getCurrentRelease(tx: Tx = prisma) {
  return tx.configRelease.findFirst({ where: { isCurrent: true } });
}

async function nextVersion(tx: Tx): Promise<number> {
  const agg = await tx.configRelease.aggregate({ _max: { version: true } });
  return (agg._max.version ?? 0) + 1;
}

export async function previewDraft() {
  const version = await nextVersion(prisma);
  const { content, problems } = await assembleDraft(prisma, version);
  const validation = validateDraft(content, problems);
  const current = await getCurrentRelease();
  return { nextVersion: version, validation, current };
}

const MAX_RETRIES = 3;

async function withSerializableRetry<T>(fn: (tx: Prisma.TransactionClient) => Promise<T>): Promise<T> {
  for (let attempt = 0; ; attempt++) {
    try {
      return await prisma.$transaction(fn, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    } catch (e) {
      const retryable =
        e instanceof Prisma.PrismaClientKnownRequestError && (e.code === "P2034" || e.code === "P2002");
      if (!retryable || attempt >= MAX_RETRIES) throw e;
    }
  }
}

async function storeRelease(
  tx: Prisma.TransactionClient,
  content: ReleaseContent,
  meta: { note: string; actorId: string; rolledBackFromVersion: number | null },
) {
  const previous = await getCurrentRelease(tx);
  await tx.configRelease.updateMany({ where: { isCurrent: true }, data: { isCurrent: false } });
  const release = await tx.configRelease.create({
    data: {
      version: content.configVersion,
      contentJson: JSON.stringify(content),
      note: meta.note,
      createdById: meta.actorId,
      rolledBackFromVersion: meta.rolledBackFromVersion,
      isCurrent: true,
    },
  });
  return { release, previousVersion: previous?.version ?? null };
}

export async function publishRelease(input: { actorId: string; note: string; ip: string }) {
  return withSerializableRetry(async (tx) => {
    const version = await nextVersion(tx);
    const { content, problems } = await assembleDraft(tx, version);
    const v = validateDraft(content, problems);
    if (!v.ok) throw new HttpError(422, "draft_invalid", "The draft config is invalid", v.issues);
    const { release, previousVersion } = await storeRelease(tx, v.content, {
      note: input.note,
      actorId: input.actorId,
      rolledBackFromVersion: null,
    });
    await audit(
      {
        actorId: input.actorId,
        action: "config.publish",
        entity: "ConfigRelease",
        entityId: String(release.version),
        before: previousVersion === null ? null : { version: previousVersion },
        after: { version: release.version, note: input.note },
        ip: input.ip,
      },
      tx,
    );
    return release;
  });
}

/** Rollback = publish a NEW version whose content equals an older release (apps reject lower versions). */
export async function rollbackRelease(input: { fromVersion: number; actorId: string; note: string; ip: string }) {
  return withSerializableRetry(async (tx) => {
    const source = await tx.configRelease.findUnique({ where: { version: input.fromVersion } });
    if (!source) throw new HttpError(404, "release_not_found");
    const version = await nextVersion(tx);
    const old = JSON.parse(source.contentJson) as Record<string, unknown>;
    const v = validateDraft({ ...old, configVersion: version });
    if (!v.ok) throw new HttpError(422, "release_invalid", "The old release no longer validates", v.issues);
    const { release, previousVersion } = await storeRelease(tx, v.content, {
      note: input.note || `Rollback to content of v${source.version}`,
      actorId: input.actorId,
      rolledBackFromVersion: source.version,
    });
    await audit(
      {
        actorId: input.actorId,
        action: "config.rollback",
        entity: "ConfigRelease",
        entityId: String(release.version),
        before: previousVersion === null ? null : { version: previousVersion },
        after: { version: release.version, rolledBackFromVersion: source.version },
        ip: input.ip,
      },
      tx,
    );
    return release;
  });
}
