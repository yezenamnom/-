import { createHash, createPrivateKey, createPublicKey } from "node:crypto";

/**
 * E2E-only environment. The signing key is derived deterministically from a public, test-only
 * seed so the web server, global setup and tests (separate processes) agree on it.
 * It is NOT a secret and must never be used outside tests.
 */
const PKCS8_ED25519_PREFIX = Buffer.from("302e020100300506032b657004220420", "hex");

export function e2eKeys() {
  const seed = createHash("sha256").update("vela-e2e-test-only-signing-seed").digest();
  const der = Buffer.concat([PKCS8_ED25519_PREFIX, seed]);
  const priv = createPrivateKey({ key: der, format: "der", type: "pkcs8" });
  const x = createPublicKey(priv).export({ format: "jwk" }).x as string;
  return { privateKeyPkcs8B64: der.toString("base64"), publicKeyRawB64url: x };
}

export function e2eEnv() {
  const port = process.env.E2E_PORT ?? "3100";
  const db = process.env.E2E_DATABASE_URL ?? "postgresql://vela:vela_dev_pw@localhost:54329/vela_e2e?schema=public";
  return {
    E2E_PORT: port,
    APP_ENV: "development",
    DATABASE_URL: db,
    CONFIG_SIGNING_PRIVATE_KEY: e2eKeys().privateKeyPkcs8B64,
    CONFIG_SIGNING_KEY_ID: "k1",
    REPORT_IP_SALT: "e2e-salt-not-a-secret-0123456789",
    PUBLIC_BASE_URL: `http://localhost:${port}`,
  };
}

export const OWNER = { email: "owner@e2e.test", password: "e2e-owner-password-1" };
export const READONLY = { email: "viewer@e2e.test", password: "e2e-viewer-password-1" };
