import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

final class OAuthPkceRequest {
  const OAuthPkceRequest({
    required this.codeVerifier,
    required this.codeChallenge,
    required this.state,
    required this.nonce,
  });

  final String codeVerifier;
  final String codeChallenge;
  final String state;
  final String nonce;
}

abstract interface class OAuthRandomSource {
  Uint8List bytes(int length);
}

final class SecureOAuthRandomSource implements OAuthRandomSource {
  SecureOAuthRandomSource() : _random = Random.secure();

  final Random _random;

  @override
  Uint8List bytes(int length) =>
      Uint8List.fromList(List.generate(length, (_) => _random.nextInt(256)));
}

final class OAuthPkce {
  OAuthPkce({OAuthRandomSource? random})
    : _random = random ?? SecureOAuthRandomSource();

  final OAuthRandomSource _random;

  OAuthPkceRequest create() {
    final verifier = _base64Url(_random.bytes(64));
    return OAuthPkceRequest(
      codeVerifier: verifier,
      codeChallenge: challengeForVerifier(verifier),
      state: _base64Url(_random.bytes(32)),
      nonce: _base64Url(_random.bytes(32)),
    );
  }

  static String challengeForVerifier(String verifier) =>
      _base64Url(sha256.convert(ascii.encode(verifier)).bytes);

  static bool secureEquals(String expected, String actual) {
    final expectedBytes = utf8.encode(expected);
    final actualBytes = utf8.encode(actual);
    var difference = expectedBytes.length ^ actualBytes.length;
    final length = max(expectedBytes.length, actualBytes.length);
    for (var index = 0; index < length; index++) {
      final left = index < expectedBytes.length ? expectedBytes[index] : 0;
      final right = index < actualBytes.length ? actualBytes[index] : 0;
      difference |= left ^ right;
    }
    return difference == 0;
  }

  static String _base64Url(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');
}
