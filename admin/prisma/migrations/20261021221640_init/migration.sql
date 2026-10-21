-- CreateEnum
CREATE TYPE "Role" AS ENUM ('OWNER', 'ADMIN', 'READONLY');

-- CreateEnum
CREATE TYPE "BlockListStatus" AS ENUM ('DRAFT', 'ACTIVE', 'ARCHIVED');

-- CreateEnum
CREATE TYPE "ReportStatus" AS ENUM ('NEW', 'TRIAGED', 'CLOSED');

-- CreateEnum
CREATE TYPE "NoticeSeverity" AS ENUM ('info', 'update');

-- CreateEnum
CREATE TYPE "PlacementKey" AS ENUM ('home_banner', 'downloads_banner', 'tabs_interstitial');

-- CreateEnum
CREATE TYPE "AdFormat" AS ENUM ('banner', 'interstitial');

-- CreateEnum
CREATE TYPE "ReportCategory" AS ENUM ('site_broken', 'blocking_issue', 'video_issue', 'ads_issue', 'other');

-- CreateEnum
CREATE TYPE "Platform" AS ENUM ('android', 'ios', 'unknown');

-- CreateTable
CREATE TABLE "AdminUser" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "passwordHash" TEXT NOT NULL,
    "role" "Role" NOT NULL DEFAULT 'READONLY',
    "disabled" BOOLEAN NOT NULL DEFAULT false,
    "failedLoginCount" INTEGER NOT NULL DEFAULT 0,
    "lockedUntil" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "lastLoginAt" TIMESTAMP(3),

    CONSTRAINT "AdminUser_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Session" (
    "id" TEXT NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "csrfToken" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "lastSeenAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "userAgent" TEXT,

    CONSTRAINT "Session_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "LoginAttempt" (
    "id" TEXT NOT NULL,
    "ip" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "success" BOOLEAN NOT NULL,
    "at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "LoginAttempt_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Shortcut" (
    "id" TEXT NOT NULL,
    "key" TEXT NOT NULL,
    "titles" JSONB NOT NULL,
    "url" TEXT NOT NULL,
    "iconKey" TEXT,
    "iconAssetId" TEXT,
    "color" TEXT NOT NULL,
    "order" INTEGER NOT NULL DEFAULT 0,
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Shortcut_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Asset" (
    "id" TEXT NOT NULL,
    "bytes" BYTEA NOT NULL,
    "mime" TEXT NOT NULL,
    "sha256" TEXT NOT NULL,
    "width" INTEGER NOT NULL,
    "height" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Asset_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AdSettings" (
    "id" INTEGER NOT NULL DEFAULT 1,
    "globalEnabled" BOOLEAN NOT NULL DEFAULT true,
    "interstitialMinIntervalSec" INTEGER NOT NULL DEFAULT 600,
    "interstitialMaxPerSession" INTEGER NOT NULL DEFAULT 1,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AdSettings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AdPlacement" (
    "id" TEXT NOT NULL,
    "key" "PlacementKey" NOT NULL,
    "format" "AdFormat" NOT NULL,
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "adUnitIdAndroid" TEXT NOT NULL DEFAULT '',
    "adUnitIdIos" TEXT NOT NULL DEFAULT '',
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AdPlacement_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "BlockList" (
    "id" TEXT NOT NULL,
    "version" INTEGER NOT NULL,
    "name" TEXT NOT NULL,
    "license" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "sha256" TEXT NOT NULL,
    "ruleCount" INTEGER NOT NULL,
    "status" "BlockListStatus" NOT NULL DEFAULT 'DRAFT',
    "createdById" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "activatedAt" TIMESTAMP(3),

    CONSTRAINT "BlockList_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ContentSettings" (
    "id" INTEGER NOT NULL DEFAULT 1,
    "privacyUrl" TEXT NOT NULL,
    "termsUrl" TEXT NOT NULL,
    "supportUrl" TEXT NOT NULL,
    "helpText" JSONB NOT NULL,
    "minAppVersion" TEXT,
    "maxAppVersion" TEXT,
    "blockingEnabledByDefault" BOOLEAN NOT NULL DEFAULT true,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ContentSettings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Notice" (
    "id" TEXT NOT NULL,
    "key" TEXT NOT NULL,
    "severity" "NoticeSeverity" NOT NULL DEFAULT 'info',
    "message" JSONB NOT NULL,
    "minAppVersion" TEXT,
    "maxAppVersion" TEXT,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Notice_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ConfigRelease" (
    "id" TEXT NOT NULL,
    "version" INTEGER NOT NULL,
    "contentJson" TEXT NOT NULL,
    "note" TEXT NOT NULL DEFAULT '',
    "createdById" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "rolledBackFromVersion" INTEGER,
    "isCurrent" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "ConfigRelease_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AuditLog" (
    "id" TEXT NOT NULL,
    "actorId" TEXT,
    "action" TEXT NOT NULL,
    "entity" TEXT NOT NULL,
    "entityId" TEXT,
    "before" JSONB,
    "after" JSONB,
    "ip" TEXT,
    "at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AuditLog_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "UserReport" (
    "id" TEXT NOT NULL,
    "category" "ReportCategory" NOT NULL,
    "message" TEXT NOT NULL,
    "appVersion" TEXT NOT NULL,
    "platform" "Platform" NOT NULL,
    "locale" TEXT NOT NULL,
    "siteHost" TEXT,
    "status" "ReportStatus" NOT NULL DEFAULT 'NEW',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "UserReport_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ReportRateLimit" (
    "id" TEXT NOT NULL,
    "ipHash" TEXT NOT NULL,
    "windowStart" TIMESTAMP(3) NOT NULL,
    "count" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "ReportRateLimit_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DailyStat" (
    "id" TEXT NOT NULL,
    "date" DATE NOT NULL,
    "platform" "Platform" NOT NULL,
    "configFetches" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "DailyStat_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "AdminUser_email_key" ON "AdminUser"("email");

-- CreateIndex
CREATE UNIQUE INDEX "Session_tokenHash_key" ON "Session"("tokenHash");

-- CreateIndex
CREATE INDEX "Session_userId_idx" ON "Session"("userId");

-- CreateIndex
CREATE INDEX "Session_expiresAt_idx" ON "Session"("expiresAt");

-- CreateIndex
CREATE INDEX "LoginAttempt_ip_email_at_idx" ON "LoginAttempt"("ip", "email", "at");

-- CreateIndex
CREATE INDEX "LoginAttempt_at_idx" ON "LoginAttempt"("at");

-- CreateIndex
CREATE UNIQUE INDEX "Shortcut_key_key" ON "Shortcut"("key");

-- CreateIndex
CREATE INDEX "Shortcut_order_idx" ON "Shortcut"("order");

-- CreateIndex
CREATE UNIQUE INDEX "Asset_sha256_key" ON "Asset"("sha256");

-- CreateIndex
CREATE UNIQUE INDEX "AdPlacement_key_key" ON "AdPlacement"("key");

-- CreateIndex
CREATE UNIQUE INDEX "BlockList_version_key" ON "BlockList"("version");

-- CreateIndex
CREATE UNIQUE INDEX "Notice_key_key" ON "Notice"("key");

-- CreateIndex
CREATE UNIQUE INDEX "ConfigRelease_version_key" ON "ConfigRelease"("version");

-- CreateIndex
CREATE INDEX "AuditLog_at_idx" ON "AuditLog"("at");

-- CreateIndex
CREATE INDEX "AuditLog_entity_entityId_idx" ON "AuditLog"("entity", "entityId");

-- CreateIndex
CREATE INDEX "UserReport_status_createdAt_idx" ON "UserReport"("status", "createdAt");

-- CreateIndex
CREATE INDEX "ReportRateLimit_windowStart_idx" ON "ReportRateLimit"("windowStart");

-- CreateIndex
CREATE UNIQUE INDEX "ReportRateLimit_ipHash_windowStart_key" ON "ReportRateLimit"("ipHash", "windowStart");

-- CreateIndex
CREATE UNIQUE INDEX "DailyStat_date_platform_key" ON "DailyStat"("date", "platform");

-- AddForeignKey
ALTER TABLE "Session" ADD CONSTRAINT "Session_userId_fkey" FOREIGN KEY ("userId") REFERENCES "AdminUser"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Shortcut" ADD CONSTRAINT "Shortcut_iconAssetId_fkey" FOREIGN KEY ("iconAssetId") REFERENCES "Asset"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BlockList" ADD CONSTRAINT "BlockList_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "AdminUser"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ConfigRelease" ADD CONSTRAINT "ConfigRelease_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "AdminUser"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AuditLog" ADD CONSTRAINT "AuditLog_actorId_fkey" FOREIGN KEY ("actorId") REFERENCES "AdminUser"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- Invariants Prisma cannot express: at most one current release, at most one ACTIVE blocklist.
CREATE UNIQUE INDEX "ConfigRelease_single_current" ON "ConfigRelease"("isCurrent") WHERE "isCurrent" = true;
CREATE UNIQUE INDEX "BlockList_single_active" ON "BlockList"("status") WHERE "status" = 'ACTIVE';

-- Singleton tables.
ALTER TABLE "AdSettings" ADD CONSTRAINT "AdSettings_singleton" CHECK ("id" = 1);
ALTER TABLE "ContentSettings" ADD CONSTRAINT "ContentSettings_singleton" CHECK ("id" = 1);

-- Server-side safety caps (mirrors CONFIG_CONTRACT.md).
ALTER TABLE "AdSettings" ADD CONSTRAINT "AdSettings_caps" CHECK ("interstitialMinIntervalSec" >= 300 AND "interstitialMaxPerSession" BETWEEN 0 AND 3);
