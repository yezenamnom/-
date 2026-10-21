import { describe, expect, it } from "vitest";
import { PrismaClient } from "@prisma/client";
import { dropDatabase, migrateDeploy, recreateDatabase } from "./db-admin";

describe("migrations", () => {
  it("apply cleanly on an empty database", async () => {
    const base = new URL(process.env.TEST_DATABASE_URL!);
    base.pathname = `/vela_migtest_${Date.now()}`;
    const url = base.toString();
    await recreateDatabase(url);
    try {
      const out = migrateDeploy(url);
      expect(out).toMatch(/applied|No pending migrations/i);
      const db = new PrismaClient({ datasourceUrl: url });
      try {
        const tables = await db.$queryRaw<Array<{ tablename: string }>>`SELECT tablename FROM pg_tables WHERE schemaname = 'public'`;
        const names = tables.map((t) => t.tablename);
        for (const t of ["AdminUser", "Session", "ConfigRelease", "BlockList", "AuditLog", "UserReport", "DailyStat", "ReportRateLimit"]) {
          expect(names).toContain(t);
        }
        const idx = await db.$queryRaw<Array<{ indexname: string }>>`SELECT indexname FROM pg_indexes WHERE indexname IN ('ConfigRelease_single_current', 'BlockList_single_active')`;
        expect(idx).toHaveLength(2);
        // DB-level safety cap is enforced too.
        await expect(db.adSettings.create({ data: { id: 1, interstitialMinIntervalSec: 10 } })).rejects.toThrow();
      } finally {
        await db.$disconnect();
      }
      expect(migrateDeploy(url)).toMatch(/No pending migrations/i);
    } finally {
      await dropDatabase(url);
    }
  });
});
