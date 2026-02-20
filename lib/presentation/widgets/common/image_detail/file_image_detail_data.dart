import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

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

  /// 图像最大维度阈值（超过此值会进行缩放优化）
  static const int _maxImageDimension = 4096;

  FileImageDetailData({
    required this.filePath,
    Uint8List? cachedBytes,
    String? id,
    NaiImageMetadata? initialMetadata,
  })  : _cachedBytes = cachedBytes,
        _id = id ?? filePath,
        _initialMetadata = initialMetadata;

  @override
  ImageProvider getImageProvider() {
    final fileImage = FileImage(File(filePath));

    // 尝试从初始元数据或缓存获取元数据以进行缩放优化
    final cachedMetadata = _initialMetadata ?? ImageMetadataService().getCached(filePath);
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

        return ResizeImage(
          fileImage,
          width: targetWidth,
          height: targetHeight,
        );
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
  NaiImageMetadata? get metadata =>
      _initialMetadata ?? ImageMetadataService().getCached(filePath);

  /// 异步获取元数据（从文件解析）
  ///
  /// **前台高优先级调用** - 用户主动打开详情页时使用
  /// 不受后台预加载队列影响，立即开始解析
  Future<NaiImageMetadata?> getMetadataAsync() async {
    // 1. 先检查初始元数据
    if (_initialMetadata != null) return _initialMetadata;
    
    // 2. 检查缓存
    final cached = ImageMetadataService().getCached(filePath);
    if (cached != null) return cached;

    // 3. 前台立即解析（高优先级，不受后台队列影响）
    return ImageMetadataService().getMetadataImmediate(filePath);
  }

  /// 预加载元数据（后台使用）
  void preloadMetadata() {
    ImageMetadataService().preload(filePath);
  }

  @override
  bool get isFavorite => false;

  @override
  String get identifier => _id ?? filePath;

  @override
  FileInfo get fileInfo => FileInfo(
        path: filePath,
        fileName: p.basename(filePath),
        size: File(filePath).lengthSync(),
        modifiedAt: File(filePath).lastModifiedSync(),
      );

  @override
  bool get showSaveButton => false;

  @override
  bool get showFavoriteButton => true;
}
