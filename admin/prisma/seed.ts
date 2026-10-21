/**
 * Idempotent seed: creates defaults only where missing; never overwrites admin edits.
 *   npm run db:seed
 */
import { PrismaClient } from "@prisma/client";
import { buildBlocklistBody } from "../src/lib/blocklist";
import { starterRules, STARTER_LICENSE, STARTER_NAME } from "./seed-data/starter-blocklist";

const prisma = new PrismaClient();

// Google's OFFICIAL public test ad unit ids (https://developers.google.com/admob/android/test-ads, /ios/test-ads).
const TEST_IDS = {
  bannerAndroid: "ca-app-pub-3940256099942544/9214589741",
  bannerIos: "ca-app-pub-3940256099942544/2435281174",
  interstitialAndroid: "ca-app-pub-3940256099942544/1033173712",
  interstitialIos: "ca-app-pub-3940256099942544/4411468910",
};

const SHORTCUTS = [
  { key: "youtube", titles: { en: "YouTube", ar: "يوتيوب", de: "YouTube" }, url: "https://m.youtube.com/", iconKey: "youtube", color: "#E53935", enabled: true },
  { key: "twitch", titles: { en: "Twitch", ar: "تويتش", de: "Twitch" }, url: "https://m.twitch.tv/", iconKey: "twitch", color: "#9146FF", enabled: true },
  { key: "tiktok", titles: { en: "TikTok", ar: "تيك توك", de: "TikTok" }, url: "https://www.tiktok.com/", iconKey: "tiktok", color: "#FE2C55", enabled: true },
  { key: "rumble", titles: { en: "Rumble", ar: "رامبل", de: "Rumble" }, url: "https://rumble.com/", iconKey: "rumble", color: "#85C742", enabled: true },
  // Customisable extra, disabled by default (not published until an admin enables it).
  { key: "facebook", titles: { en: "Facebook", ar: "فيسبوك", de: "Facebook" }, url: "https://m.facebook.com/", iconKey: "facebook", color: "#1877F2", enabled: false },
];

async function main() {
  let order = 0;
  for (const s of SHORTCUTS) {
    await prisma.shortcut.upsert({ where: { key: s.key }, create: { ...s, order: order }, update: {} });
    order++;
  }

  await prisma.adSettings.upsert({
    where: { id: 1 },
    create: { id: 1, globalEnabled: true, interstitialMinIntervalSec: 600, interstitialMaxPerSession: 1 },
    update: {},
  });
  const placements = [
    { key: "home_banner" as const, format: "banner" as const, enabled: true, adUnitIdAndroid: TEST_IDS.bannerAndroid, adUnitIdIos: TEST_IDS.bannerIos },
    { key: "downloads_banner" as const, format: "banner" as const, enabled: true, adUnitIdAndroid: TEST_IDS.bannerAndroid, adUnitIdIos: TEST_IDS.bannerIos },
    { key: "tabs_interstitial" as const, format: "interstitial" as const, enabled: false, adUnitIdAndroid: TEST_IDS.interstitialAndroid, adUnitIdIos: TEST_IDS.interstitialIos },
  ];
  for (const p of placements) await prisma.adPlacement.upsert({ where: { key: p.key }, create: p, update: {} });

  await prisma.contentSettings.upsert({
    where: { id: 1 },
    create: {
      id: 1,
      // Placeholders on a reserved TLD — replace in the admin panel before production.
      privacyUrl: "https://example.invalid/privacy",
      termsUrl: "https://example.invalid/terms",
      supportUrl: "https://example.invalid/support",
      helpText: {
        en: "Tap the address bar to search or enter a website. Use the shield icon to control content blocking per site.",
        ar: "اضغط على شريط العنوان للبحث أو لإدخال موقع. استخدم أيقونة الدرع للتحكم في حجب المحتوى لكل موقع.",
        de: "Tippe auf die Adressleiste, um zu suchen oder eine Website einzugeben. Mit dem Schild-Symbol steuerst du die Inhaltsblockierung pro Website.",
      },
      minAppVersion: "1.0.0",
      maxAppVersion: null,
      blockingEnabledByDefault: true,
    },
    update: {},
  });

  if ((await prisma.blockList.count()) === 0) {
    const built = buildBlocklistBody({ version: 1, name: STARTER_NAME, license: STARTER_LICENSE, rules: starterRules() });
    if (!built.ok) throw new Error(`Starter blocklist invalid: ${built.errors.join("; ")}`);
    await prisma.blockList.create({
      data: {
        version: 1,
        name: STARTER_NAME,
        license: STARTER_LICENSE,
        body: built.body,
        sha256: built.sha256,
        ruleCount: built.ruleCount,
        status: "ACTIVE",
        activatedAt: new Date(),
      },
    });
    console.info(`Seeded blocklist v1 (${built.ruleCount} rules, sha256 ${built.sha256}).`);
  }
  console.info("Seed complete. Next: create an owner (npm run admin:create-owner -- --email you@example.com), then publish from the admin panel.");
}

main()
  .catch((e) => {
    console.error(e instanceof Error ? e.message : e);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
