/** Read-side helpers shared by admin API GET routes and server-rendered admin pages. */
import { prisma } from "./db";
import { cleanLocalized } from "./localized";
import { configFetchesLastDays, getSigningKey } from "./config-serve";
import { signingKeyId } from "./env";

export async function listShortcuts() {
  const rows = await prisma.shortcut.findMany({ orderBy: [{ order: "asc" }, { key: "asc" }] });
  return rows.map((s) => ({
    id: s.id,
    key: s.key,
    titles: cleanLocalized(s.titles),
    url: s.url,
    iconKey: s.iconKey,
    iconAssetId: s.iconAssetId,
    color: s.color,
    order: s.order,
    enabled: s.enabled,
    updatedAt: s.updatedAt.toISOString(),
  }));
}
export type ShortcutRow = Awaited<ReturnType<typeof listShortcuts>>[number];

export async function getAds() {
  const [settings, placements] = await Promise.all([
    prisma.adSettings.findUnique({ where: { id: 1 } }),
    prisma.adPlacement.findMany({ orderBy: { key: "asc" } }),
  ]);
  return {
    globalEnabled: settings?.globalEnabled ?? false,
    frequency: {
      interstitialMinIntervalSec: settings?.interstitialMinIntervalSec ?? 600,
      interstitialMaxPerSession: settings?.interstitialMaxPerSession ?? 1,
    },
    placements: placements.map((p) => ({
      key: p.key,
      format: p.format,
      enabled: p.enabled,
      adUnitIdAndroid: p.adUnitIdAndroid,
      adUnitIdIos: p.adUnitIdIos,
    })),
  };
}
export type AdsView = Awaited<ReturnType<typeof getAds>>;

export async function listBlocklists() {
  const rows = await prisma.blockList.findMany({
    orderBy: { version: "desc" },
    select: {
      id: true,
      version: true,
      name: true,
      license: true,
      sha256: true,
      ruleCount: true,
      status: true,
      createdAt: true,
      activatedAt: true,
      createdBy: { select: { email: true } },
    },
  });
  return rows.map((r) => ({
    ...r,
    createdAt: r.createdAt.toISOString(),
    activatedAt: r.activatedAt?.toISOString() ?? null,
    createdBy: r.createdBy?.email ?? null,
  }));
}
export type BlocklistRow = Awaited<ReturnType<typeof listBlocklists>>[number];

export async function getContent() {
  const c = await prisma.contentSettings.findUnique({ where: { id: 1 } });
  return {
    privacyUrl: c?.privacyUrl ?? "",
    termsUrl: c?.termsUrl ?? "",
    supportUrl: c?.supportUrl ?? "",
    helpText: cleanLocalized(c?.helpText),
    minAppVersion: c?.minAppVersion ?? null,
    maxAppVersion: c?.maxAppVersion ?? null,
    blockingEnabledByDefault: c?.blockingEnabledByDefault ?? true,
  };
}
export type ContentView = Awaited<ReturnType<typeof getContent>>;

export async function listNotices() {
  const rows = await prisma.notice.findMany({ orderBy: [{ createdAt: "asc" }, { key: "asc" }] });
  return rows.map((n) => ({
    id: n.id,
    key: n.key,
    severity: n.severity,
    message: cleanLocalized(n.message),
    minAppVersion: n.minAppVersion,
    maxAppVersion: n.maxAppVersion,
    active: n.active,
  }));
}
export type NoticeRow = Awaited<ReturnType<typeof listNotices>>[number];

export async function listReleases(take = 100) {
  const rows = await prisma.configRelease.findMany({
    orderBy: { version: "desc" },
    take,
    select: {
      version: true,
      note: true,
      createdAt: true,
      rolledBackFromVersion: true,
      isCurrent: true,
      createdBy: { select: { email: true } },
    },
  });
  return rows.map((r) => ({ ...r, createdAt: r.createdAt.toISOString(), createdBy: r.createdBy?.email ?? null }));
}
export type ReleaseRow = Awaited<ReturnType<typeof listReleases>>[number];

export async function listReports(opts: { status?: "NEW" | "TRIAGED" | "CLOSED"; page: number; pageSize: number }) {
  const where = opts.status ? { status: opts.status } : {};
  const [total, rows] = await Promise.all([
    prisma.userReport.count({ where }),
    prisma.userReport.findMany({
      where,
      orderBy: { createdAt: "desc" },
      skip: (opts.page - 1) * opts.pageSize,
      take: opts.pageSize,
    }),
  ]);
  return {
    total,
    page: opts.page,
    pageSize: opts.pageSize,
    items: rows.map((r) => ({ ...r, createdAt: r.createdAt.toISOString(), updatedAt: r.updatedAt.toISOString() })),
  };
}
export type ReportRow = Awaited<ReturnType<typeof listReports>>["items"][number];

export async function listAudit(opts: { page: number; pageSize: number }) {
  const [total, rows] = await Promise.all([
    prisma.auditLog.count(),
    prisma.auditLog.findMany({
      orderBy: { at: "desc" },
      skip: (opts.page - 1) * opts.pageSize,
      take: opts.pageSize,
      include: { actor: { select: { email: true } } },
    }),
  ]);
  return {
    total,
    page: opts.page,
    pageSize: opts.pageSize,
    items: rows.map((r) => ({
      id: r.id,
      at: r.at.toISOString(),
      actor: r.actor?.email ?? null,
      action: r.action,
      entity: r.entity,
      entityId: r.entityId,
      before: r.before,
      after: r.after,
      ip: r.ip,
    })),
  };
}
export type AuditRow = Awaited<ReturnType<typeof listAudit>>["items"][number];

export async function listUsers() {
  const rows = await prisma.adminUser.findMany({
    orderBy: { createdAt: "asc" },
    select: { id: true, email: true, role: true, disabled: true, lockedUntil: true, createdAt: true, lastLoginAt: true },
  });
  return rows.map((u) => ({
    ...u,
    lockedUntil: u.lockedUntil && u.lockedUntil > new Date() ? u.lockedUntil.toISOString() : null,
    createdAt: u.createdAt.toISOString(),
    lastLoginAt: u.lastLoginAt?.toISOString() ?? null,
  }));
}
export type UserRow = Awaited<ReturnType<typeof listUsers>>[number];

export async function systemStatus() {
  let dbOk = false;
  try {
    await prisma.$queryRaw`SELECT 1`;
    dbOk = true;
  } catch {
    dbOk = false;
  }
  if (!dbOk) {
    return { dbOk, signingKeyConfigured: getSigningKey() !== null, keyId: signingKeyId(), current: null, fetches: null, openReports: null, activeBlocklist: null };
  }
  const [current, fetches, openReports, activeBlocklist] = await Promise.all([
    prisma.configRelease.findFirst({ where: { isCurrent: true }, select: { version: true, createdAt: true, note: true } }),
    configFetchesLastDays(7),
    prisma.userReport.count({ where: { status: { not: "CLOSED" } } }),
    prisma.blockList.findFirst({ where: { status: "ACTIVE" }, select: { version: true, ruleCount: true } }),
  ]);
  return {
    dbOk,
    signingKeyConfigured: getSigningKey() !== null,
    keyId: signingKeyId(),
    current: current ? { version: current.version, createdAt: current.createdAt.toISOString(), note: current.note } : null,
    fetches,
    openReports,
    activeBlocklist,
  };
}
export type SystemStatus = Awaited<ReturnType<typeof systemStatus>>;
