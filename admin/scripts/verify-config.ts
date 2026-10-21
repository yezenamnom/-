/**
 * Ops tool: fetch a server's signed config and verify it exactly like the app does.
 *   CONFIG_PUBLIC_KEY=<base64url raw key> npm run config:verify -- https://admin.example.com
 *   (or pass --public-key <key>; URL may be the base URL or the full /api/v1/config URL)
 * Also checks the schema, expiry, and the referenced blocklist's SHA-256.
 */
import { createHash } from "node:crypto";
import { loadRawPublicKey, verifyEnvelope } from "../src/lib/signing";
import { configPayloadSchema } from "../src/lib/config-schema";

function arg(name: string): string | undefined {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : undefined;
}

async function main() {
  const target = process.argv.slice(2).find((a) => /^https?:\/\//.test(a));
  const pubB64 = arg("--public-key") ?? process.env.CONFIG_PUBLIC_KEY;
  if (!target || !pubB64) {
    console.error("Usage: CONFIG_PUBLIC_KEY=<key> npm run config:verify -- <base-url | .../api/v1/config>");
    process.exit(2);
  }
  const url = new URL(target);
  if (!url.pathname.endsWith("/api/v1/config")) url.pathname = `${url.pathname.replace(/\/$/, "")}/api/v1/config`;
  const pub = loadRawPublicKey(pubB64);

  const res = await fetch(url, { headers: { accept: "application/json" } });
  if (!res.ok) {
    console.error(`FAIL: HTTP ${res.status} ${await res.text()}`);
    process.exit(1);
  }
  const envelope = (await res.json()) as unknown;
  const v = verifyEnvelope(envelope, pub);
  if (!v.ok) {
    console.error(`FAIL: signature verification failed (${v.reason})`);
    process.exit(1);
  }
  const payload = configPayloadSchema.safeParse(JSON.parse(v.payloadJson));
  if (!payload.success) {
    console.error("FAIL: payload does not match schema:", payload.error.issues.slice(0, 10));
    process.exit(1);
  }
  const p = payload.data;
  if (Date.parse(p.expiresAt) <= Date.now()) {
    console.error(`FAIL: expired at ${p.expiresAt}`);
    process.exit(1);
  }
  const blRes = await fetch(new URL(p.blocking.listPath, url));
  const blBytes = Buffer.from(await blRes.arrayBuffer());
  const blSha = createHash("sha256").update(blBytes).digest("hex");
  const blOk = blRes.ok && blSha === p.blocking.listSha256;

  console.log(`OK: signature valid (keyId=${(envelope as { keyId: string }).keyId})`);
  console.log(`  configVersion=${p.configVersion} issuedAt=${p.issuedAt} expiresAt=${p.expiresAt}`);
  console.log(`  shortcuts=${p.shortcuts.length} ads.enabled=${p.ads.enabled} notices=${p.notices.length}`);
  console.log(`  blocklist v${p.blocking.listVersion}: ${blOk ? "sha256 matches" : `MISMATCH (HTTP ${blRes.status}, got ${blSha})`}`);
  if (!blOk) process.exit(1);
}

main().catch((e) => {
  console.error("FAIL:", e instanceof Error ? e.message : e);
  process.exit(1);
});
