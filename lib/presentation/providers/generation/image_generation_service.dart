import 'dart:async';
import 'dart:typed_data';

import '../../../core/utils/app_logger.dart';
import '../../../data/datasources/remote/nai_image_generation_api_service.dart';
import '../../../data/models/image/image_params.dart';
import 'generation_models.dart';

/// 图像生成结果
class ImageGenerationResult {
  /// 生成的图像列表
  final List<GeneratedImage> images;

  /// Vibe 编码哈希映射 (索引 -> 编码)
  /// 注意：key 使用字符串格式 '${imageIndex}_${vibeIndex}' 以避免冲突
  final Map<String, String> vibeEncodings;

  /// 是否被取消
  final bool isCancelled;

  /// 错误信息（如果有）
  final String? error;

  const ImageGenerationResult({
    required this.images,
    this.vibeEncodings = const {},
    this.isCancelled = false,
    this.error,
  });

  /// 是否成功
  bool get isSuccess => error == null && !isCancelled && images.isNotEmpty;

  /// 创建取消结果
  factory ImageGenerationResult.cancelled() {
    return const ImageGenerationResult(
      images: [],
      isCancelled: true,
    );
  }

  /// 创建错误结果
  factory ImageGenerationResult.error(String message) {
    return ImageGenerationResult(
      images: const [],
      error: message,
    );
  }
}

/// 生成进度回调
///
/// [current] - 当前图像索引 (1-based)
/// [total] - 总图像数量
/// [progress] - 总体进度 (0.0 - 1.0)
/// [previewImage] - 流式预览图像（如果有）
typedef GenerationProgressCallback = void Function(
  int current,
  int total,
  double progress, {
  Uint8List? previewImage,
});

/// 批量生成结果（包含图像和 vibe encodings）
typedef _BatchGenerationResult = ({List<GeneratedImage> images, Map<String, String> vibeEncodings});

/// 图像生成服务
///
/// 封装核心的图像生成逻辑，包括：
/// - 单张图像生成（带流式预览）
/// - 批量图像生成
/// - 重试机制
/// - 取消支持
/// - 错误处理
///
/// 注意：此服务不依赖 Riverpod，是纯粹的领域服务
class ImageGenerationService {
  final NAIImageGenerationApiService _apiService;

  /// 重试延迟策略 (毫秒)
  static const List<int> _retryDelays = [1000, 2000, 4000];
  static const int _maxRetries = 3;

  /// 取消标志
  bool _isCancelled = false;

  /// 构造函数
  ImageGenerationService({
    required NAIImageGenerationApiService apiService,
  }) : _apiService = apiService;

  /// 是否已取消
  bool get isCancelled => _isCancelled;

  /// 取消当前生成
  void cancel() {
    _isCancelled = true;
    _apiService.cancelGeneration();
    AppLogger.d('Image generation cancelled', 'ImageGenerationService');
  }

  /// 重置取消状态
  void resetCancellation() {
    _isCancelled = false;
  }

  /// 生成单张图像（带流式预览支持）
  ///
  /// [params] - 生成参数（nSamples 会被强制设为 1）
  /// [onProgress] - 进度回调（包含流式预览）
  ///
  /// 返回生成结果，包含生成的图像和可能的 vibe 编码
  Future<ImageGenerationResult> generateSingle(
    ImageParams params, {
    GenerationProgressCallback? onProgress,
  }) async {
    _isCancelled = false;

    // 强制单张生成
    final singleParams = params.copyWith(nSamples: 1);

    try {
      // 尝试流式生成
      final result = await _generateWithStream(
        singleParams,
        currentIndex: 1,
        totalCount: 1,
        onProgress: onProgress,
      );

      if (_isCancelled) {
        return ImageGenerationResult.cancelled();
      }

      return result;
    } catch (e) {
      if (_isCancelled || _isCancelledError(e)) {
        return ImageGenerationResult.cancelled();
      }

      AppLogger.e('Single generation failed: $e', 'ImageGenerationService');
      return ImageGenerationResult.error(e.toString());
    }
  }

  /// 批量生成图像
  ///
  /// [params] - 基础生成参数
  /// [batchCount] - 批次数量（请求次数）
  /// [batchSize] - 每批次生成的图像数量
  /// [onBatchStart] - 每批次开始回调 (batchIndex, currentImage, totalImages)
  /// [onProgress] - 进度回调
  /// [onBatchComplete] - 每批次完成回调 (images)
  ///
  /// 返回所有生成的图像
  Future<ImageGenerationResult> generateBatch(
    ImageParams params, {
    required int batchCount,
    required int batchSize,
    void Function(int batchIndex, int currentImage, int totalImages)? onBatchStart,
    GenerationProgressCallback? onProgress,
    void Function(List<GeneratedImage> batchImages)? onBatchComplete,
  }) async {
    _isCancelled = false;

    if (batchCount == 1 && batchSize == 1) {
      return generateSingle(params, onProgress: onProgress);
    }

    // 验证参数，防止除以零
    if (batchCount <= 0 || batchSize <= 0) {
      return ImageGenerationResult.error('批次数量和批次大小必须大于0');
    }

    final totalImages = (batchCount * batchSize).toInt();
    final allImages = <GeneratedImage>[];
    final allVibeEncodings = <String, String>{};
    int generatedCount = 0;

    for (int batch = 0; batch < batchCount; batch++) {
      if (_isCancelled) {
        break;
      }

      final currentStart = generatedCount + 1;

      // 通知批次开始
      onBatchStart?.call(batch, currentStart, totalImages);

      // 每批次使用不同的随机种子
      final batchParams = params.copyWith(
        nSamples: batchSize,
        seed: params.seed == -1 ? -1 : params.seed + batch,
      );

      try {
        // 批量生成时，每张图单独请求以支持流式预览
        final batchResult = await _generateBatchWithStream(
          batchParams,
          currentStart: currentStart,
          totalImages: totalImages,
          onProgress: onProgress,
        );

        if (_isCancelled) {
          break;
        }

        allImages.addAll(batchResult.images);
        allVibeEncodings.addAll(batchResult.vibeEncodings);
        generatedCount += batchResult.images.length;

        onBatchComplete?.call(batchResult.images);
      } catch (e) {
        if (_isCancelled || _isCancelledError(e)) {
          break;
        }

        AppLogger.e('Batch ${batch + 1} failed: $e', 'ImageGenerationService');
        // 继续下一批次
        generatedCount += batchSize;
      }
    }

    if (_isCancelled) {
      return ImageGenerationResult.cancelled();
    }

    return ImageGenerationResult(
      images: allImages,
      vibeEncodings: allVibeEncodings,
    );
  }

  /// 使用流式 API 生成单张图像
  Future<ImageGenerationResult> _generateWithStream(
    ImageParams params, {
    required int currentIndex,
    required int totalCount,
    GenerationProgressCallback? onProgress,
  }) async {
    bool streamingNotAllowed = false;
    Uint8List? finalImage;

    try {
      final stream = _apiService.generateImageStream(params);

      await for (final chunk in stream) {
        if (_isCancelled) {
          return ImageGenerationResult.cancelled();
        }

        if (chunk.hasError) {
          if (_isStreamingNotAllowed(chunk.error ?? '')) {
            AppLogger.w(
              'Streaming not allowed, falling back to non-stream API',
              'ImageGenerationService',
            );
            streamingNotAllowed = true;
            break;
          }
          return ImageGenerationResult.error(chunk.error!);
        }

        if (chunk.hasPreview) {
          onProgress?.call(
            currentIndex,
            totalCount,
            chunk.progress.clamp(0.0, 0.99),
            previewImage: chunk.previewImage,
          );
        }

        if (chunk.isComplete && chunk.hasFinalImage) {
          finalImage = chunk.finalImage;
        }
      }

      // 如果流式成功返回图像
      if (finalImage != null && !_isCancelled) {
        final generatedImage = GeneratedImage.create(
          finalImage,
          width: params.width,
          height: params.height,
        );
        // 注意：Streaming API 的响应中不包含 vibe encodings 数据
        // 只有非流式 API (generateImage) 会返回 vibe encodings
        // 这是 NovelAI API 的已知限制，非本实现问题
        //
        // 如果需要获取 vibe encodings，有以下选择：
        // 1. 使用非流式生成（禁用流式预览）
        // 2. 在流式生成成功后，使用相同的参数再调用一次非流式 API
        //    （但这会增加 API 调用成本，不推荐）
        //
        // 由于 vibe encodings 主要用于保存和复用 Vibe Transfer 特征，
        // 而大多数用户更重视流式预览体验，因此此处优先保证流式功能
        return ImageGenerationResult(
          images: [generatedImage],
        );
      }

      // 流式不支持或未完成，回退到非流式
      if (streamingNotAllowed || finalImage == null) {
        return _generateWithRetry(params);
      }

      return ImageGenerationResult.error('No image generated');
    } catch (e) {
      if (_isCancelled || _isCancelledError(e)) {
        return ImageGenerationResult.cancelled();
      }

      if (_isStreamingNotAllowed(e.toString())) {
        return _generateWithRetry(params);
      }

      rethrow;
    }
  }

  /// 批量生成（带流式预览）
  Future<_BatchGenerationResult> _generateBatchWithStream(
    ImageParams params, {
    required int currentStart,
    required int totalImages,
    GenerationProgressCallback? onProgress,
  }) async {
    final images = <GeneratedImage>[];
    final allVibeEncodings = <String, String>{};
    final batchSize = params.nSamples;
    bool useNonStreamFallback = false;

    for (int i = 0; i < batchSize; i++) {
      if (_isCancelled) break;

      final currentIndex = currentStart + i;

      // 更新进度
      onProgress?.call(
        currentIndex,
        totalImages,
        (currentIndex - 1) / totalImages,
      );

      // 为每张图使用不同的种子
      final singleParams = params.copyWith(
        nSamples: 1,
        seed: params.seed == -1 ? -1 : params.seed + i,
      );

      Uint8List? image;
      Map<String, String> imageVibeEncodings = {};

      for (int retry = 0; retry <= _maxRetries; retry++) {
        if (_isCancelled) break;

        try {
          // 使用非流式回退
          if (useNonStreamFallback) {
            final (fallbackImages, fallbackVibes) = await _apiService.generateImage(
              singleParams,
              onProgress: (_, __) {},
            );
            if (fallbackImages.isNotEmpty) {
              image = fallbackImages.first;
              // 将 API 返回的 Map<int, String> 转换为 Map<String, String>
              // key 格式: '${currentIndex}_${vibeIndex}'
              imageVibeEncodings = {
                for (final entry in fallbackVibes.entries)
                  '${currentIndex}_${entry.key}': entry.value,
              };
              break;
            }
            continue;
          }

          // 尝试流式生成
          bool streamingNotAllowed = false;
          await for (final chunk in _apiService.generateImageStream(singleParams)) {
            if (_isCancelled) break;

            if (chunk.hasError) {
              if (_isStreamingNotAllowed(chunk.error ?? '')) {
                streamingNotAllowed = true;
                useNonStreamFallback = true;
                break;
              }
              throw Exception(chunk.error);
            }

            if (chunk.hasPreview) {
              onProgress?.call(
                currentIndex,
                totalImages,
                (currentIndex - 1 + chunk.progress) / totalImages,
                previewImage: chunk.previewImage,
              );
            }

            if (chunk.isComplete && chunk.hasFinalImage) {
              image = chunk.finalImage;
            }
          }

          // 流式不支持，使用非流式回退
          if (streamingNotAllowed) {
            final (fallbackImages, fallbackVibes) = await _apiService.generateImage(
              singleParams,
              onProgress: (_, __) {},
            );
            if (fallbackImages.isNotEmpty) {
              image = fallbackImages.first;
              // 将 API 返回的 Map<int, String> 转换为 Map<String, String>
              imageVibeEncodings = {
                for (final entry in fallbackVibes.entries)
                  '${currentIndex}_${entry.key}': entry.value,
              };
              break;
            }
            continue;
          }

          if (image != null) {
            break;
          }

          // 流式未返回图像，尝试非流式
          final (fallbackImages, fallbackVibes) = await _apiService.generateImage(
            singleParams,
            onProgress: (_, __) {},
          );
          if (fallbackImages.isNotEmpty) {
            image = fallbackImages.first;
            // 将 API 返回的 Map<int, String> 转换为 Map<String, String>
            imageVibeEncodings = {
              for (final entry in fallbackVibes.entries)
                '${currentIndex}_${entry.key}': entry.value,
            };
            break;
          }
        } catch (e) {
          if (_isCancelled || _isCancelledError(e)) break;

          if (_isStreamingNotAllowed(e.toString())) {
            useNonStreamFallback = true;
            try {
              final (fallbackImages, fallbackVibes) = await _apiService.generateImage(
                singleParams,
                onProgress: (_, __) {},
              );
              if (fallbackImages.isNotEmpty) {
                image = fallbackImages.first;
                // 将 API 返回的 Map<int, String> 转换为 Map<String, String>
                imageVibeEncodings = {
                  for (final entry in fallbackVibes.entries)
                    '${currentIndex}_${entry.key}': entry.value,
                };
                break;
              }
            } catch (fallbackError) {
              AppLogger.e('Non-stream fallback failed: $fallbackError');
            }
            break;
          }

          if (retry < _maxRetries) {
            AppLogger.w(
              'Generation failed, retrying in ${_retryDelays[retry]}ms (${retry + 1}/$_maxRetries): $e',
            );
            await Future.delayed(Duration(milliseconds: _retryDelays[retry]));
          } else {
            AppLogger.e('Failed to generate image $currentIndex: $e');
          }
        }
      }

      if (image != null) {
        images.add(GeneratedImage.create(
          image,
          width: params.width,
          height: params.height,
        ),);
        // 合并当前图像的 vibe encodings
        // imageVibeEncodings 的 key 已经是 '${currentIndex}_${vibeIndex}' 格式
        if (imageVibeEncodings.isNotEmpty) {
          allVibeEncodings.addAll(imageVibeEncodings);
        }
      }
    }

    return (images: images, vibeEncodings: allVibeEncodings);
  }

  /// 带重试的非流式生成
  Future<ImageGenerationResult> _generateWithRetry(ImageParams params) async {
    for (int retry = 0; retry <= _maxRetries; retry++) {
      try {
        final (imageBytes, vibeEncodings) = await _apiService.generateImage(
          params,
          onProgress: (_, __) {},
        );

        final images = imageBytes
            .map((b) => GeneratedImage.create(
                  b,
                  width: params.width,
                  height: params.height,
                ),)
            .toList();

        // 将 API 返回的 Map<int, String> 转换为 Map<String, String>
        // key 格式: '0_${vibeIndex}'（单张生成使用索引 0）
        final convertedVibeEncodings = {
          for (final entry in vibeEncodings.entries) '0_${entry.key}': entry.value,
        };

        return ImageGenerationResult(
          images: images,
          vibeEncodings: convertedVibeEncodings,
        );
      } catch (e) {
        if (_isCancelled || _isCancelledError(e)) {
          return ImageGenerationResult.cancelled();
        }

        if (retry < _maxRetries) {
          AppLogger.w(
            'Generation failed, retrying in ${_retryDelays[retry]}ms (${retry + 1}/$_maxRetries): $e',
          );
          await Future.delayed(Duration(milliseconds: _retryDelays[retry]));
        } else {
          rethrow;
        }
      }
    }

    return ImageGenerationResult.error('Max retries exceeded');
  }

  /// 检查错误是否为取消操作
  bool _isCancelledError(dynamic error) {
    return _isCancelled || error.toString().toLowerCase().contains('cancelled');
  }

  /// 检查错误是否为流式不支持
  bool _isStreamingNotAllowed(String error) {
    final lower = error.toLowerCase();
    return lower.contains('streaming is not allowed') ||
        lower.contains('streaming not allowed') ||
        lower.contains('stream is not allowed') ||
        lower.contains('stream not allowed');
  }
}
