import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';

void main() {
  group('PlatformCapabilities', () {
    test('Android exposes touch-platform integrations only', () {
      final capabilities = PlatformCapabilities.forPlatform(
        TargetPlatform.android,
      );

      expect(capabilities.isMobile, isTrue);
      expect(capabilities.supportsNativeShare, isTrue);
      expect(capabilities.supportsDesktopWindowControls, isFalse);
      expect(capabilities.supportsSystemTray, isFalse);
      expect(capabilities.supportsExternalFileDrop, isFalse);
      expect(capabilities.supportsOpenFolder, isFalse);
      expect(capabilities.supportsComfyUiIntegration, isFalse);
      expect(capabilities.supportsDesktopOverlayInteractions, isFalse);
      expect(capabilities.supportsKeyboardShortcutConfiguration, isFalse);
      expect(capabilities.supportsKritaBridge, isFalse);
      expect(capabilities.supportsMcpServer, isFalse);
      expect(capabilities.supportsSystemFontEnumeration, isFalse);
      expect(capabilities.supportsInAppPackageInstall, isTrue);
      expect(capabilities.requiresExternalInstallerFlow, isTrue);
    });

    test('Windows exposes desktop integrations', () {
      final capabilities = PlatformCapabilities.forPlatform(
        TargetPlatform.windows,
      );

      expect(capabilities.isDesktop, isTrue);
      expect(capabilities.supportsDesktopWindowControls, isTrue);
      expect(capabilities.supportsSystemTray, isTrue);
      expect(capabilities.supportsExternalFileDrop, isTrue);
      expect(capabilities.supportsOpenFolder, isTrue);
      expect(capabilities.supportsComfyUiIntegration, isTrue);
      expect(capabilities.supportsDesktopOverlayInteractions, isTrue);
      expect(capabilities.supportsKeyboardShortcutConfiguration, isTrue);
      expect(capabilities.supportsKritaBridge, isTrue);
      expect(capabilities.supportsMcpServer, isTrue);
      expect(capabilities.supportsSystemFontEnumeration, isTrue);
      expect(capabilities.supportsInAppPackageInstall, isTrue);
      expect(capabilities.requiresExternalInstallerFlow, isFalse);
    });

    test('macOS and Linux also host the local MCP server', () {
      for (final platform in [TargetPlatform.macOS, TargetPlatform.linux]) {
        final capabilities = PlatformCapabilities.forPlatform(platform);
        expect(capabilities.supportsMcpServer, isTrue, reason: '$platform');
      }
      expect(
        PlatformCapabilities.forPlatform(TargetPlatform.iOS).supportsMcpServer,
        isFalse,
      );
    });

    test('current honors an isolated capability override', () {
      PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
        TargetPlatform.windows,
      );
      try {
        expect(PlatformCapabilities.current.supportsExternalFileDrop, isTrue);
      } finally {
        PlatformCapabilities.debugOverride = null;
      }
    });
  });
}
