/**
 * Ed25519 signing of the config envelope using Node's built-in crypto only.
 *
 * Envelope (CONFIG_CONTRACT.md):
 *   { keyId, payload: base64url(UTF-8 bytes of payloadJson), signature: base64url(Ed25519(those bytes)) }
 * The signature covers exactly the bytes that were base64url-encoded into `payload`.
 */
import {
  createPrivateKey,
  createPublicKey,
  generateKeyPairSync,
  sign,
  verify,
  type KeyObject,
} from "node:crypto";

export type SignedEnvelope = { keyId: string; payload: string; signature: string };

export function loadPrivateKey(pkcs8Base64: string): KeyObject {
  const der = Buffer.from(pkcs8Base64.trim(), "base64");
  const key = createPrivateKey({ key: der, format: "der", type: "pkcs8" });
  if (key.asymmetricKeyType !== "ed25519") throw new Error("Signing key is not an Ed25519 key");
  return key;
}

/** Raw 32-byte public key (base64url) — the value the mobile build embeds. */
export function rawPublicKeyB64url(privateOrPublic: KeyObject): string {
  const pub = privateOrPublic.type === "private" ? createPublicKey(privateOrPublic) : privateOrPublic;
  const jwk = pub.export({ format: "jwk" });
  if (jwk.crv !== "Ed25519" || typeof jwk.x !== "string") throw new Error("Not an Ed25519 key");
  return jwk.x;
}

export function loadRawPublicKey(rawB64url: string): KeyObject {
  const bytes = Buffer.from(rawB64url.trim(), "base64url");
  if (bytes.length !== 32) throw new Error("Ed25519 public key must be 32 bytes");
  return createPublicKey({ key: { kty: "OKP", crv: "Ed25519", x: bytes.toString("base64url") }, format: "jwk" });
}

export function generateSigningKeyPair(): { privateKeyPkcs8B64: string; publicKeyRawB64url: string } {
  const { privateKey } = generateKeyPairSync("ed25519");
  return {
    privateKeyPkcs8B64: privateKey.export({ format: "der", type: "pkcs8" }).toString("base64"),
    publicKeyRawB64url: rawPublicKeyB64url(privateKey),
  };
}

export function signPayloadJson(payloadJson: string, privateKey: KeyObject, keyId: string): SignedEnvelope {
  const bytes = Buffer.from(payloadJson, "utf8");
  const signature = sign(null, bytes, privateKey);
  return { keyId, payload: bytes.toString("base64url"), signature: signature.toString("base64url") };
}

export type VerifyResult = { ok: true; payloadJson: string } | { ok: false; reason: string };

const B64URL_RE = /^[A-Za-z0-9_-]*$/;

export function verifyEnvelope(envelope: unknown, publicKey: KeyObject): VerifyResult {
  if (typeof envelope !== "object" || envelope === null) return { ok: false, reason: "envelope_not_object" };
  const e = envelope as Record<string, unknown>;
  if (typeof e.keyId !== "string" || typeof e.payload !== "string" || typeof e.signature !== "string") {
    return { ok: false, reason: "envelope_fields" };
  }
  if (!B64URL_RE.test(e.payload) || !B64URL_RE.test(e.signature)) return { ok: false, reason: "not_base64url" };
  const bytes = Buffer.from(e.payload, "base64url");
  const sig = Buffer.from(e.signature, "base64url");
  if (sig.length !== 64) return { ok: false, reason: "bad_signature_length" };
  if (!verify(null, bytes, publicKey, sig)) return { ok: false, reason: "bad_signature" };
  return { ok: true, payloadJson: bytes.toString("utf8") };
}
