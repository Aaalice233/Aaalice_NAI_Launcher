import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/constant_time_equals.dart';

void main() {
  group('constantTimeEquals', () {
    test('accepts identical secrets', () {
      expect(constantTimeEquals('token-value', 'token-value'), isTrue);
      expect(constantTimeEquals('', ''), isTrue);
    });

    test('rejects different secrets regardless of shape', () {
      expect(constantTimeEquals('token', 'Token'), isFalse);
      expect(constantTimeEquals('token', 'token '), isFalse);
      expect(constantTimeEquals('token', 'token-extra'), isFalse);
      expect(constantTimeEquals('token', ''), isFalse);
      expect(constantTimeEquals('', 'token'), isFalse);
    });

    test('compares by bytes, not code units', () {
      expect(constantTimeEquals('密钥', '密钥'), isTrue);
      expect(constantTimeEquals('密钥', '密鑰'), isFalse);
    });
  });

  group('secretsMatch', () {
    test('accepts identical non-empty secrets', () {
      expect(secretsMatch('token-value', 'token-value'), isTrue);
      expect(secretsMatch('密钥', '密钥'), isTrue);
    });

    test('rejects a missing or empty secret on either side', () {
      const absent = <String?>[null, ''];
      for (final expected in absent) {
        for (final presented in absent) {
          expect(secretsMatch(expected, presented), isFalse);
        }
        expect(secretsMatch(expected, 'token'), isFalse);
        expect(secretsMatch('token', expected), isFalse);
      }
    });

    test('rejects different secrets', () {
      expect(secretsMatch('token', 'Token'), isFalse);
      expect(secretsMatch('token', 'token '), isFalse);
      expect(secretsMatch('token', 'token-extra'), isFalse);
    });
  });
}
