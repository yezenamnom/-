import { execFileSync } from "node:child_process";
import { createHash, createPrivateKey, generateKeyPairSync, sign, X509Certificate } from "node:crypto";
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { verifyAppStoreTransaction } from "@/lib/entitlements/app-store";
import { resetGoogleTokenCache, verifyGooglePlaySubscription } from "@/lib/entitlements/google-play";
import { entitlementPayload, MAX_ENTITLEMENT_TTL_MS, StoreVerificationError } from "@/lib/entitlements/types";

const NOW = new Date("2026-10-21T12:00:00Z");

function expectCode(fn: () => unknown, code: string) {
  try {
    fn();
  } catch (e) {
    expect(e).toBeInstanceOf(StoreVerificationError);
    expect((e as StoreVerificationError).code).toBe(code);
    return;
  }
  throw new Error("expected StoreVerificationError " + code);
}

describe("entitlement payload", () => {
  it("caps validity at 7 days and never grants expired/revoked", () => {
    const far = new Date(NOW.getTime() + 365 * 86_400_000);
    const p = entitlementPayload({ platform: "android", productId: "p", status: "active", expiresAt: far }, NOW);
    expect(new Date(p.expiresAt).getTime() - NOW.getTime()).toBe(MAX_ENTITLEMENT_TTL_MS);
    expect(p.status).toBe("active");
    expect(
      entitlementPayload({ platform: "ios", productId: "p", status: "revoked", expiresAt: far }, NOW).status,
    ).toBe("expired");
    const past = new Date(NOW.getTime() - 1000);
    expect(entitlementPayload({ platform: "ios", productId: "p", status: "active", expiresAt: past }, NOW).status).toBe(
      "expired",
    );
  });
});

describe("Google Play", () => {
  const { privateKey } = generateKeyPairSync("rsa", { modulusLength: 2048 });
  const cfg = {
    packageName: "dev.vela.browser",
    clientEmail: "svc@project.iam.gserviceaccount.com",
    privateKeyPem: privateKey.export({ type: "pkcs8", format: "pem" }).toString(),
  };
  const TOKEN = "purchase-token-abcdefghijklmnop";

  function fakeFetch(sub: unknown, status = 200) {
    const calls: string[] = [];
    const fn = (async (url: string | URL | Request, init?: RequestInit) => {
      const u = String(url);
      calls.push(u);
      if (u.startsWith("https://oauth2.googleapis.com/token")) {
        const body = String(init?.body);
        expect(body).toContain("grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer");
        return new Response(JSON.stringify({ access_token: "at", expires_in: 3600 }), { status: 200 });
      }
      expect(u).toContain("/applications/dev.vela.browser/purchases/subscriptionsv2/tokens/");
      expect((init?.headers as Record<string, string>).authorization).toBe("Bearer at");
      return new Response(JSON.stringify(sub), { status });
    }) as typeof fetch;
    return { fn, calls };
  }

  it("maps an active subscription", async () => {
    resetGoogleTokenCache();
    const { fn } = fakeFetch({
      subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
      lineItems: [{ productId: "remove_ads_monthly", expiryTime: "2026-11-21T12:00:00Z" }],
    });
    const s = await verifyGooglePlaySubscription(TOKEN, "remove_ads_monthly", cfg, {
      fetchFn: fn,
      now: NOW,
      allowTestPurchases: false,
    });
    expect(s.status).toBe("active");
    expect(s.expiresAt.toISOString()).toBe("2026-11-21T12:00:00.000Z");
  });

  it("rejects wrong product, test purchases in production, unknown tokens", async () => {
    resetGoogleTokenCache();
    const sub = {
      subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
      testPurchase: {},
      lineItems: [{ productId: "other", expiryTime: "2026-11-21T12:00:00Z" }],
    };
    await expect(
      verifyGooglePlaySubscription(TOKEN, "remove_ads_monthly", cfg, {
        fetchFn: fakeFetch(sub).fn,
        now: NOW,
        allowTestPurchases: true,
      }),
    ).rejects.toMatchObject({ code: "product_mismatch" });
    await expect(
      verifyGooglePlaySubscription(TOKEN, "other", cfg, { fetchFn: fakeFetch(sub).fn, now: NOW, allowTestPurchases: false }),
    ).rejects.toMatchObject({ code: "environment_mismatch" });
    await expect(
      verifyGooglePlaySubscription(TOKEN, "other", cfg, {
        fetchFn: fakeFetch({}, 404).fn,
        now: NOW,
        allowTestPurchases: true,
      }),
    ).rejects.toMatchObject({ code: "invalid_purchase" });
    await expect(
      verifyGooglePlaySubscription("bad token/../x", "other", cfg, {
        fetchFn: fakeFetch({}).fn,
        now: NOW,
        allowTestPurchases: true,
      }),
    ).rejects.toMatchObject({ code: "invalid_purchase" });
  });

  it("maps canceled and expired states", async () => {
    resetGoogleTokenCache();
    for (const [state, expected] of [
      ["SUBSCRIPTION_STATE_CANCELED", "canceled"],
      ["SUBSCRIPTION_STATE_EXPIRED", "expired"],
      ["SUBSCRIPTION_STATE_ON_HOLD", "expired"],
      ["SOMETHING_NEW", "expired"],
    ] as const) {
      const s = await verifyGooglePlaySubscription(TOKEN, "p", cfg, {
        fetchFn: fakeFetch({ subscriptionState: state, lineItems: [{ productId: "p", expiryTime: "2026-11-01T00:00:00Z" }] })
          .fn,
        now: NOW,
        allowTestPurchases: true,
      });
      expect(s.status).toBe(expected);
    }
  });
});

describe("App Store JWS", () => {
  const NOW = new Date(Date.now() + 60_000);
  // A throw-away CA chain built with openssl, standing in for Apple's.
  const dir = mkdtempSync(path.join(tmpdir(), "vela-apple-"));
  const run = (...args: string[]) => execFileSync("openssl", args, { cwd: dir, stdio: "pipe" });
  const ext = path.join(dir, "ca.ext");
  writeFileSync(ext, "basicConstraints=critical,CA:TRUE\nkeyUsage=critical,keyCertSign,cRLSign\n");
  for (const n of ["root", "int", "leaf"]) run("ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", `${n}.key`);
  run("req", "-x509", "-new", "-key", "root.key", "-subj", "/CN=Test Root", "-days", "3650", "-out", "root.pem",
    "-set_serial", "1", "-addext", "basicConstraints=critical,CA:TRUE", "-addext", "keyUsage=critical,keyCertSign,cRLSign");
  run("req", "-new", "-key", "int.key", "-subj", "/CN=Test Intermediate", "-out", "int.csr");
  run("x509", "-req", "-in", "int.csr", "-CA", "root.pem", "-CAkey", "root.key", "-set_serial", "2",
    "-extfile", ext, "-out", "int.pem", "-days", "3650");
  run("req", "-new", "-key", "leaf.key", "-subj", "/CN=Test Leaf", "-out", "leaf.csr");
  run("x509", "-req", "-in", "leaf.csr", "-CA", "int.pem", "-CAkey", "int.key", "-set_serial", "3",
    "-out", "leaf.pem", "-days", "3650");

  const der = (f: string) => new X509Certificate(readFileSync(path.join(dir, f))).raw.toString("base64");
  const rootSha = createHash("sha256").update(new X509Certificate(readFileSync(path.join(dir, "root.pem"))).raw).digest("hex");
  const leafKey = createPrivateKey(readFileSync(path.join(dir, "leaf.key")));
  const cfg = { bundleId: "dev.vela.browser", allowSandbox: false, trustedRootSha256: rootSha };

  function jws(payload: Record<string, unknown>, x5c = [der("leaf.pem"), der("int.pem"), der("root.pem")], key = leafKey) {
    const h = Buffer.from(JSON.stringify({ alg: "ES256", x5c })).toString("base64url");
    const p = Buffer.from(JSON.stringify(payload)).toString("base64url");
    const s = sign("sha256", Buffer.from(`${h}.${p}`), { key, dsaEncoding: "ieee-p1363" }).toString("base64url");
    return `${h}.${p}.${s}`;
  }
  const tx = {
    bundleId: "dev.vela.browser",
    productId: "remove_ads_yearly",
    transactionId: "2000000001",
    originalTransactionId: "2000000000",
    type: "Auto-Renewable Subscription",
    environment: "Production",
    purchaseDate: NOW.getTime() - 86_400_000,
    expiresDate: NOW.getTime() + 30 * 86_400_000,
  };

  it("accepts a valid chain and signature", () => {
    const s = verifyAppStoreTransaction(jws(tx), "remove_ads_yearly", cfg, NOW);
    expect(s.status).toBe("active");
    expect(s.expiresAt.getTime()).toBe(tx.expiresDate);
  });

  it("rejects tampering, foreign roots, wrong keys and wrong apps", () => {
    const good = jws(tx);
    const [h, , s] = good.split(".");
    const forged = `${h}.${Buffer.from(JSON.stringify({ ...tx, expiresDate: 9e15 })).toString("base64url")}.${s}`;
    expectCode(() => verifyAppStoreTransaction(forged, "remove_ads_yearly", cfg, NOW), "invalid_purchase");
    // Real Apple root pin (default) does not trust the test chain.
    expectCode(
      () => verifyAppStoreTransaction(good, "remove_ads_yearly", { ...cfg, trustedRootSha256: undefined }, NOW),
      "invalid_purchase",
    );
    const otherKey = generateKeyPairSync("ec", { namedCurve: "prime256v1" }).privateKey;
    expectCode(() => verifyAppStoreTransaction(jws(tx, undefined, otherKey), "remove_ads_yearly", cfg, NOW), "invalid_purchase");
    // Leaf presented without its intermediate.
    expectCode(
      () => verifyAppStoreTransaction(jws(tx, [der("leaf.pem"), der("root.pem")]), "remove_ads_yearly", cfg, NOW),
      "invalid_purchase",
    );
    expectCode(
      () => verifyAppStoreTransaction(jws({ ...tx, bundleId: "com.other" }), "remove_ads_yearly", cfg, NOW),
      "invalid_purchase",
    );
    expectCode(() => verifyAppStoreTransaction(jws(tx), "remove_ads_monthly", cfg, NOW), "product_mismatch");
    expectCode(
      () => verifyAppStoreTransaction(jws({ ...tx, environment: "Sandbox" }), "remove_ads_yearly", cfg, NOW),
      "environment_mismatch",
    );
    expectCode(() => verifyAppStoreTransaction("a.b", "remove_ads_yearly", cfg, NOW), "invalid_purchase");
  });

  it("reports revoked and expired transactions", () => {
    expect(verifyAppStoreTransaction(jws({ ...tx, revocationDate: NOW.getTime() }), "remove_ads_yearly", cfg, NOW).status).toBe(
      "revoked",
    );
    expect(
      verifyAppStoreTransaction(jws({ ...tx, expiresDate: NOW.getTime() - 1 }), "remove_ads_yearly", cfg, NOW).status,
    ).toBe("expired");
    expect(
      verifyAppStoreTransaction(jws({ ...tx, environment: "Sandbox" }), "remove_ads_yearly", { ...cfg, allowSandbox: true }, NOW)
        .status,
    ).toBe("active");
  });
});
