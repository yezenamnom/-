import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// Verifies the signed envelope `{keyId, payload, signature}` produced by
/// the admin server (docs/CONFIG_CONTRACT.md). Returns the decoded payload
/// JSON string only if the Ed25519 signature over its exact bytes is valid.
class ConfigVerifier {
  ConfigVerifier(this._publicKey);

  /// Raw 32-byte Ed25519 public key, injected at build time via
  /// `--dart-define=CONFIG_PUBLIC_KEY=<base64url>`. Never fetched remotely.
  final List<int>? _publicKey;

  static ConfigVerifier fromBase64Url(String value) {
    if (value.isEmpty) return ConfigVerifier(null);
    try {
      final bytes = base64Url.decode(base64Url.normalize(value));
      return ConfigVerifier(bytes.length == 32 ? bytes : null);
    } on FormatException {
      return ConfigVerifier(null);
    }
  }

  bool get isConfigured => _publicKey != null;

  Future<String?> verifyEnvelope(String envelopeJson) async {
    final key = _publicKey;
    if (key == null) return null;
    try {
      final env = jsonDecode(envelopeJson);
      if (env is! Map) return null;
      final payload = env['payload'];
      final signature = env['signature'];
      if (payload is! String || signature is! String) return null;
      if (payload.length > 512 * 1024) return null;
      final payloadBytes = base64Url.decode(base64Url.normalize(payload));
      final sigBytes = base64Url.decode(base64Url.normalize(signature));
      if (sigBytes.length != 64) return null;
      final ok = await Ed25519().verify(
        payloadBytes,
        signature: Signature(
          sigBytes,
          publicKey: SimplePublicKey(key, type: KeyPairType.ed25519),
        ),
      );
      return ok ? utf8.decode(payloadBytes) : null;
    } on FormatException {
      return null;
    }
  }
}
