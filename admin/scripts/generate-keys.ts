/**
 * Prints a NEW Ed25519 keypair. Nothing is written to disk.
 *   npm run keys:generate
 */
import { generateSigningKeyPair } from "../src/lib/signing";

const { privateKeyPkcs8B64, publicKeyRawB64url } = generateSigningKeyPair();

console.log(`# Vela config signing keypair (Ed25519) — generated ${new Date().toISOString()}
#
# 1) SERVER ONLY — put this in admin/.env (never commit it, never ship it in the app):
CONFIG_SIGNING_PRIVATE_KEY=${privateKeyPkcs8B64}
CONFIG_SIGNING_KEY_ID=k1

# 2) MOBILE BUILD — raw 32-byte public key, base64url:
#    flutter build ... --dart-define=CONFIG_PUBLIC_KEY=${publicKeyRawB64url}
#    (also usable by: CONFIG_PUBLIC_KEY=... npm run config:verify -- <url>)
CONFIG_PUBLIC_KEY=${publicKeyRawB64url}
#
# When rotating keys: bump CONFIG_SIGNING_KEY_ID (k2, ...) and ship an app build with the new public key first.`);
