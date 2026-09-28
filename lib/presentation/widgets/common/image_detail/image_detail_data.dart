import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import '../../../../data/models/gallery/local_image_record.dart';
import '../../../../data/models/gallery/nai_image_metadata.dart';
import '../../../../data/models/fixed_tag/fixed_tag_usage_snapshot.dart';
import '../../../../data/services/image_metadata_service.dart';
import '../../../../data/services/metadata/isolate_metadata_service.dart';

/// 原图解码期间的低清占位图。
///
/// 【偏离上游】上游 v4.2.1 删掉了落盘缩略图缓存（`ThumbnailCacheService`），
/// 改成由 `LocalGalleryThumbnailProvider` 按显示尺寸直接解码。那个 provider
/// 不能拿来当详情页占位：它的解码调度器被
/// `LocalGalleryThumbnailProvider.setGalleryVisible()` 门控，而详情页也可能从
/// 生成页/历史面板打开（此时本地图库分支不可见），排进去的解码任务会永远不被
/// drain，占位图静默卡住。所以这里退回到与调度器无关的标准 provider：
/// 同一个文件按 [_placeholderMaxDimension] 降采样解码，代价只有全尺寸解码的零头，
/// 又不会挂在别人的可见性状态上。占位是纯优化，任何失败都静默回退到无占位。
Future<ImageProvider?> downscaledFilePlaceholder(String path) async {
  const placeholderMaxDimension = 512;
  try {
    final file = File(path);
    if (!await file.exists()) return null;
    return ResizeImage(
      FileImage(file),
      width: placeholderMaxDimension,
      height: placeholderMaxDimension,
      policy: ResizeImagePolicy.fit,
      allowUpscaling: false,
    );
  } catch (_) {
    return null;
  }
}

/// 图像详情数据抽象接口
///
/// 通过适配器模式统一两种数据源：
/// - 本地图库：使用 [LocalImageDetailData]
/// - 生成图像：使用 [GeneratedImageDetailData]
abstract class ImageDetailData {
  /// 获取图像提供者（用于显示）
  ImageProvider getImageProvider();

  /// 获取低清占位图（原图解码期间显示，避免长时间黑屏）；没有则返回 null。
  ///
  /// 【偏离上游】上游没有这个成员，详情页在原图解码完成前只显示一个转圈。
  Future<ImageProvider?> getPlaceholderProvider();

  /// 获取原始图像字节（用于保存）
  Future<Uint8List> getImageBytes();

  /// 获取元数据
  NaiImageMetadata? get metadata;

  /// 异步获取元数据（[metadata] 为空时从图像文件/字节解析兜底）。
  ///
  /// 【偏离上游】三个实现类在上游都已经有同名方法，但**不是接口成员**，
  /// 于是 `detail_metadata_panel.dart:145-165` 只能按具体类型 if/else 分派，
  /// 而顶栏 `detail_top_bar.dart:55` 干脆只读 [metadata] 这个数据库快照。
  /// iOS 覆盖安装后应用容器 UUID 变化、快照里的绝对路径全部失效，
  /// [metadata] 返回 null，「复用参数」按钮会直接从顶栏消失——
  /// 上游只修了「点了之后能不能用」（`local_gallery_action_coordinator`
  /// 改走文件级 `resolveLocalGalleryMetadata`），没修「按钮显不显示」。
  /// 提升为接口成员后 `ImageDetailViewer` 才能统一兜底并把结果回灌给顶栏。
  Future<NaiImageMetadata?> getMetadataAsync();

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

  /// 是否需要显示收藏按钮
  bool get showFavoriteButton;

  /// 保存时是否必须保持当前图像字节不变。
  bool get preserveOriginalBytesOnSave;
}

/// 文件信息
class FileInfo {
  final String path;
  final String fileName;
  final int size;
  final DateTime modifiedAt;

  const FileInfo({
    required this.path,
    required this.fileName,
    required this.size,
    required this.modifiedAt,
  });
}

/// 本地图库图像数据适配器
///
/// 包含大图内存优化：超过阈值的图像会使用 ResizeImage 限制内存占用
class LocalImageDetailData implements ImageDetailData {
  final LocalImageRecord record;
  final bool Function(String path)? getFavoriteStatus;

  /// 图像最大维度阈值（超过此值会进行缩放优化）
  static const int _maxImageDimension = 4096;

  LocalImageDetailData(this.record, {this.getFavoriteStatus});

  @override
  ImageProvider getImageProvider() {
    final meta = metadata;
    final fileImage = FileImage(File(record.path));

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
  Future<ImageProvider?> getPlaceholderProvider() =>
      downscaledFilePlaceholder(record.path);

  @override
  Future<Uint8List> getImageBytes() async {
    return File(record.path).readAsBytes();
  }

  @override
  NaiImageMetadata? get metadata =>
      record.metadata?.upgradeFromRawJsonIfNeeded();

  /// 异步获取元数据（从文件解析）
  ///
  /// **前台高优先级调用** - 用户主动打开详情页时使用
  ///
  /// 【优化】使用 Isolate 在后台线程解析，避免阻塞 UI
  @override
  Future<NaiImageMetadata?> getMetadataAsync() async {
    // 1. 先检查已缓存的元数据
    final cachedRecordMetadata = metadata;
    if (cachedRecordMetadata != null) return cachedRecordMetadata;

    // 2. 在 Isolate 中解析（不阻塞 UI）
    // 先尝试快速路径（缓存）
    final cached = await ImageMetadataService().getMetadataImmediate(
      record.path,
    );
    if (cached != null) return cached;

    // 3. 使用 Isolate 深度解析（针对大文件或复杂格式）
    final isolateService = IsolateMetadataService.instance;
    return isolateService.parseForDetailView(record.path);
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
  bool get showFavoriteButton => true;

  @override
  bool get preserveOriginalBytesOnSave => false;
}

/// 生成图像数据适配器
///
/// 用于未保存到磁盘的图像（内存中的图像数据）
/// 支持从内存字节异步解析元数据
class GeneratedImageDetailData implements ImageDetailData {
  final Uint8List imageBytes;
  final NaiImageMetadata? _metadata;
  final String _id;
  final bool _showSaveButton;
  final bool _showCopyButton;
  final FixedTagUsageSnapshot? fixedTagUsageSnapshot;
  @override
  final bool preserveOriginalBytesOnSave;

  GeneratedImageDetailData({
    required this.imageBytes,
    NaiImageMetadata? metadata,
    String? id,
    bool showSaveButton = true,
    bool showCopyButton = true,
    this.preserveOriginalBytesOnSave = false,
    this.fixedTagUsageSnapshot,
  }) : _metadata = metadata,
       _id = id ?? imageBytes.hashCode.toString(),
       _showSaveButton = showSaveButton,
       _showCopyButton = showCopyButton;

  @override
  ImageProvider getImageProvider() {
    return MemoryImage(imageBytes);
  }

  /// 内存字节没有可降采样的磁盘副本，[MemoryImage] 本身就是唯一来源，无占位。
  @override
  Future<ImageProvider?> getPlaceholderProvider() async => null;

  @override
  Future<Uint8List> getImageBytes() async {
    return imageBytes;
  }

  /// 同步获取元数据（如果已缓存）
  @override
  NaiImageMetadata? get metadata => _metadata;

  /// 异步获取元数据（从内存字节解析）
  ///
  /// **前台高优先级调用** - 用户主动打开详情页时使用
  /// 内存字节直接解析，不受后台队列影响
  @override
  Future<NaiImageMetadata?> getMetadataAsync() async {
    // 1. 先检查已缓存的元数据
    if (_metadata != null) return _metadata;

    // 2. 从内存字节直接解析（内存操作，无需排队）
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
  bool get showFavoriteButton => false;
}
