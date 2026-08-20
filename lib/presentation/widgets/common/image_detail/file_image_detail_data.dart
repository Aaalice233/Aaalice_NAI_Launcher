import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import '../../../../core/utils/app_logger.dart';
import '../../../../data/models/gallery/nai_image_metadata.dart';
import '../../../../data/services/image_metadata_service.dart';
import 'image_detail_data.dart';

/// 文件图像详情数据适配器
///
/// 从文件路径加载图像，并使用 ImageMetadataService 解析元数据
/// 用于主页生成的已保存图像和历史队列中的图像
class FileImageDetailData implements ImageDetailData {
  final String filePath;
  final Uint8List? _cachedBytes;
  final String? _id;
  final NaiImageMetadata? _initialMetadata;
  final bool _showCopyButton;

  /// 图像最大维度阈值（超过此值会进行缩放优化）
  static const int _maxImageDimension = 4096;

  FileImageDetailData({
    required this.filePath,
    Uint8List? cachedBytes,
    String? id,
    NaiImageMetadata? initialMetadata,
    bool showCopyButton = true,
  }) : _cachedBytes = cachedBytes,
       _id = id ?? filePath,
       _initialMetadata = initialMetadata,
       _showCopyButton = showCopyButton;

  @override
  ImageProvider getImageProvider() {
    final fileImage = FileImage(File(filePath));

    // 尝试从初始元数据或缓存获取元数据以进行缩放优化
    final cachedMetadata =
        _initialMetadata ?? ImageMetadataService().getCached(filePath);
    if (cachedMetadata != null) {
      final width = cachedMetadata.width ?? 0;
      final height = cachedMetadata.height ?? 0;

      if (width > _maxImageDimension || height > _maxImageDimension) {
        final int? targetWidth;
        final int? targetHeight;

        if (width > height) {
          targetWidth = _maxImageDimension;
          targetHeight = null;
        } else {
          targetWidth = null;
          targetHeight = _maxImageDimension;
        }

        return ResizeImage(fileImage, width: targetWidth, height: targetHeight);
      }
    }

    return fileImage;
  }

  @override
  Future<Uint8List> getImageBytes() async {
    if (_cachedBytes != null) {
      return _cachedBytes;
    }
    return File(filePath).readAsBytes();
  }

  /// 同步获取元数据（优先使用初始传入的元数据，其次从缓存获取）
  @override
  NaiImageMetadata? get metadata {
    final result =
        _initialMetadata ?? ImageMetadataService().getCached(filePath);
    AppLogger.d(
      '[MetadataFlow] FileImageDetailData.metadata sync: path=$filePath, hasInitial=${_initialMetadata != null}, result=${result?.hasData}',
      'FileImageDetailData',
    );
    return result;
  }

  /// 异步获取元数据（从文件解析）
  ///
  /// **前台高优先级调用** - 用户主动打开详情页时使用
  /// 不受后台预加载队列影响，立即开始解析
  Future<NaiImageMetadata?> getMetadataAsync() async {
    AppLogger.i(
      '[MetadataFlow] getMetadataAsync START: path=$filePath',
      'FileImageDetailData',
    );

    // 1. 先检查初始元数据
    if (_initialMetadata != null) {
      AppLogger.i(
        '[MetadataFlow] Returning initial metadata',
        'FileImageDetailData',
      );
      return _initialMetadata;
    }

    // 2. 检查缓存
    final cached = ImageMetadataService().getCached(filePath);
    if (cached != null) {
      AppLogger.i(
        '[MetadataFlow] Returning cached metadata: hasData=${cached.hasData}',
        'FileImageDetailData',
      );
      return cached;
    }

    // 3. 前台立即解析（高优先级，不受后台队列影响）
    AppLogger.i(
      '[MetadataFlow] No cache, calling getMetadataImmediate...',
      'FileImageDetailData',
    );
    final result = await ImageMetadataService().getMetadataImmediate(filePath);
    AppLogger.i(
      '[MetadataFlow] getMetadataImmediate returned: hasData=${result?.hasData}',
      'FileImageDetailData',
    );
    return result;
  }

  /// 预加载元数据（后台使用）
  void preloadMetadata() {
    ImageMetadataService().preload(filePath);
  }

  @override
  bool get isFavorite => false;

  @override
  String get identifier => _id ?? filePath;

  /// 异步获取文件信息
  ///
  /// 使用异步文件操作避免阻塞 UI 线程
  Future<FileInfo> getFileInfoAsync() async {
    final file = File(filePath);
    final stat = await file.stat();
    return FileInfo(
      path: filePath,
      fileName: p.basename(filePath),
      size: stat.size,
      modifiedAt: stat.modified,
    );
  }

  @override
  FileInfo get fileInfo {
    // 同步回退：返回默认值，实际数据通过 getFileInfoAsync 获取
    // 警告：同步获取文件信息可能在文件系统繁忙时阻塞 UI
    final file = File(filePath);
    try {
      return FileInfo(
        path: filePath,
        fileName: p.basename(filePath),
        size: file.lengthSync(),
        modifiedAt: file.lastModifiedSync(),
      );
    } catch (_) {
      // 如果同步获取失败，返回默认值
      return FileInfo(
        path: filePath,
        fileName: p.basename(filePath),
        size: 0,
        modifiedAt: DateTime.now(),
      );
    }
  }

  @override
  bool get showSaveButton => false;

  @override
  bool get showCopyButton => _showCopyButton;

  @override
  bool get showFavoriteButton => true;

  @override
  bool get preserveOriginalBytesOnSave => false;
}
