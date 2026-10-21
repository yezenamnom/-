// Loads real sites in Playwright Chromium with Pixel emulation, once without and
// once with Vela's network rules applied via request interception, and records
// whether the page still works. This approximates the Android behaviour of the
// rules; it is NOT a test of the app's WebView. Results -> smoke-results.json.
import { chromium, devices } from "playwright-core";
import { readFileSync, writeFileSync } from "node:fs";

const list = JSON.parse(readFileSync(new URL("../../mobile/assets/blocklists/starter.json", import.meta.url)));
const rules = list.rules.filter((r) => r.action === "block").map((r) => new RegExp(r.urlFilter));
const sites = process.argv.slice(2).length
  ? process.argv.slice(2)
  : ["https://m.youtube.com/", "https://m.twitch.tv/", "https://www.tiktok.com/", "https://rumble.com/", "https://www.bbc.com/news", "https://www.wikipedia.org/"];

const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined });
const results = [];
for (const url of sites) {
  for (const blocking of [false, true]) {
    const ctx = await browser.newContext({ ...devices["Pixel 7"], locale: "en-US" });
    const page = await ctx.newPage();
    let total = 0, blocked = 0;
    const blockedHosts = new Set();
    await page.route("**/*", (route) => {
      total++;
      const u = route.request().url();
      if (blocking && rules.some((r) => r.test(u))) {
        blocked++;
        blockedHosts.add(new URL(u).host);
        return route.abort("blockedbyclient");
      }
      return route.continue();
    });
    const r = { url, blocking, status: null, title: null, videoElements: null, requests: 0, blocked: 0, blockedHosts: [], error: null };
    try {
      const resp = await page.goto(url, { waitUntil: "domcontentloaded", timeout: 45000 });
      await page.waitForTimeout(6000);
      r.status = resp?.status() ?? null;
      r.title = (await page.title()).slice(0, 80);
      r.videoElements = await page.locator("video").count();
    } catch (e) {
      r.error = String(e.message).split("\n")[0];
    }
    r.requests = total; r.blocked = blocked; r.blockedHosts = [...blockedHosts].sort();
    results.push(r);
    console.log(JSON.stringify(r));
    await ctx.close();
  }
}
await browser.close();
writeFileSync(new URL("./smoke-results.json", import.meta.url),
  JSON.stringify({ date: new Date().toISOString(), engine: "Chromium (Playwright, Pixel 7 emulation)", listVersion: list.version, results }, null, 2));
