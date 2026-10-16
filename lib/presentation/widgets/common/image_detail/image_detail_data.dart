import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import '../../../../core/cache/local_file_image.dart';
import '../../../../data/models/gallery/local_image_record.dart';
import '../../../../data/models/gallery/nai_image_metadata.dart';
import '../../../../data/models/fixed_tag/fixed_tag_usage_snapshot.dart';
import '../../../../data/services/image_metadata_service.dart';

/// 图像详情数据抽象接口
///
/// 通过适配器模式统一两种数据源：
/// - 本地图库：使用 [LocalImageDetailData]
/// - 生成图像：使用 [GeneratedImageDetailData]
abstract class ImageDetailData {
  /// 获取图像提供者（用于显示）
  ImageProvider getImageProvider();

  /// 获取原始图像字节（用于保存）
  Future<Uint8List> getImageBytes();

  /// 获取元数据
  NaiImageMetadata? get metadata;

  /// 是否收藏
  bool get isFavorite;

  /// 图像唯一标识
  String get identifier;

  /// 文件信息（可选，本地图库有）
  FileInfo? get fileInfo;

  /// 是否需要显示保存按钮（生成图像需要，本地图库不需要）
  bool get showSaveButton;

  /// 是否需要显示复制按钮
  bool get showCopyButton;

  /// 是否允许另存为副本；已存入图库的图没有保存按钮但仍可另存为
  bool get showSaveAsButton;

  /// 是否需要显示收藏按钮
  bool get showFavoriteButton;

  /// 保存时是否必须保持当前图像字节不变。
  bool get preserveOriginalBytesOnSave;

  /// 完整元数据，同步读不到时再解析图像；默认就是 [metadata]
  Future<NaiImageMetadata?> getMetadataAsync() async => metadata;

  /// 切到这张图之前把需要读盘的元数据取进来，首帧的 [metadata] 就能同步读到；默认无需预取
  Future<void> prefetchMetadata() => Future.value();

  /// 预取仍在读取；等待方先行显示后据此决定读完是否刷新
  bool get isPrefetchingMetadata => false;

  /// 需要读盘才能补全的文件信息；[fileInfo] 已经完整时返回 null
  Future<FileInfo?> getFileInfoAsync() async => null;
}

/// 文件信息
///
/// [size] 与 [modifiedAt] 需要磁盘 IO，只有异步取到才有值；未知时留空不展示。
class FileInfo {
  final String path;
  final String fileName;
  final int? size;
  final DateTime? modifiedAt;

  const FileInfo({
    required this.path,
    required this.fileName,
    this.size,
    this.modifiedAt,
  });
}

/// 本地图库图像数据适配器
///
/// 包含大图内存优化：超过阈值的图像会使用 ResizeImage 限制内存占用
class LocalImageDetailData extends ImageDetailData {
  final LocalImageRecord record;
  final bool Function(String path)? getFavoriteStatus;

  /// 图像最大维度阈值（超过此值会进行缩放优化）
  static const int _maxImageDimension = 4096;

  LocalImageDetailData(this.record, {this.getFavoriteStatus});

  @override
  ImageProvider getImageProvider() {
    final meta = metadata;
    final fileImage = LocalFileImage(record.path);

    // 无元数据时无法预判尺寸，仍要限制解码上限以避免超大图片撑爆内存。
    if (meta == null) {
      return ResizeImage(
        fileImage,
        width: _maxImageDimension,
        height: _maxImageDimension,
        policy: ResizeImagePolicy.fit,
      );
    }

    // 如果有元数据且图像尺寸超过阈值，使用 ResizeImage 限制内存
    final width = meta.width ?? 0;
    final height = meta.height ?? 0;

    if (width > _maxImageDimension || height > _maxImageDimension) {
      // 计算缩放后的尺寸，保持宽高比
      final int? targetWidth;
      final int? targetHeight;

      if (width > height) {
        targetWidth = _maxImageDimension;
        targetHeight = null; // 保持宽高比
      } else {
        targetWidth = null;
        targetHeight = _maxImageDimension;
      }

      return ResizeImage(fileImage, width: targetWidth, height: targetHeight);
    }

    return fileImage;
  }

  @override
  Future<Uint8List> getImageBytes() async {
    return File(record.path).readAsBytes();
  }

  @override
  NaiImageMetadata? get metadata =>
      record.metadata?.upgradeFromRawJsonIfNeeded();

  /// 图库记录没有元数据时从文件解析
  @override
  Future<NaiImageMetadata?> getMetadataAsync() async {
    final recordMetadata = metadata;
    if (recordMetadata != null) return recordMetadata;

    // 服务已在后台 isolate 走完整条解析链，这里再兜底解析只会重复同一次整图解码。
    return ImageMetadataService().getMetadataImmediate(record.path);
  }

  @override
  bool get isFavorite =>
      getFavoriteStatus?.call(record.path) ?? record.isFavorite;

  @override
  String get identifier => record.path;

  @override
  FileInfo get fileInfo => FileInfo(
    path: record.path,
    fileName: p.basename(record.path),
    size: record.size,
    modifiedAt: record.modifiedAt,
  );

  @override
  bool get showSaveButton => false;

  @override
  bool get showCopyButton => true;

  @override
  bool get showSaveAsButton => true;

  @override
  bool get showFavoriteButton => true;

  @override
  bool get preserveOriginalBytesOnSave => false;
}

/// 生成图像数据适配器
///
/// 用于未保存到磁盘的图像（内存中的图像数据）
/// 支持从内存字节异步解析元数据
class GeneratedImageDetailData extends ImageDetailData {
  final Uint8List imageBytes;
  final NaiImageMetadata? _metadata;
  final String _id;
  final bool _showSaveButton;
  final bool _showCopyButton;
  final bool _showSaveAsButton;
  final FixedTagUsageSnapshot? fixedTagUsageSnapshot;
  @override
  final bool preserveOriginalBytesOnSave;

  GeneratedImageDetailData({
    required this.imageBytes,
    NaiImageMetadata? metadata,
    String? id,
    bool showSaveButton = true,
    bool showCopyButton = true,
    bool showSaveAsButton = true,
    this.preserveOriginalBytesOnSave = false,
    this.fixedTagUsageSnapshot,
  }) : _metadata = metadata,
       _id = id ?? imageBytes.hashCode.toString(),
       _showSaveButton = showSaveButton,
       _showCopyButton = showCopyButton,
       _showSaveAsButton = showSaveAsButton;

  @override
  ImageProvider getImageProvider() {
    return MemoryImage(imageBytes);
  }

  @override
  Future<Uint8List> getImageBytes() async {
    return imageBytes;
  }

  /// 同步获取元数据（如果已缓存）
  @override
  NaiImageMetadata? get metadata => _metadata;

  /// 没有传入元数据时从内存字节解析
  @override
  Future<NaiImageMetadata?> getMetadataAsync() async {
    if (_metadata != null) return _metadata;
    return ImageMetadataService().getMetadataFromBytes(imageBytes);
  }

  @override
  bool get isFavorite => false;

  @override
  String get identifier => _id;

  @override
  FileInfo? get fileInfo => null;

  @override
  bool get showSaveButton => _showSaveButton;

  @override
  bool get showCopyButton => _showCopyButton;

  @override
  bool get showSaveAsButton => _showSaveAsButton;

  @override
  bool get showFavoriteButton => false;
}
