import 'dart:io';
import 'dart:typed_data';

import '../../../core/utils/app_logger.dart';
import '../../../core/utils/vibe_file_parser.dart';
import '../models/vibe/vibe_reference.dart';

/// Vibe 元数据服务
///
/// 负责从 PNG 文件中提取 Vibe 元数据
/// - 支持从文件路径或字节数据中提取
/// - 检查图片是否包含 Vibe 元数据
/// - 获取 Vibe 缩略图
class VibeMetadataService {
  /// 从图片字节数据中提取 Vibe 参考
  ///
  /// [image] - PNG 图片字节数据
  /// [defaultStrength] - 默认强度值 (0-1)
  ///
  /// 返回提取的 VibeReference，如果提取失败则返回 null
  Future<VibeReference?> extractVibeFromImage(
    Uint8List image, {
    double defaultStrength = 0.6,
  }) async {
    try {
      final reference = await VibeFileParser.fromPngInIsolate(
        'image.png',
        image,
        defaultStrength: defaultStrength,
      );

      // 检查是否成功提取了编码数据
      if (reference.vibeEncoding.isNotEmpty) {
        AppLogger.i(
          'Successfully extracted Vibe metadata from image',
          'VibeMetadataService',
        );
        return reference;
      }

      AppLogger.i(
        'No Vibe metadata found in image (will be encoded on demand)',
        'VibeMetadataService',
      );
      return null;
    } catch (e, stack) {
      AppLogger.e(
        'Failed to extract Vibe from image',
        e,
        stack,
        'VibeMetadataService',
      );
      return null;
    }
  }

  /// 从文件路径提取 Vibe 参考
  ///
  /// [filePath] - PNG 文件路径
  /// [defaultStrength] - 默认强度值 (0-1)
  ///
  /// 返回提取的 VibeReference，如果文件不存在或提取失败则返回 null
  Future<VibeReference?> extractVibeFromFile(
    String filePath, {
    double defaultStrength = 0.6,
  }) async {
    try {
      // 检查文件是否存在
      final file = File(filePath);
      if (!await file.exists()) {
        AppLogger.w(
          'File not found: $filePath',
          'VibeMetadataService',
        );
        return null;
      }

      // 读取文件字节
      final bytes = await file.readAsBytes();

      // 提取文件名
      final fileName = filePath.split(Platform.pathSeparator).last;

      // 解析 Vibe 数据 (使用 isolate 避免阻塞 UI 线程)
      final reference = await VibeFileParser.fromPngInIsolate(
        fileName,
        bytes,
        defaultStrength: defaultStrength,
      );

      // 检查是否成功提取了编码数据
      if (reference.vibeEncoding.isNotEmpty) {
        AppLogger.i(
          'Successfully extracted Vibe metadata from file: $fileName',
          'VibeMetadataService',
        );
        return reference;
      }

      AppLogger.i(
        'No Vibe metadata found in file: $fileName (will be encoded on demand)',
        'VibeMetadataService',
      );
      return null;
    } catch (e, stack) {
      AppLogger.e(
        'Failed to extract Vibe from file: $filePath',
        e,
        stack,
        'VibeMetadataService',
      );
      return null;
    }
  }

  /// 检查图片是否包含 Vibe 元数据
  ///
  /// [image] - PNG 图片字节数据
  ///
  /// 返回 true 如果图片包含 NovelAI_Vibe_Encoding_Base64 iTXt 块
  Future<bool> hasVibeMetadata(Uint8List image) async {
    try {
      final reference = await VibeFileParser.fromPngInIsolate(
        'image.png',
        image,
      );

      return reference.vibeEncoding.isNotEmpty;
    } catch (e) {
      // 解析失败视为没有 Vibe 元数据
      return false;
    }
  }

  /// 获取 Vibe 缩略图
  ///
  /// [image] - PNG 图片字节数据
  ///
  /// 返回图片字节数据作为缩略图（对于 PNG 文件，返回原图）
  /// 如果提取失败则返回 null
  Future<Uint8List?> getVibeThumbnail(Uint8List image) async {
    try {
      // 对于 PNG 文件，直接返回原图作为缩略图
      // 实际使用时可以根据需要调整大小
      return image;
    } catch (e, stack) {
      AppLogger.e(
        'Failed to get Vibe thumbnail',
        e,
        stack,
        'VibeMetadataService',
      );
      return null;
    }
  }
}
