import 'dart:io' as io;

import 'package:flutter/foundation.dart';

/// Centralized platform feature matrix.
///
/// Layout decisions still belong to the adaptive presentation layer. This
/// class only answers whether an operating-system integration exists, keeping
/// platform checks out of feature screens.
@immutable
class PlatformCapabilities {
  const PlatformCapabilities._({required this.platform});

  factory PlatformCapabilities.forPlatform(TargetPlatform platform) {
    return PlatformCapabilities._(platform: platform);
  }

  /// Capabilities for the platform selected by Flutter's presentation layer.
  ///
  /// Platform services that must work before a Flutter binding exists should
  /// use [operatingSystem] instead.
  static PlatformCapabilities get current =>
      debugOverride ?? PlatformCapabilities.forPlatform(defaultTargetPlatform);

  /// Allows widget tests to exercise desktop and touch capability branches
  /// without mutating Flutter's global platform debug state.
  @visibleForTesting
  static PlatformCapabilities? debugOverride;

  static PlatformCapabilities get operatingSystem {
    if (io.Platform.isAndroid) {
      return PlatformCapabilities.forPlatform(TargetPlatform.android);
    }
    if (io.Platform.isIOS) {
      return PlatformCapabilities.forPlatform(TargetPlatform.iOS);
    }
    if (io.Platform.isWindows) {
      return PlatformCapabilities.forPlatform(TargetPlatform.windows);
    }
    if (io.Platform.isMacOS) {
      return PlatformCapabilities.forPlatform(TargetPlatform.macOS);
    }
    return PlatformCapabilities.forPlatform(TargetPlatform.linux);
  }

  final TargetPlatform platform;

  bool get isAndroid => platform == TargetPlatform.android;
  bool get isIOS => platform == TargetPlatform.iOS;
  bool get isMobile => isAndroid || isIOS;
  bool get isWindows => platform == TargetPlatform.windows;
  bool get isMacOS => platform == TargetPlatform.macOS;
  bool get isLinux => platform == TargetPlatform.linux;
  bool get isDesktop => isWindows || isMacOS || isLinux;

  bool get supportsDesktopWindowControls => isDesktop;
  bool get supportsSystemTray => isDesktop;
  bool get supportsExternalFileDrop => isDesktop;
  bool get supportsOpenFolder => isDesktop;
  bool get supportsCustomStorageDirectories => isDesktop;
  bool get usesAppManagedStorage => isMobile;
  bool get supportsComfyUiIntegration => isDesktop;
  bool get supportsDesktopOverlayInteractions => isDesktop;
  bool get supportsKeyboardShortcutConfiguration => isDesktop;
  bool get supportsKritaBridge => isDesktop;
  bool get supportsSystemFontEnumeration => isWindows;
  bool get supportsNativeShare => isMobile || isMacOS;
  bool get supportsSystemGalleryExport => isAndroid;
  bool get supportsDocumentFileExport => isAndroid;
  bool get supportsManagedFileImports => isAndroid;
  bool get supportsInAppPackageInstall => isWindows || isAndroid;
  bool get requiresExternalInstallerFlow => isAndroid;
}
