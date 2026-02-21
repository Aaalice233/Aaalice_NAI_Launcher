import 'dart:async';
import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/datasources/remote/nai_image_generation_api_service.dart';
import '../../data/models/image/image_params.dart';
import 'generation/generation_models.dart';
import 'generation/image_generation_service.dart';

export 'generation/generation_models.dart';

part 'image_generation_provider_new.g.dart';

// ==================== 简化版图像生成 Provider (Facade) ====================

/// 简化版图像生成状态
///
/// 作为 facade 层，提供简洁的图像生成接口
/// 底层使用 ImageGenerationService 处理复杂逻辑
@riverpod
class ImageGenerationNotifierNew extends _$ImageGenerationNotifierNew {
  ImageGenerationService? _service;

  @override
  ImageGenerationState build() {
    // 初始化时创建服务
    final apiService = ref.read(naiImageGenerationApiServiceProvider);
    _service = ImageGenerationService(apiService: apiService);

    // 清理时取消生成
    ref.onDispose(() {
      _service?.cancel();
    });

    return const ImageGenerationState();
  }

  /// 生成单张图像
  ///
  /// [params] - 图像生成参数
  /// 自动处理流式预览和错误回退
  Future<void> generateSingle(ImageParams params) async {
    if (_service == null) return;

    // 重置状态
    _service!.resetCancellation();

    state = state.copyWith(
      status: GenerationStatus.generating,
      progress: 0.0,
      errorMessage: null,
      currentImages: [],
      clearStreamPreview: true,
    );

    try {
      final result = await _service!.generateSingle(
        params,
        onProgress: (current, total, progress, {previewImage}) {
          state = state.copyWith(
            currentImage: current,
            totalImages: total,
            progress: progress,
            streamPreview: previewImage,
          );
        },
      );

      if (result.isCancelled) {
        state = state.copyWith(
          status: GenerationStatus.cancelled,
          progress: 0.0,
          clearStreamPreview: true,
        );
        return;
      }

      if (result.error != null) {
        state = state.copyWith(
          status: GenerationStatus.error,
          errorMessage: result.error,
          progress: 0.0,
          clearStreamPreview: true,
        );
        return;
      }

      // 更新成功状态
      final images = result.images;
      state = state.copyWith(
        status: GenerationStatus.completed,
        currentImages: images,
        displayImages: images,
        displayWidth: params.width,
        displayHeight: params.height,
        history: [...images, ...state.history].take(50).toList(),
        progress: 1.0,
        currentImage: 0,
        totalImages: 0,
        clearStreamPreview: true,
      );
    } catch (e) {
      state = state.copyWith(
        status: GenerationStatus.error,
        errorMessage: e.toString(),
        progress: 0.0,
        clearStreamPreview: true,
      );
    }
  }

  /// 批量生成图像
  ///
  /// [params] - 基础生成参数
  /// [batchCount] - 批次数量（请求次数）
  /// [batchSize] - 每批次生成的图像数量
  Future<void> generateBatch(
    ImageParams params, {
    required int batchCount,
    required int batchSize,
  }) async {
    if (_service == null) return;

    // 重置状态
    _service!.resetCancellation();

    final totalImages = batchCount * batchSize;

    state = state.copyWith(
      status: GenerationStatus.generating,
      progress: 0.0,
      errorMessage: null,
      currentImage: 1,
      totalImages: totalImages,
      currentImages: [],
      clearStreamPreview: true,
    );

    try {
      final result = await _service!.generateBatch(
        params,
        batchCount: batchCount,
        batchSize: batchSize,
        onBatchStart: (batchIndex, currentImage, totalImages) {
          state = state.copyWith(
            currentImage: currentImage,
            totalImages: totalImages,
            progress: (currentImage - 1) / totalImages,
          );
        },
        onProgress: (current, total, progress, {previewImage}) {
          state = state.copyWith(
            currentImage: current,
            totalImages: total,
            progress: progress,
            streamPreview: previewImage,
          );
        },
      );

      if (result.isCancelled) {
        state = state.copyWith(
          status: GenerationStatus.cancelled,
          progress: 0.0,
          clearStreamPreview: true,
        );
        return;
      }

      if (result.error != null) {
        state = state.copyWith(
          status: GenerationStatus.error,
          errorMessage: result.error,
          progress: 0.0,
          clearStreamPreview: true,
        );
        return;
      }

      // 更新成功状态
      final images = result.images;
      state = state.copyWith(
        status: GenerationStatus.completed,
        currentImages: images,
        displayImages: images,
        displayWidth: params.width,
        displayHeight: params.height,
        history: [...images, ...state.history].take(50).toList(),
        progress: 1.0,
        currentImage: 0,
        totalImages: 0,
        clearStreamPreview: true,
      );
    } catch (e) {
      state = state.copyWith(
        status: GenerationStatus.error,
        errorMessage: e.toString(),
        progress: 0.0,
        clearStreamPreview: true,
      );
    }
  }

  /// 取消当前生成
  void cancel() {
    _service?.cancel();
    state = state.copyWith(
      status: GenerationStatus.cancelled,
      progress: 0.0,
      currentImage: 0,
      totalImages: 0,
    );
  }

  /// 清除当前图像
  void clearCurrent() {
    state = state.copyWith(
      currentImages: [],
      status: GenerationStatus.idle,
    );
  }

  /// 清除错误状态
  void clearError() {
    if (state.status == GenerationStatus.error) {
      state = state.copyWith(
        status: GenerationStatus.idle,
        errorMessage: null,
      );
    }
  }

  /// 清除历史记录
  void clearHistory() {
    state = state.copyWith(
      currentImages: [],
      history: [],
    );
  }

  /// 更新显示图像列表
  void updateDisplayImages(List<GeneratedImage> images) {
    state = state.copyWith(
      displayImages: images,
    );
  }
}

// ==================== 便捷 Provider ====================

/// 当前生成状态便捷访问
@riverpod
GenerationStatus generationStatus(GenerationStatusRef ref) {
  return ref.watch(imageGenerationNotifierNewProvider).status;
}

/// 当前生成进度便捷访问
@riverpod
double generationProgress(GenerationProgressRef ref) {
  return ref.watch(imageGenerationNotifierNewProvider).progress;
}

/// 当前生成的图像列表便捷访问
@riverpod
List<GeneratedImage> generatedImages(GeneratedImagesRef ref) {
  return ref.watch(imageGenerationNotifierNewProvider).currentImages;
}

/// 当前是否有流式预览
@riverpod
bool hasStreamPreview(HasStreamPreviewRef ref) {
  return ref.watch(imageGenerationNotifierNewProvider).hasStreamPreview;
}

/// 流式预览图像便捷访问
@riverpod
Uint8List? streamPreviewImage(StreamPreviewImageRef ref) {
  return ref.watch(imageGenerationNotifierNewProvider).streamPreview;
}

/// 是否正在生成中
@riverpod
bool isGenerating(IsGeneratingRef ref) {
  return ref.watch(imageGenerationNotifierNewProvider).isGenerating;
}

/// 生成错误信息便捷访问
@riverpod
String? generationError(GenerationErrorRef ref) {
  return ref.watch(imageGenerationNotifierNewProvider).errorMessage;
}
