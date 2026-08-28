import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/network/web_access/web_access_models.dart';

void main() {
  group('WebAccessConfig', () {
    test('round-trips persisted fields', () {
      const config = WebAccessConfig(
        enabled: true,
        mode: WebSearchMode.exaMcp,
        searxngBaseUrl: 'http://127.0.0.1:8080',
        defaultResultCount: 8,
      );

      final decoded = WebAccessConfig.decode(config.encode());

      expect(decoded.enabled, isTrue);
      expect(decoded.mode, WebSearchMode.exaMcp);
      expect(decoded.searxngBaseUrl, 'http://127.0.0.1:8080');
      expect(decoded.defaultResultCount, 8);
    });

    test('uses conservative defaults and clamps result count', () {
      final decoded = WebAccessConfig.decode(
        '{"mode":"future","defaultResultCount":99}',
      );

      expect(decoded.enabled, isFalse);
      expect(decoded.mode, WebSearchMode.auto);
      expect(decoded.defaultResultCount, WebAccessConfig.maxResultCount);
    });
  });
}
