import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/app_logger.dart';
import '../../../data/repositories/gallery_folder_repository.dart';
import 'generation_models.dart';

part 'image_save_notifier.g.dart';

/// 图片保存状态
enum ImageSaveStatus {
  /// 空闲状态
  idle,

  /// 正在保存
  saving,

  /// 保存完成
  completed,

  /// 保存失败
  error,
}

/// 图片保存结果
class ImageSaveResult {
  /// 保存的图像
  final GeneratedImage image;

  /// 保存的文件路径
  final String? filePath;

  /// 是否成功
  final bool success;

  /// 错误信息（如果失败）
  final String? errorMessage;

  const ImageSaveResult({
    required this.image,
    this.filePath,
    required this.success,
    this.errorMessage,
  });

  /// 创建成功结果
  factory ImageSaveResult.success(GeneratedImage image, String filePath) {
    return ImageSaveResult(
      image: image,
      filePath: filePath,
      success: true,
    );
  }

  /// 创建失败结果
  factory ImageSaveResult.failure(GeneratedImage image, String error) {
    return ImageSaveResult(
      image: image,
      success: false,
      errorMessage: error,
    );
  }
}

/// 图片保存状态
class ImageSaveState {
  /// 当前状态
  final ImageSaveStatus status;

  /// 最后保存的图像
  final GeneratedImage? lastSavedImage;

  /// 最后保存的文件路径
  final String? lastSavedPath;

  /// 错误信息
  final String? errorMessage;

  /// 已保存的图像数量
  final int savedCount;

  /// 保存失败的图像数量
  final int failedCount;

  const ImageSaveState({
    this.status = ImageSaveStatus.idle,
    this.lastSavedImage,
    this.lastSavedPath,
    this.errorMessage,
    this.savedCount = 0,
    this.failedCount = 0,
  });

  ImageSaveState copyWith({
    ImageSaveStatus? status,
    GeneratedImage? lastSavedImage,
    String? lastSavedPath,
    String? errorMessage,
    int? savedCount,
    int? failedCount,
  }) {
    return ImageSaveState(
      status: status ?? this.status,
      lastSavedImage: lastSavedImage ?? this.lastSavedImage,
      lastSavedPath: lastSavedPath ?? this.lastSavedPath,
      errorMessage: errorMessage,
      savedCount: savedCount ?? this.savedCount,
      failedCount: failedCount ?? this.failedCount,
    );
  }

  /// 是否正在保存
  bool get isSaving => status == ImageSaveStatus.saving;

  /// 是否有错误
  bool get hasError => status == ImageSaveStatus.error;

  /// 是否已保存
  bool get isCompleted => status == ImageSaveStatus.completed;
}

/// 图片保存 Notifier
///
/// 负责自动保存和手动保存生成的图片到本地存储
@Riverpod(keepAlive: true)
class ImageSaveNotifier extends _$ImageSaveNotifier {
  @override
  ImageSaveState build() {
    return const ImageSaveState();
  }

  /// 自动保存图片
  ///
  /// 当 [autoSave] 为 true 时，自动将图片保存到默认路径
  /// 返回保存结果，包含文件路径或错误信息
  Future<ImageSaveResult> autoSave(
    GeneratedImage image, {
    bool autoSave = true,
  }) async {
    if (!autoSave) {
      return ImageSaveResult(
        image: image,
        success: false,
        errorMessage: 'Auto-save is disabled',
      );
    }

    return saveImage(image);
  }

  /// 保存单个图片
  ///
  /// 将图片保存到指定的或默认的路径
  /// 返回保存结果，包含文件路径或错误信息
  Future<ImageSaveResult> saveImage(GeneratedImage image) async {
    state = state.copyWith(status: ImageSaveStatus.saving, errorMessage: null);

    try {
      final savePath = await _getSavePath();
      if (savePath == null) {
        throw Exception('Failed to get save path');
      }

      // 确保目录存在
      final saveDir = Directory(savePath);
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      // 生成文件名
      final fileName = _generateFileName();
      final filePath = path.join(saveDir.path, fileName);

      // 写入文件
      final file = File(filePath);
      await file.writeAsBytes(image.bytes);

      AppLogger.i('Image saved: $filePath', 'ImageSaveNotifier');

      // 更新状态
      state = state.copyWith(
        status: ImageSaveStatus.completed,
        lastSavedImage: image.copyWithFilePath(filePath),
        lastSavedPath: filePath,
        savedCount: state.savedCount + 1,
      );

      return ImageSaveResult.success(image.copyWithFilePath(filePath), filePath);
    } catch (e, stackTrace) {
      AppLogger.e('Failed to save image', e, stackTrace, 'ImageSaveNotifier');

      state = state.copyWith(
        status: ImageSaveStatus.error,
        errorMessage: e.toString(),
        failedCount: state.failedCount + 1,
      );

      return ImageSaveResult.failure(image, e.toString());
    }
  }

  /// 批量保存图片
  ///
  /// 同时保存多个图片，返回每个图片的保存结果
  Future<List<ImageSaveResult>> saveImages(List<GeneratedImage> images) async {
    if (images.isEmpty) {
      return [];
    }

    state = state.copyWith(status: ImageSaveStatus.saving, errorMessage: null);

    final results = <ImageSaveResult>[];
    int successCount = 0;
    int failCount = 0;

    for (final image in images) {
      final result = await saveImage(image);
      results.add(result);

      if (result.success) {
        successCount++;
      } else {
        failCount++;
      }
    }

    // 更新最终状态
    state = state.copyWith(
      status: failCount > 0 ? ImageSaveStatus.error : ImageSaveStatus.completed,
      savedCount: state.savedCount + successCount,
      failedCount: state.failedCount + failCount,
      errorMessage: failCount > 0 ? '$failCount images failed to save' : null,
    );

    return results;
  }

  /// 保存图片到指定路径
  ///
  /// [image] 要保存的图片
  /// [customPath] 自定义保存路径
  Future<ImageSaveResult> saveImageToPath(
    GeneratedImage image,
    String customPath,
  ) async {
    state = state.copyWith(status: ImageSaveStatus.saving, errorMessage: null);

    try {
      // 确保目录存在
      final saveDir = Directory(customPath);
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      // 生成文件名
      final fileName = _generateFileName();
      final filePath = path.join(saveDir.path, fileName);

      // 写入文件
      final file = File(filePath);
      await file.writeAsBytes(image.bytes);

      AppLogger.i('Image saved to custom path: $filePath', 'ImageSaveNotifier');

      // 更新状态
      state = state.copyWith(
        status: ImageSaveStatus.completed,
        lastSavedImage: image.copyWithFilePath(filePath),
        lastSavedPath: filePath,
        savedCount: state.savedCount + 1,
      );

      return ImageSaveResult.success(image.copyWithFilePath(filePath), filePath);
    } catch (e, stackTrace) {
      AppLogger.e('Failed to save image to custom path', e, stackTrace, 'ImageSaveNotifier');

      state = state.copyWith(
        status: ImageSaveStatus.error,
        errorMessage: e.toString(),
        failedCount: state.failedCount + 1,
      );

      return ImageSaveResult.failure(image, e.toString());
    }
  }

  /// 获取保存路径
  ///
  /// 优先使用 GalleryFolderRepository 的路径逻辑
  Future<String?> _getSavePath() async {
    return GalleryFolderRepository.instance.getRootPath();
  }

  /// 生成文件名
  ///
  /// 格式: NAI_<timestamp>.png
  String _generateFileName() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'NAI_$timestamp.png';
  }

  /// 重置状态
  ///
  /// 清除当前状态和错误信息
  void reset() {
    state = const ImageSaveState();
  }

  /// 清除错误
  ///
  /// 清除错误信息并将状态重置为空闲
  void clearError() {
    state = state.copyWith(
      status: ImageSaveStatus.idle,
      errorMessage: null,
    );
  }

  /// 获取保存统计
  ///
  /// 返回已保存和失败的图片数量
  ({int saved, int failed}) getStatistics() {
    return (saved: state.savedCount, failed: state.failedCount);
  }
}
