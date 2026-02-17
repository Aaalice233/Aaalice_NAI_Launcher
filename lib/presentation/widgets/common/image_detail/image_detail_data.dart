import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import '../../../../data/models/gallery/local_image_record.dart';
import '../../../../data/models/gallery/nai_image_metadata.dart';

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

  /// 是否需要显示收藏按钮
  bool get showFavoriteButton;
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

  LocalImageDetailData(
    this.record, {
    this.getFavoriteStatus,
  });

  @override
  ImageProvider getImageProvider() {
    final meta = record.metadata;
    final fileImage = FileImage(File(record.path));

    // 如果有元数据且图像尺寸超过阈值，使用 ResizeImage 限制内存
    if (meta != null) {
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
    return File(record.path).readAsBytes();
  }

  @override
  NaiImageMetadata? get metadata => record.metadata;

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
  bool get showFavoriteButton => true;
}

/// 生成图像数据适配器
class GeneratedImageDetailData implements ImageDetailData {
  final Uint8List imageBytes;
  final NaiImageMetadata? _metadata;
  final String _id;

  GeneratedImageDetailData({
    required this.imageBytes,
    NaiImageMetadata? metadata,
    String? id,
  })  : _metadata = metadata,
        _id = id ?? imageBytes.hashCode.toString();

  /// 从生成参数构造
  factory GeneratedImageDetailData.fromParams({
    required Uint8List imageBytes,
    required String prompt,
    required String negativePrompt,
    required int seed,
    required int steps,
    required double scale,
    required int width,
    required int height,
    required String model,
    required String sampler,
    bool smea = false,
    bool smeaDyn = false,
    String? noiseSchedule,
    double? cfgRescale,
    List<String> characterPrompts = const [],
    List<String> characterNegativePrompts = const [],
    String? id,
  }) {
    final metadata = NaiImageMetadata(
      prompt: prompt,
      negativePrompt: negativePrompt,
      seed: seed,
      steps: steps,
      scale: scale,
      width: width,
      height: height,
      model: model,
      sampler: sampler,
      smea: smea,
      smeaDyn: smeaDyn,
      noiseSchedule: noiseSchedule,
      cfgRescale: cfgRescale,
      characterPrompts: characterPrompts,
      characterNegativePrompts: characterNegativePrompts,
    );

    return GeneratedImageDetailData(
      imageBytes: imageBytes,
      metadata: metadata,
      id: id,
    );
  }

  @override
  ImageProvider getImageProvider() {
    return MemoryImage(imageBytes);
  }

  @override
  Future<Uint8List> getImageBytes() async {
    return imageBytes;
  }

  @override
  NaiImageMetadata? get metadata => _metadata;

  @override
  bool get isFavorite => false;

  @override
  String get identifier => _id;

  @override
  FileInfo? get fileInfo => null;

  @override
  bool get showSaveButton => true;

  @override
  bool get showFavoriteButton => false;
}
