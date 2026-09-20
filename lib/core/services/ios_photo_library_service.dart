
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;

import '../platform/platform_capabilities.dart';

/// 「保存到系统相册」这个**显式手动动作**的结果。
enum PhotoLibrarySaveOutcome {
  /// 已写入系统相册。
  saved,

  /// 当前平台没有这条通道（非 iOS）。调用方应当先用
  /// [IosPhotoLibraryService.isSupported] 把入口隐藏掉，正常不会拿到这个值。
  unsupported,

  /// 用户拒绝了相册写入权限。
  permissionDenied,

  /// 其他失败（空间不足、系统异常等），详情见 [PhotoLibrarySaveResult.error]。
  failed,
}

@immutable
class PhotoLibrarySaveResult {
  const PhotoLibrarySaveResult(this.outcome, {this.error});

  final PhotoLibrarySaveOutcome outcome;
  final Object? error;

  bool get isSaved => outcome == PhotoLibrarySaveOutcome.saved;

  @override
  String toString() =>
      'PhotoLibrarySaveResult(${outcome.name}${error == null ? '' : ', $error'})';
}

/// iOS 上把图片写进系统相册的唯一通道（gal / PHPhotoLibrary）。
///
/// 【上游没有这个服务，而且它刻意不是 `AndroidMediaStoreService` 的 iOS 版】
///
/// 上游在 Android 上的行为是「出图/保存即自动发布到系统相册」：
/// `image_generation_provider` 的 `publishToSystemGallery` 回调等约 10 个调用点
/// 都由 `PlatformCapabilities.supportsSystemGalleryExport` 一个开关统一放行，
/// 且没有任何设置项能关。我们的产品决定（用户点名）是
/// **保存只写应用自管的本地图库，进系统相册必须由用户主动触发**。
///
/// 因此本服务：
/// - 只由 [PlatformCapabilities.supportsExplicitPhotoLibraryExport] 门控，
///   与 `supportsSystemGalleryExport` 完全解耦；
/// - **禁止**接到任何自动保存回调上（`publishToSystemGallery`、
///   `generation_save_service` 的保存链路等），只接详情页 / 卡片菜单里
///   用户点的那一个「保存到相册」条目。
///
/// 需要 Info.plist 的 `NSPhotoLibraryAddUsageDescription`（仅新增权限，
/// 不读取用户相册）。
class IosPhotoLibraryService {
  IosPhotoLibraryService._();

  /// 入口是否应当出现。消费方必须先判这一位再显示菜单项。
  static bool get isSupported =>
      PlatformCapabilities.operatingSystem.supportsExplicitPhotoLibraryExport;

  static Future<PhotoLibrarySaveResult> saveImageBytes({
    required Uint8List bytes,
    String? fileName,
  }) {
    return _guard(
      () => Gal.putImageBytes(bytes, name: albumItemNameFor(fileName)),
    );
  }

  static Future<PhotoLibrarySaveResult> saveImageFile({required String path}) {
    return _guard(() => Gal.putImage(path));
  }

  static Future<PhotoLibrarySaveResult> _guard(
    Future<void> Function() write,
  ) async {
    if (!isSupported) {
      return const PhotoLibrarySaveResult(PhotoLibrarySaveOutcome.unsupported);
    }
    try {
      // 先请求「仅添加」权限；用户拒绝时直接返回，不要让 gal 再抛一次。
      final hasAccess = await Gal.requestAccess();
      if (!hasAccess) {
        return const PhotoLibrarySaveResult(
          PhotoLibrarySaveOutcome.permissionDenied,
        );
      }
      await write();
      return const PhotoLibrarySaveResult(PhotoLibrarySaveOutcome.saved);
    } on GalException catch (error) {
      return PhotoLibrarySaveResult(
        error.type == GalExceptionType.accessDenied
            ? PhotoLibrarySaveOutcome.permissionDenied
            : PhotoLibrarySaveOutcome.failed,
        error: error,
      );
    } catch (error) {
      return PhotoLibrarySaveResult(
        PhotoLibrarySaveOutcome.failed,
        error: error,
      );
    }
  }

  /// gal 的 `name` 是相册条目名，不带扩展名，且不可为空（默认 `'image'`）。
  @visibleForTesting
  static String albumItemNameFor(String? fileName) {
    final leaf = p.basename((fileName ?? '').trim());
    if (leaf.isEmpty) return 'image';
    final base = p.basenameWithoutExtension(leaf).trim();
    return base.isEmpty ? 'image' : base;
  }
}
