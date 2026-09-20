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
      expect(capabilities.supportsSystemFontEnumeration, isFalse);
      expect(capabilities.supportsInAppPackageInstall, isTrue);
      expect(capabilities.requiresExternalInstallerFlow, isTrue);
    });

    test('iOS never auto-publishes to the system gallery', () {
      final ios = PlatformCapabilities.forPlatform(TargetPlatform.iOS);
      final android = PlatformCapabilities.forPlatform(TargetPlatform.android);

      // 回归钉子（不要"顺手"把这一位改成 isMobile）：
      // supportsSystemGalleryExport 守着约 10 个 AndroidMediaStoreService 调用点，
      // 它们在这一位为真时**无条件**把每张保存/生成的图发布进系统相册，
      // 且没有任何设置项能关。iOS 上打开它既违背"保存不自动进相册"的产品决定，
      // 也会因为 iOS 没有 AndroidMediaStoreService 的实现而直接抛异常。
      expect(ios.supportsSystemGalleryExport, isFalse);
      // iOS 的相册能力走这一条独立能力位，只被用户手动触发的入口消费。
      expect(ios.supportsExplicitPhotoLibraryExport, isTrue);
      expect(android.supportsExplicitPhotoLibraryExport, isFalse);
    });

    test('iOS routes file IO away from desktop-only dialogs', () {
      final ios = PlatformCapabilities.forPlatform(TargetPlatform.iOS);

      // 没有另存为对话框：导出必须走 FileExportService 的临时文件 + 分享面板。
      expect(ios.supportsDocumentFileExport, isTrue);
      // 没有可长期写入的目录：只能"选文件导入到应用自管目录"。
      expect(ios.supportsManagedFileImports, isTrue);
      expect(ios.supportsDirectoryBatchExport, isFalse);
      // 没有任何可用的安装通道，整条更新链路关闭。
      expect(ios.supportsAutomaticUpdateCheck, isFalse);
      expect(
        PlatformCapabilities.forPlatform(
          TargetPlatform.windows,
        ).supportsAutomaticUpdateCheck,
        isTrue,
      );
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
      expect(capabilities.supportsSystemFontEnumeration, isTrue);
      expect(capabilities.supportsInAppPackageInstall, isTrue);
      expect(capabilities.requiresExternalInstallerFlow, isFalse);
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
