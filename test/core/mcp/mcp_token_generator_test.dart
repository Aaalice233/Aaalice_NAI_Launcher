import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/mcp/mcp_token_generator.dart';

void main() {
  group('generateMcpServerToken', () {
    test('produces 32 bytes of unpadded base64url', () {
      final token = generateMcpServerToken();

      expect(token.length, 43);
      expect(token, isNot(contains('=')));
      expect(RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(token), isTrue);
      expect(base64Url.decode('$token=').length, 32);
    });

    test('is unique across calls', () {
      final tokens = {for (var i = 0; i < 64; i++) generateMcpServerToken()};

      expect(tokens.length, 64);
    });

    test('uses the injected randomness', () {
      final token = generateMcpServerToken(random: _ZeroRandom());

      expect(base64Url.decode('$token='), List<int>.filled(32, 0));
    });
  });
}

class _ZeroRandom implements Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => 0;
}
