import { createSign } from "node:crypto";
import { z } from "zod";
import { StoreVerificationError, type SubscriptionStatus, type VerifiedSubscription } from "./types";

/**
 * Google Play subscription verification via the Android Publisher API
 * (purchases.subscriptionsv2.get) using a service account. No SDK: a signed
 * JWT is exchanged for an OAuth token (RFC 7523), all over HTTPS to Google.
 */
export type GooglePlayConfig = {
  packageName: string;
  clientEmail: string;
  privateKeyPem: string;
};

const serviceAccountSchema = z.object({
  client_email: z.string().email(),
  private_key: z.string().includes("PRIVATE KEY"),
});

/** From env: GOOGLE_PLAY_PACKAGE_NAME + GOOGLE_PLAY_SERVICE_ACCOUNT_JSON (base64 of the JSON key). */
export function googlePlayConfigFromEnv(env = process.env): GooglePlayConfig | null {
  const pkg = env.GOOGLE_PLAY_PACKAGE_NAME?.trim();
  const b64 = env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON?.trim();
  if (!pkg || !b64) return null;
  try {
    const sa = serviceAccountSchema.parse(JSON.parse(Buffer.from(b64, "base64").toString("utf8")));
    return { packageName: pkg, clientEmail: sa.client_email, privateKeyPem: sa.private_key };
  } catch {
    return null;
  }
}

type Fetch = typeof fetch;

const TOKEN_URL = "https://oauth2.googleapis.com/token";
const SCOPE = "https://www.googleapis.com/auth/androidpublisher";

let tokenCache: { email: string; token: string; exp: number } | null = null;

async function accessToken(cfg: GooglePlayConfig, fetchFn: Fetch, now: Date): Promise<string> {
  const nowS = Math.floor(now.getTime() / 1000);
  if (tokenCache && tokenCache.email === cfg.clientEmail && tokenCache.exp - 60 > nowS) return tokenCache.token;
  const header = Buffer.from(JSON.stringify({ alg: "RS256", typ: "JWT" })).toString("base64url");
  const claims = Buffer.from(
    JSON.stringify({ iss: cfg.clientEmail, scope: SCOPE, aud: TOKEN_URL, iat: nowS, exp: nowS + 3600 }),
  ).toString("base64url");
  const signer = createSign("RSA-SHA256");
  signer.update(`${header}.${claims}`);
  const jwt = `${header}.${claims}.${signer.sign(cfg.privateKeyPem).toString("base64url")}`;
  const res = await fetchFn(TOKEN_URL, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: jwt }),
  });
  if (!res.ok) throw new StoreVerificationError("store_unavailable", `token ${res.status}`);
  const body = z.object({ access_token: z.string(), expires_in: z.number() }).parse(await res.json());
  tokenCache = { email: cfg.clientEmail, token: body.access_token, exp: nowS + body.expires_in };
  return body.access_token;
}

const subscriptionSchema = z.object({
  subscriptionState: z.string(),
  testPurchase: z.object({}).passthrough().optional(),
  lineItems: z
    .array(z.object({ productId: z.string(), expiryTime: z.string().optional() }))
    .min(1),
});

const STATE_MAP: Record<string, SubscriptionStatus> = {
  SUBSCRIPTION_STATE_ACTIVE: "active",
  SUBSCRIPTION_STATE_IN_GRACE_PERIOD: "grace",
  SUBSCRIPTION_STATE_CANCELED: "canceled",
  SUBSCRIPTION_STATE_ON_HOLD: "expired",
  SUBSCRIPTION_STATE_PAUSED: "expired",
  SUBSCRIPTION_STATE_EXPIRED: "expired",
  SUBSCRIPTION_STATE_PENDING: "pending",
  SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED: "expired",
};

export async function verifyGooglePlaySubscription(
  purchaseToken: string,
  productId: string,
  cfg: GooglePlayConfig,
  opts: { fetchFn?: Fetch; now?: Date; allowTestPurchases: boolean },
): Promise<VerifiedSubscription> {
  const fetchFn = opts.fetchFn ?? fetch;
  const now = opts.now ?? new Date();
  if (!/^[A-Za-z0-9._:-]{10,1024}$/.test(purchaseToken)) {
    throw new StoreVerificationError("invalid_purchase", "malformed token");
  }
  const token = await accessToken(cfg, fetchFn, now);
  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/` +
    `${encodeURIComponent(cfg.packageName)}/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`;
  const res = await fetchFn(url, { headers: { authorization: `Bearer ${token}` } });
  if (res.status === 400 || res.status === 404 || res.status === 410) {
    throw new StoreVerificationError("invalid_purchase", `play ${res.status}`);
  }
  if (!res.ok) throw new StoreVerificationError("store_unavailable", `play ${res.status}`);
  const sub = subscriptionSchema.parse(await res.json());
  if (sub.testPurchase && !opts.allowTestPurchases) {
    throw new StoreVerificationError("environment_mismatch", "test purchase in production");
  }
  const item = sub.lineItems.find((l) => l.productId === productId);
  if (!item) throw new StoreVerificationError("product_mismatch");
  const expires = item.expiryTime ? new Date(item.expiryTime) : new Date(0);
  if (Number.isNaN(expires.getTime())) throw new StoreVerificationError("invalid_purchase", "bad expiry");
  return {
    platform: "android",
    productId,
    status: STATE_MAP[sub.subscriptionState] ?? "expired",
    expiresAt: expires,
  };
}

/** Test hook. */
export function resetGoogleTokenCache() {
  tokenCache = null;
}
