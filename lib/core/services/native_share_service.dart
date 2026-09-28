import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../platform/platform_capabilities.dart';
import '../utils/media_mime_type.dart';

/// Shares in-memory images through the operating system share sheet.
class NativeShareService {
  NativeShareService._();

  static Future<ShareResult> shareImage({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
    Rect? sharePositionOrigin,
  }) {
    final resolvedMimeType =
        mimeType ??
        mediaMimeTypeForExtension(p.extension(fileName), fallback: 'image/*');
    return Share.shareXFiles([
      XFile.fromData(bytes, mimeType: resolvedMimeType, name: fileName),
    ], sharePositionOrigin: resolveSharePositionOrigin(sharePositionOrigin));
  }

  /// 把一个已落地的文件交给系统分享面板。
  ///
  /// 【上游没有这个方法】iOS 没有「另存为」对话框，`FileExportService` 的 iOS
  /// 分支要靠分享面板把导出文件交给「文件」App / AirDrop / 其他应用，
  /// 而按路径分享可以避免把大文件（ZIP、模型包）整份读进内存。
  static Future<ShareResult> shareFile({
    required String path,
    String? fileName,
    String? mimeType,
    Rect? sharePositionOrigin,
  }) {
    final resolvedName = fileName ?? p.basename(path);
    final resolvedMimeType =
        mimeType ??
        mediaMimeTypeForExtension(
          p.extension(resolvedName),
          fallback: 'application/octet-stream',
        );
    return Share.shareXFiles([
      XFile(path, mimeType: resolvedMimeType, name: resolvedName),
    ], sharePositionOrigin: resolveSharePositionOrigin(sharePositionOrigin));
  }

  /// 【上游没有这段兜底】iPad 上 `UIActivityViewController` 以 popover 呈现，
  /// 必须有一个非空的锚点矩形，否则系统会在呈现时抛异常 / 把面板钉在屏幕左上角。
  /// 上游的两个调用点（`mosaic_editor_screen._share`、
  /// `watermark_editor_screen._shareImage`）都没有传 `sharePositionOrigin`，
  /// 而它们不在本车道的文件集内，所以兜底放在服务内部：iOS 下若调用方没给锚点，
  /// 就退化成屏幕正中的 1×1 矩形。非 iOS 平台保持上游行为（原样透传，含 null）。
  static Rect? resolveSharePositionOrigin(Rect? origin) {
    return resolveSharePositionOriginFor(
      origin: origin,
      isIOS: PlatformCapabilities.operatingSystem.isIOS,
      viewSize: _implicitViewSize(),
    );
  }

  @visibleForTesting
  static Rect? resolveSharePositionOriginFor({
    required Rect? origin,
    required bool isIOS,
    required Size? viewSize,
  }) {
    if (!isIOS) return origin;
    if (origin != null && origin.width > 0 && origin.height > 0) return origin;
    if (viewSize == null || viewSize.isEmpty) return origin;
    return Rect.fromCenter(
      center: Offset(viewSize.width / 2, viewSize.height / 2),
      width: 1,
      height: 1,
    );
  }

  /// 读屏幕逻辑尺寸时刻意不经过 `WidgetsBinding`，这样分享服务不依赖绑定初始化。
  static Size? _implicitViewSize() {
    final dispatcher = ui.PlatformDispatcher.instance;
    final view =
        dispatcher.implicitView ??
        (dispatcher.views.isEmpty ? null : dispatcher.views.first);
    if (view == null) return null;
    final ratio = view.devicePixelRatio;
    if (ratio <= 0) return null;
    final size = view.physicalSize / ratio;
    return size.isEmpty ? null : size;
  }
}
