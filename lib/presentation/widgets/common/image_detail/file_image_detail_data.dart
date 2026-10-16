import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import '../../../../core/cache/local_file_image.dart';
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
  final Future<NaiImageMetadata?> Function(String path) _readCachedMetadata;
  NaiImageMetadata? _prefetchedMetadata;
  Future<void>? _pendingPrefetch;
  final bool _showCopyButton;
  final bool _showSaveAsButton;

  /// 图像最大维度阈值（超过此值会进行缩放优化）
  static const int _maxImageDimension = 4096;

  FileImageDetailData({
    required this.filePath,
    Uint8List? cachedBytes,
    String? id,
    NaiImageMetadata? initialMetadata,
    bool showCopyButton = true,
    bool showSaveAsButton = true,
    Future<NaiImageMetadata?> Function(String path)? readCachedMetadata,
  }) : _cachedBytes = cachedBytes,
       _id = id ?? filePath,
       _initialMetadata = initialMetadata,
       _readCachedMetadata =
           readCachedMetadata ?? ImageMetadataService().getCachedAsync,
       _showCopyButton = showCopyButton,
       _showSaveAsButton = showSaveAsButton;

  @override
  ImageProvider getImageProvider() {
    final fileImage = LocalFileImage(filePath);

    // 尝试从初始元数据或缓存获取元数据以进行缩放优化
    final cachedMetadata = _knownMetadata;
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

  /// 首帧前把 L2 命中取进来：L2 只能异步读，同步的 [metadata] 否则先空后填
  ///
  /// 读取在途时重复调用共享同一次读取，等待方超时放弃后读取照常完成。
  Future<void> prefetchMetadata() {
    if (_knownMetadata != null) return Future.value();
    return _pendingPrefetch ??= _readPrefetch().whenComplete(
      () => _pendingPrefetch = null,
    );
  }

  /// 预取仍在读盘；等待方先行显示后据此决定读完是否刷新
  bool get isPrefetchingMetadata => _pendingPrefetch != null;

  Future<void> _readPrefetch() async {
    try {
      _prefetchedMetadata = await _readCachedMetadata(filePath);
    } catch (error) {
      AppLogger.w(
        '[MetadataFlow] Metadata prefetch failed: path=$filePath, error=$error',
        'FileImageDetailData',
      );
    }
  }

  NaiImageMetadata? get _knownMetadata =>
      _initialMetadata ??
      _prefetchedMetadata ??
      ImageMetadataService().getCached(filePath);

  /// 同步获取元数据（初始传入、预取结果、L1 缓存依次兜底）
  @override
  NaiImageMetadata? get metadata {
    final result = _knownMetadata;
    AppLogger.d(
      '[MetadataFlow] FileImageDetailData.metadata sync: path=$filePath, hasInitial=${_initialMetadata != null}, result=${result?.hasData}',
      'FileImageDetailData',
    );
    return result;
  }

  /// 异步获取元数据（从文件解析）
  ///
  /// **前台高优先级调用** - 用户主动打开详情页时使用
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

    // 2. 检查预取结果与缓存
    final cached = _knownMetadata;
    if (cached != null) {
      AppLogger.i(
        '[MetadataFlow] Returning cached metadata: hasData=${cached.hasData}',
        'FileImageDetailData',
      );
      return cached;
    }

    // 3. 预取还在读 L2 时接着等它，不并行再读一次
    final pending = _pendingPrefetch;
    if (pending != null) {
      await pending;
      final prefetched = _knownMetadata;
      if (prefetched != null) {
        AppLogger.i(
          '[MetadataFlow] Returning prefetched metadata: hasData=${prefetched.hasData}',
          'FileImageDetailData',
        );
        return prefetched;
      }
    }

    // 4. 前台高优先级解析
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

  @override
  bool get isFavorite => false;

  @override
  String get identifier => _id ?? filePath;

  /// 异步获取文件信息（含大小与修改时间）
  Future<FileInfo> getFileInfoAsync() async {
    final stat = await File(filePath).stat();
    return FileInfo(
      path: filePath,
      fileName: p.basename(filePath),
      size: stat.type == FileSystemEntityType.notFound ? null : stat.size,
      modifiedAt: stat.type == FileSystemEntityType.notFound
          ? null
          : stat.modified,
    );
  }

  @override
  FileInfo get fileInfo =>
      FileInfo(path: filePath, fileName: p.basename(filePath));

  @override
  bool get showSaveButton => false;

  @override
  bool get showCopyButton => _showCopyButton;

  @override
  bool get showSaveAsButton => _showSaveAsButton;

  @override
  bool get showFavoriteButton => true;

  @override
  bool get preserveOriginalBytesOnSave => false;
}
