import 'dart:ui' as ui;

import '../../data/models/gallery/local_image_record.dart';
import '../utils/app_logger.dart';
import '../utils/encoded_image_dimensions.dart';
import 'local_gallery_thumbnail_provider.dart';

typedef ImageFileAspectRatioReader = Future<double> Function(String path);

/// 缺失元数据时整文件读入内存解析尺寸，结果按来源身份缓存并合并并发读取。
class GalleryAspectRatioCache {
  GalleryAspectRatioCache({ImageFileAspectRatioReader? readFile})
    : _readFile = readFile ?? _readEncodedAspectRatio;

  static const double fallback = 1.0;

  final ImageFileAspectRatioReader _readFile;
  final Map<LocalGallerySourceIdentity, double> _resolved = {};
  final Map<LocalGallerySourceIdentity, Future<double>> _pending = {};

  /// 无需读文件即可得到时返回宽高比，否则返回 null。
  double? peek(LocalImageRecord record) =>
      _metadataAspectRatio(record) ?? _resolved[sourceOf(record)];

  Future<double> resolve(LocalImageRecord record) {
    final known = peek(record);
    if (known != null) return Future.value(known);
    final source = sourceOf(record);
    return _pending[source] ??= _readFile(record.path)
        .then<double>(
          (value) => value.isFinite && value > 0 ? value : fallback,
          onError: (Object _) => fallback,
        )
        .then((value) {
          _resolved[source] = value;
          _pending.remove(source);
          return value;
        });
  }

  static LocalGallerySourceIdentity sourceOf(LocalImageRecord record) =>
      LocalGallerySourceIdentity.fromRecord(
        path: record.path,
        size: record.size,
        modifiedAt: record.modifiedAt,
      );

  static double? _metadataAspectRatio(LocalImageRecord record) {
    final width = record.metadata?.width;
    final height = record.metadata?.height;
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return width / height;
  }

  static Future<double> _readEncodedAspectRatio(String path) async {
    try {
      final (width, height) = await readEncodedImageDimensions(
        await ui.ImmutableBuffer.fromFilePath(path),
      );
      if (width > 0 && height > 0) return width / height;
    } catch (e) {
      AppLogger.d(
        'Failed to read gallery image aspect ratio: $e',
        'GalleryContent',
      );
    }
    return fallback;
  }
}
