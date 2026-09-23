import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/network/browser_identity/chrome_grease_brands.dart';
import 'package:nai_launcher/core/network/browser_identity/chrome_identity.dart';

void main() {
  group('buildChromeSecChUa', () {
    test('reproduces the brand lists shipped by real Chrome builds', () {
      expect(
        buildChromeSecChUa(140),
        '"Chromium";v="140", "Not=A?Brand";v="24", "Google Chrome";v="140"',
      );
      expect(
        buildChromeSecChUa(141),
        '"Google Chrome";v="141", "Not?A_Brand";v="8", "Chromium";v="141"',
      );
    });

    test('derives the configured major version', () {
      expect(
        buildChromeSecChUa(152),
        '"Chromium";v="152", "Not?A_Brand";v="24", "Google Chrome";v="152"',
      );
    });

    test('always lists three brands', () {
      for (var major = 100; major < 200; major++) {
        expect(buildChromeSecChUa(major).split(', '), hasLength(3));
      }
    });
  });

  group('ChromeIdentity', () {
    test('derives Windows headers', () {
      const identity = ChromeIdentity(platform: ChromePlatform.windows);

      expect(
        identity.userAgent,
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/152.0.0.0 Safari/537.36',
      );
      expect(identity.secChUaPlatform, '"Windows"');
      expect(identity.secChUaMobile, '?0');
    });

    test('derives macOS headers', () {
      const identity = ChromeIdentity(platform: ChromePlatform.macOS);

      expect(
        identity.userAgent,
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/152.0.0.0 Safari/537.36',
      );
      expect(identity.secChUaPlatform, '"macOS"');
      expect(identity.secChUaMobile, '?0');
    });

    test('derives Android headers with the mobile token', () {
      const identity = ChromeIdentity(platform: ChromePlatform.android);

      expect(
        identity.userAgent,
        'Mozilla/5.0 (Linux; Android 10; K) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/152.0.0.0 Mobile Safari/537.36',
      );
      expect(identity.secChUaPlatform, '"Android"');
      expect(identity.secChUaMobile, '?1');
    });

    test('derives Linux headers', () {
      const identity = ChromeIdentity(platform: ChromePlatform.linux);

      expect(
        identity.userAgent,
        'Mozilla/5.0 (X11; Linux x86_64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/152.0.0.0 Safari/537.36',
      );
      expect(identity.secChUaPlatform, '"Linux"');
      expect(identity.secChUaMobile, '?0');
    });

    test('keeps user agent and client hints on one version constant', () {
      const identity = ChromeIdentity(
        platform: ChromePlatform.windows,
        majorVersion: 199,
      );

      expect(identity.userAgent, contains('Chrome/199.0.0.0'));
      expect(identity.secChUa, contains('"Chromium";v="199"'));
    });

    test('maps unsupported target platforms to Windows', () {
      expect(
        ChromePlatform.fromTargetPlatform(TargetPlatform.iOS),
        ChromePlatform.windows,
      );
      expect(
        ChromePlatform.fromTargetPlatform(TargetPlatform.fuchsia),
        ChromePlatform.windows,
      );
      expect(
        ChromePlatform.fromTargetPlatform(TargetPlatform.macOS),
        ChromePlatform.macOS,
      );
      expect(
        ChromePlatform.fromTargetPlatform(TargetPlatform.android),
        ChromePlatform.android,
      );
      expect(
        ChromePlatform.fromTargetPlatform(TargetPlatform.linux),
        ChromePlatform.linux,
      );
    });

    test('reads the running platform', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      expect(ChromeIdentity.current().platform, ChromePlatform.android);
    });
  });
}
