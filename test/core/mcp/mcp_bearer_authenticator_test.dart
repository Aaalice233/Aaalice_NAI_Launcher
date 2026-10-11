import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/mcp/mcp_bearer_authenticator.dart';

void main() {
  group('McpBearerAuthenticator', () {
    final authenticator = McpBearerAuthenticator(() => 'expected-token');

    test('accepts the expected token in any scheme casing', () {
      expect(authenticator.authorize('Bearer expected-token'), isTrue);
      expect(authenticator.authorize('bearer expected-token'), isTrue);
      expect(authenticator.authorize('BEARER expected-token'), isTrue);
      expect(authenticator.authorize('  Bearer  expected-token  '), isTrue);
    });

    test('rejects a missing, empty or malformed header', () {
      expect(authenticator.authorize(null), isFalse);
      expect(authenticator.authorize(''), isFalse);
      expect(authenticator.authorize('Bearer'), isFalse);
      expect(authenticator.authorize('Bearer '), isFalse);
      expect(authenticator.authorize('expected-token'), isFalse);
      expect(authenticator.authorize('Basic expected-token'), isFalse);
    });

    test('rejects a wrong token', () {
      expect(authenticator.authorize('Bearer other-token'), isFalse);
      expect(authenticator.authorize('Bearer Expected-Token'), isFalse);
      expect(authenticator.authorize('Bearer expected-token-extra'), isFalse);
    });

    test('rejects everything while no token is configured', () {
      final unconfigured = McpBearerAuthenticator(() => '');

      expect(unconfigured.authorize('Bearer '), isFalse);
      expect(unconfigured.authorize('Bearer anything'), isFalse);
    });

    test('reads the expected token on every call', () {
      var token = 'first';
      final rotating = McpBearerAuthenticator(() => token);

      expect(rotating.authorize('Bearer first'), isTrue);
      token = 'second';
      expect(rotating.authorize('Bearer first'), isFalse);
      expect(rotating.authorize('Bearer second'), isTrue);
    });
  });
}
