/**
 * "Remove app ads" entitlements. The server is the only place a purchase is
 * turned into an entitlement: it verifies the purchase with Google Play or
 * the App Store, then signs a short-lived entitlement the app can verify
 * offline (same Ed25519 key/envelope as the config).
 */
export type StorePlatform = "android" | "ios";

export type SubscriptionStatus = "active" | "grace" | "canceled" | "expired" | "revoked" | "pending";

export type VerifiedSubscription = {
  platform: StorePlatform;
  productId: string;
  status: SubscriptionStatus;
  /** When the store says access ends. */
  expiresAt: Date;
};

export class StoreVerificationError extends Error {
  constructor(
    public readonly code:
      | "not_configured"
      | "invalid_purchase"
      | "product_mismatch"
      | "store_unavailable"
      | "environment_mismatch",
    message?: string,
  ) {
    super(message ?? code);
  }
}

/** Entitlements are re-verified at least this often, so cancellations and refunds propagate. */
export const MAX_ENTITLEMENT_TTL_MS = 7 * 24 * 60 * 60 * 1000;

const GRANTING: ReadonlySet<SubscriptionStatus> = new Set(["active", "grace", "canceled"]);

export function grantsAdFree(s: VerifiedSubscription, now: Date): boolean {
  return GRANTING.has(s.status) && s.expiresAt.getTime() > now.getTime();
}

export type EntitlementPayload = {
  type: "ad_free_entitlement";
  platform: StorePlatform;
  productId: string;
  status: SubscriptionStatus;
  issuedAt: string;
  expiresAt: string;
};

export function entitlementPayload(s: VerifiedSubscription, now: Date): EntitlementPayload {
  const cap = new Date(now.getTime() + MAX_ENTITLEMENT_TTL_MS);
  const expires = s.expiresAt.getTime() < cap.getTime() ? s.expiresAt : cap;
  return {
    type: "ad_free_entitlement",
    platform: s.platform,
    productId: s.productId,
    status: grantsAdFree(s, now) ? s.status : s.status === "pending" ? "pending" : "expired",
    issuedAt: now.toISOString(),
    expiresAt: expires.toISOString(),
  };
}
