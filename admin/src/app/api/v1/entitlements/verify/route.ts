import { z } from "zod";
import { getSigningKey } from "@/lib/config-serve";
import { appEnv, signingKeyId } from "@/lib/env";
import { errorJson, HttpError, json, readJson } from "@/lib/http";
import { signPayloadJson } from "@/lib/signing";
import { appStoreConfigFromEnv, verifyAppStoreTransaction } from "@/lib/entitlements/app-store";
import { googlePlayConfigFromEnv, verifyGooglePlaySubscription } from "@/lib/entitlements/google-play";
import { entitlementPayload, StoreVerificationError, type VerifiedSubscription } from "@/lib/entitlements/types";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

const input = z.object({
  platform: z.enum(["android", "ios"]),
  productId: z.string().regex(/^[A-Za-z0-9._-]{1,150}$/),
  verificationData: z.string().min(10).max(16_384),
  source: z.string().max(40).optional(),
});

/** Comma-separated product ids that remove app ads (ENTITLEMENT_PRODUCT_IDS). */
function allowedProducts(): Set<string> {
  return new Set(
    (process.env.ENTITLEMENT_PRODUCT_IDS ?? "")
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean),
  );
}

const STATUS: Record<StoreVerificationError["code"], number> = {
  not_configured: 501,
  invalid_purchase: 400,
  product_mismatch: 400,
  environment_mismatch: 400,
  store_unavailable: 503,
};

/**
 * POST /api/v1/entitlements/verify — verifies a purchase with the store and
 * returns a signed, short-lived "ad_free_entitlement" envelope. Nothing is
 * stored; no user account exists. 501 when the store is not configured.
 */
export async function POST(req: Request) {
  try {
    const body = await readJson(req, input, 32 * 1024);
    if (!allowedProducts().has(body.productId)) return errorJson(400, "unknown_product");
    const key = getSigningKey();
    if (!key) return errorJson(503, "signing_key_unavailable");

    let sub: VerifiedSubscription;
    if (body.platform === "android") {
      const cfg = googlePlayConfigFromEnv();
      if (!cfg) throw new StoreVerificationError("not_configured");
      sub = await verifyGooglePlaySubscription(body.verificationData, body.productId, cfg, {
        allowTestPurchases: appEnv() !== "production",
      });
    } else {
      const cfg = appStoreConfigFromEnv();
      if (!cfg) throw new StoreVerificationError("not_configured");
      sub = verifyAppStoreTransaction(body.verificationData, body.productId, cfg);
    }
    const now = new Date();
    const envelope = signPayloadJson(JSON.stringify(entitlementPayload(sub, now)), key, signingKeyId());
    return json(envelope);
  } catch (e) {
    if (e instanceof StoreVerificationError) return errorJson(STATUS[e.code], e.code);
    if (e instanceof HttpError) return errorJson(e.status, e.code, undefined, e.details);
    return errorJson(500, "internal_error");
  }
}
