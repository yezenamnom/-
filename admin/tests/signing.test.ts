import { describe, expect, it } from "vitest";
import { generateKeyPairSync } from "node:crypto";
import { generateSigningKeyPair, loadPrivateKey, loadRawPublicKey, signPayloadJson, verifyEnvelope } from "@/lib/signing";

describe("Ed25519 signing", () => {
  const kp = generateSigningKeyPair();
  const priv = loadPrivateKey(kp.privateKeyPkcs8B64);
  const pub = loadRawPublicKey(kp.publicKeyRawB64url);
  const json = JSON.stringify({ schemaVersion: 1, text: "يوتيوب ✓" });

  it("round-trips and signs the exact payload bytes", () => {
    const env = signPayloadJson(json, priv, "k1");
    expect(env.keyId).toBe("k1");
    expect(Buffer.from(env.payload, "base64url").toString("utf8")).toBe(json);
    expect(env.payload).not.toMatch(/[+/=]/);
    const v = verifyEnvelope(env, pub);
    expect(v).toEqual({ ok: true, payloadJson: json });
    expect(Buffer.from(kp.publicKeyRawB64url, "base64url")).toHaveLength(32);
  });

  it("detects tampering", () => {
    const env = signPayloadJson(json, priv, "k1");
    const tampered = Buffer.from(JSON.stringify({ schemaVersion: 1, text: "evil" })).toString("base64url");
    expect(verifyEnvelope({ ...env, payload: tampered }, pub).ok).toBe(false);
    const sig = Buffer.from(env.signature, "base64url");
    sig[0] = sig[0]! ^ 1;
    expect(verifyEnvelope({ ...env, signature: sig.toString("base64url") }, pub).ok).toBe(false);
    const other = loadRawPublicKey(generateSigningKeyPair().publicKeyRawB64url);
    expect(verifyEnvelope(env, other).ok).toBe(false);
    expect(verifyEnvelope({ keyId: "k1" }, pub).ok).toBe(false);
    expect(verifyEnvelope(null, pub).ok).toBe(false);
  });

  it("rejects non-Ed25519 keys", () => {
    const { privateKey } = generateKeyPairSync("ec", { namedCurve: "P-256" });
    const b64 = privateKey.export({ format: "der", type: "pkcs8" }).toString("base64");
    expect(() => loadPrivateKey(b64)).toThrow();
    expect(() => loadRawPublicKey("abc")).toThrow();
  });
});
