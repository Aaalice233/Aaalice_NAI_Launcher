import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/mcp/mcp_origin_policy.dart';

void main() {
  group('McpOriginPolicy.allows', () {
    test('allows requests without an Origin header', () {
      expect(McpOriginPolicy.allows(null), isTrue);
      expect(McpOriginPolicy.allows(''), isTrue);
      expect(McpOriginPolicy.allows('   '), isTrue);
    });

    test('allows loopback origins on http and https', () {
      expect(McpOriginPolicy.allows('http://127.0.0.1:5173'), isTrue);
      expect(McpOriginPolicy.allows('http://localhost'), isTrue);
      expect(McpOriginPolicy.allows('https://localhost:3000'), isTrue);
      expect(McpOriginPolicy.allows('http://[::1]:8080'), isTrue);
      expect(McpOriginPolicy.allows('HTTP://LOCALHOST:1'), isTrue);
      expect(McpOriginPolicy.allows('  http://127.0.0.1  '), isTrue);
    });

    test('rejects remote origins, including loopback-looking hostnames', () {
      expect(McpOriginPolicy.allows('http://evil.com'), isFalse);
      expect(McpOriginPolicy.allows('http://127.0.0.1.evil.com'), isFalse);
      expect(McpOriginPolicy.allows('https://localhost.evil.com'), isFalse);
    });

    test('rejects opaque and non-http origins', () {
      expect(McpOriginPolicy.allows('null'), isFalse);
      expect(McpOriginPolicy.allows('file:///tmp'), isFalse);
      expect(McpOriginPolicy.allows('ws://127.0.0.1'), isFalse);
    });

    test('rejects unparsable origins', () {
      expect(McpOriginPolicy.allows('::::'), isFalse);
      expect(McpOriginPolicy.allows('http://[bad'), isFalse);
    });
  });
}
