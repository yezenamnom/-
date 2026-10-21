import { X509Certificate, createHash, verify as verifySig } from "node:crypto";
import { z } from "zod";
import { StoreVerificationError, type VerifiedSubscription } from "./types";

/**
 * App Store (StoreKit 2) transaction verification, fully offline: the JWS
 * signed transaction carries an x5c chain that must end in Apple Root CA - G3
 * (pinned by SHA-256 fingerprint), every certificate must be valid now and
 * signed by the next, and the JWS must verify with the leaf key (ES256).
 *
 * Limitation (documented in STORE_READINESS.md): a transaction reflects the
 * state when it was issued. Renewals create new transactions, which the app
 * sends on restore/re-verify; App Store Server Notifications V2 are not wired
 * yet, so a refund is picked up when the 7-day entitlement is re-verified
 * only if the app sends the revoked transaction.
 */

/** SHA-256 of https://www.apple.com/certificateauthority/AppleRootCA-G3.cer */
export const APPLE_ROOT_CA_G3_SHA256 =
  "63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179";

export type AppStoreConfig = {
  bundleId: string;
  /** Accept Sandbox/Xcode transactions (never in production). */
  allowSandbox: boolean;
  /** Override only in tests. */
  trustedRootSha256?: string;
};

export function appStoreConfigFromEnv(env = process.env): AppStoreConfig | null {
  const bundleId = env.APPLE_BUNDLE_ID?.trim();
  if (!bundleId) return null;
  return { bundleId, allowSandbox: (env.APP_ENV ?? "development") !== "production" };
}

const headerSchema = z.object({ alg: z.literal("ES256"), x5c: z.array(z.string()).min(2).max(4) });

const transactionSchema = z.object({
  bundleId: z.string(),
  productId: z.string(),
  transactionId: z.string(),
  originalTransactionId: z.string(),
  type: z.string(),
  environment: z.enum(["Production", "Sandbox", "Xcode", "LocalTesting"]),
  expiresDate: z.number().optional(),
  revocationDate: z.number().optional(),
  purchaseDate: z.number(),
});

function fingerprint(cert: X509Certificate): string {
  return createHash("sha256").update(cert.raw).digest("hex");
}

export function verifyAppStoreTransaction(
  jws: string,
  productId: string,
  cfg: AppStoreConfig,
  now = new Date(),
): VerifiedSubscription {
  const [h64, p64, s64, ...rest] = jws.split(".");
  if (h64 === undefined || p64 === undefined || s64 === undefined || rest.length > 0 || jws.length > 16_384) {
    throw new StoreVerificationError("invalid_purchase", "not a JWS");
  }
  let header: z.infer<typeof headerSchema>;
  try {
    header = headerSchema.parse(JSON.parse(Buffer.from(h64, "base64url").toString("utf8")));
  } catch {
    throw new StoreVerificationError("invalid_purchase", "bad header");
  }

  let chain: X509Certificate[];
  try {
    chain = header.x5c.map((c) => new X509Certificate(Buffer.from(c, "base64")));
  } catch {
    throw new StoreVerificationError("invalid_purchase", "bad certificate");
  }
  const leaf = chain[0];
  const root = chain[chain.length - 1];
  if (!leaf || !root || fingerprint(root) !== (cfg.trustedRootSha256 ?? APPLE_ROOT_CA_G3_SHA256)) {
    throw new StoreVerificationError("invalid_purchase", "untrusted root");
  }
  chain.forEach((c, i) => {
    if (now < new Date(c.validFrom) || now > new Date(c.validTo)) {
      throw new StoreVerificationError("invalid_purchase", "certificate not valid now");
    }
    // Each certificate must be issued and signed by the next; the root by itself.
    const issuer = chain[i + 1] ?? root;
    if (!c.verify(issuer.publicKey) || (issuer !== c && !c.checkIssued(issuer))) {
      throw new StoreVerificationError("invalid_purchase", "broken chain");
    }
  });
  const ok = verifySig(
    "sha256",
    Buffer.from(`${h64}.${p64}`),
    { key: leaf.publicKey, dsaEncoding: "ieee-p1363" },
    Buffer.from(s64, "base64url"),
  );
  if (!ok) throw new StoreVerificationError("invalid_purchase", "bad signature");

  let tx: z.infer<typeof transactionSchema>;
  try {
    tx = transactionSchema.parse(JSON.parse(Buffer.from(p64, "base64url").toString("utf8")));
  } catch {
    throw new StoreVerificationError("invalid_purchase", "bad payload");
  }
  if (tx.bundleId !== cfg.bundleId) throw new StoreVerificationError("invalid_purchase", "bundle mismatch");
  if (tx.productId !== productId) throw new StoreVerificationError("product_mismatch");
  if (tx.environment !== "Production" && !cfg.allowSandbox) {
    throw new StoreVerificationError("environment_mismatch");
  }
  if (tx.type !== "Auto-Renewable Subscription") {
    throw new StoreVerificationError("invalid_purchase", "not a subscription");
  }
  const expiresAt = new Date(tx.expiresDate ?? 0);
  return {
    platform: "ios",
    productId,
    status: tx.revocationDate ? "revoked" : expiresAt > now ? "active" : "expired",
    expiresAt,
  };
}
