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
  bool get supportsDlssEnhancement => isWindows;
  bool get supportsDesktopOverlayInteractions => isDesktop;
  bool get supportsKeyboardShortcutConfiguration => isDesktop;
  bool get supportsKritaBridge => isDesktop;
  bool get supportsSystemFontEnumeration => isWindows;
  bool get supportsNativeShare => isMobile || isMacOS;

  /// 保存/出图后是否**自动**把图片发布进系统相册。
  ///
  /// 【偏离上游的关键点：这一位必须保持 `isAndroid`，绝不能改成 `isMobile`】
  ///
  /// 上游把这一位当作「移动端相册能力」使用：`image_generation_provider.dart`
  /// 的 `publishToSystemGallery` 回调、`generation_save_service`、`image_preview`、
  /// `image_card_actions`、`local_image_context_menu`、mosaic / watermark 编辑器
  /// 等共约 10 个调用点，只要这一位为真就**无条件**调 `AndroidMediaStoreService`
  /// 把图写进系统相册，且没有任何设置项可以关掉。
  ///
  /// 我们的产品决定（用户点名）是「保存只写应用自管的本地图库，进系统相册必须是
  /// 用户主动点的独立动作」；而且 `AndroidMediaStoreService` 走的是 Android 的
  /// MethodChannel，iOS 侧没有对应实现，打开这一位在 iOS 上还会直接抛异常。
  ///
  /// iOS 的相册能力改由下面的 [supportsExplicitPhotoLibraryExport] 提供，
  /// 那一位**只**被手动入口（详情页「保存到相册」菜单项）消费。
  bool get supportsSystemGalleryExport => isAndroid;

  /// iOS 上「保存到系统相册」这个**显式手动动作**是否可用
  /// （由 `IosPhotoLibraryService` / gal + `Gal.requestAccess` 实现）。
  ///
  /// 【上游没有这一位】新增它的唯一目的，是在不打开
  /// [supportsSystemGalleryExport] 的前提下给 iOS 补上相册导出能力。
  /// 消费方仅限用户主动触发的菜单/按钮，**绝不能**接到
  /// `image_generation_provider` 的 `publishToSystemGallery` 自动回调上。
  bool get supportsExplicitPhotoLibraryExport => isIOS;

  /// 平台是否有「由系统接管落地位置」的文件导出通道，
  /// 因而不能使用桌面那套 `FilePicker.saveFile` 另存为对话框。
  ///
  /// 【偏离上游：上游是 `isAndroid`，这里放宽到 `isMobile`】
  /// 上游只考虑了 Android 的 SAF（文档 URI）。iOS 同样没有另存为对话框：
  /// file_picker 的 `file_picker_io.dart` 在 iOS/Android 下若 `bytes == null`
  /// 会直接 `throw ArgumentError`，所以上游「非 Android 就走 FilePicker.saveFile」
  /// 的分支在 iOS 上是 100% 抛异常。两端的后端不同（Android=SAF，
  /// iOS=临时文件 + 系统分享面板），差异封装在 `FileExportService` 内部。
  bool get supportsDocumentFileExport => isMobile;

  /// 平台是否只能通过「选文件导入到应用自管目录」而不是「选一个目录长期引用」
  /// 来获取外部文件。
  ///
  /// 【偏离上游：上游是 `isAndroid`，这里放宽到 `isMobile`】
  /// iOS 的 `FilePicker.getDirectoryPath` 返回的是一次性 security-scoped 路径，
  /// 跨启动即失效——界面会显示「已配置」但实际扫不到任何文件。
  bool get supportsManagedFileImports => isMobile;

  /// 是否支持「先让用户选一个输出目录，再往里批量写文件」的导出形态。
  ///
  /// 【上游没有这一位】iOS 拿不到可长期写入的目录（见
  /// [supportsManagedFileImports]），`FileExportService.pickExportDirectory`
  /// 在 iOS 上直接返回 null。入口应该用这一位整体隐藏，而不是留一个点了没反应的按钮。
  bool get supportsDirectoryBatchExport => !isIOS;

  /// 是否允许应用自己检查/提示版本更新。
  ///
  /// 【上游没有这一位】iOS 侧没有任何可用的安装通道（无 APK、无 Windows 安装器），
  /// 自检更新只会把桌面/安卓安装包推给 iPhone，因此整条更新链路在 iOS 关闭。
  bool get supportsAutomaticUpdateCheck => !isIOS;

  bool get supportsInAppPackageInstall => isWindows || isAndroid;
  bool get requiresExternalInstallerFlow => isAndroid;
}
