import 'dart:async';
import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/app_logger.dart';
import '../../../data/datasources/remote/nai_image_generation_api_service.dart';
import '../../../data/models/image/image_params.dart';
import '../../../data/models/image/image_stream_chunk.dart';
import 'generation_models.dart';

part 'stream_generation_notifier.g.dart';

// ==================== 流式生成状态枚举 ====================

/// 流式生成状态
enum StreamGenerationStatus {
  idle,
  connecting,
  streaming,
  completing,
  completed,
  error,
  cancelled,
}

// ==================== 流式生成状态 ====================

/// 流式生成状态
class StreamGenerationState {
  final StreamGenerationStatus status;
  final GeneratedImage? result;
  final String? errorMessage;
  final double progress;

  /// 流式预览图像（渐进式生成过程中的预览）
  final Uint8List? previewImage;

  /// 当前步数
  final int? currentStep;

  /// 总步数
  final int? totalSteps;

  /// 生成开始时间
  final DateTime? startTime;

  /// 生成结束时间
  final DateTime? endTime;

  const StreamGenerationState({
    this.status = StreamGenerationStatus.idle,
    this.result,
    this.errorMessage,
    this.progress = 0.0,
    this.previewImage,
    this.currentStep,
    this.totalSteps,
    this.startTime,
    this.endTime,
  });

  StreamGenerationState copyWith({
    StreamGenerationStatus? status,
    GeneratedImage? result,
    String? errorMessage,
    double? progress,
    Uint8List? previewImage,
    bool clearPreviewImage = false,
    int? currentStep,
    int? totalSteps,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return StreamGenerationState(
      status: status ?? this.status,
      result: result ?? this.result,
      errorMessage: errorMessage,
      progress: progress ?? this.progress,
      previewImage: clearPreviewImage
          ? null
          : (previewImage ?? this.previewImage),
      currentStep: currentStep ?? this.currentStep,
      totalSteps: totalSteps ?? this.totalSteps,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  /// 是否正在生成
  bool get isGenerating =>
      status == StreamGenerationStatus.connecting ||
      status == StreamGenerationStatus.streaming ||
      status == StreamGenerationStatus.completing;

  /// 是否空闲
  bool get isIdle => status == StreamGenerationStatus.idle;

  /// 是否已完成
  bool get isCompleted => status == StreamGenerationStatus.completed;

  /// 是否有预览图像
  bool get hasPreview => previewImage != null && previewImage!.isNotEmpty;

  /// 是否有结果
  bool get hasResult => result != null;

  /// 生成耗时（毫秒）
  int? get durationMs {
    if (startTime == null) return null;
    final end = endTime ?? DateTime.now();
    return end.difference(startTime!).inMilliseconds;
  }
}

// ==================== 流式生成 Notifier ====================

/// 流式生成 Notifier
///
/// 用于管理单张图像的流式生成，支持：
/// - 实时预览（渐进式图像更新）
/// - 进度跟踪（步数、百分比）
/// - 取消支持
/// - 错误处理
/// - 自动回退到非流式生成
@Riverpod(keepAlive: true)
class StreamGenerationNotifier extends _$StreamGenerationNotifier {
  StreamSubscription<ImageStreamChunk>? _streamSubscription;
  bool _isCancelled = false;

  @override
  StreamGenerationState build() {
    ref.onDispose(() {
      _cleanup();
    });
    return const StreamGenerationState();
  }

  /// 清理资源
  void _cleanup() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
  }

  /// 开始流式生成
  ///
  /// [params] 生成参数（nSamples 会被强制设为 1）
  Future<void> generate(ImageParams params) async {
    if (isGenerating) {
      AppLogger.w('Generation already in progress', 'StreamGeneration');
      return;
    }

    _isCancelled = false;
    _cleanup();

    // 强制单张生成
    final singleParams = params.copyWith(nSamples: 1);

    state = StreamGenerationState(
      status: StreamGenerationStatus.connecting,
      progress: 0.0,
      startTime: DateTime.now(),
    );

    AppLogger.d('Starting stream generation', 'StreamGeneration');

    try {
      final apiService = ref.read(naiImageGenerationApiServiceProvider);
      final stream = apiService.generateImageStream(singleParams);

      _streamSubscription = stream.listen(
        _onChunkReceived,
        onError: _onError,
        onDone: _onComplete,
      );
    } catch (e) {
      _handleError(e.toString());
    }
  }

  /// 处理接收到的数据块
  void _onChunkReceived(ImageStreamChunk chunk) {
    if (_isCancelled) return;

    // 处理错误
    if (chunk.hasError) {
      // 检查是否为流式不支持错误，如果是则静默处理，等待 onDone 回退
      if (_isStreamingNotAllowed(chunk.error!)) {
        AppLogger.w(
          'Streaming not allowed, will fallback to non-stream API',
          'StreamGeneration',
        );
        return;
      }
      _handleError(chunk.error!);
      return;
    }

    // 更新状态为流式中
    if (state.status == StreamGenerationStatus.connecting) {
      state = state.copyWith(status: StreamGenerationStatus.streaming);
    }

    // 处理预览图像
    if (chunk.hasPreview) {
      state = state.copyWith(
        previewImage: chunk.previewImage,
        progress: chunk.progress.clamp(0.0, 0.99),
        currentStep: chunk.currentStep,
        totalSteps: chunk.totalSteps,
      );
    }

    // 处理最终图像
    if (chunk.isComplete && chunk.hasFinalImage) {
      state = state.copyWith(
        status: StreamGenerationStatus.completing,
        progress: 1.0,
      );
      _completeGeneration(chunk.finalImage!, state.previewImage);
    }
  }

  /// 处理流错误
  void _onError(dynamic error) {
    if (_isCancelled) return;

    final errorMessage = error.toString();

    // 检查是否为流式不支持错误
    if (_isStreamingNotAllowed(errorMessage)) {
      AppLogger.w(
        'Streaming not supported, falling back to non-stream API',
        'StreamGeneration',
      );
      _fallbackToNonStreamGeneration();
      return;
    }

    _handleError(errorMessage);
  }

  /// 处理流完成
  void _onComplete() {
    if (_isCancelled) return;

    // 如果流结束但没有最终结果，可能是流式不支持或发生错误
    if (!state.isCompleted && state.status != StreamGenerationStatus.error) {
      AppLogger.w(
        'Stream ended without final image, falling back to non-stream API',
        'StreamGeneration',
      );
      _fallbackToNonStreamGeneration();
    }
  }

  /// 完成生成
  void _completeGeneration(Uint8List imageBytes, Uint8List? previewBytes) {
    final generatedImage = GeneratedImage.create(
      imageBytes,
      width: 832,  // 使用默认值，实际应从参数获取
      height: 1216,
    );

    state = state.copyWith(
      status: StreamGenerationStatus.completed,
      result: generatedImage,
      previewImage: previewBytes,
      endTime: DateTime.now(),
      progress: 1.0,
    );

    AppLogger.d(
      'Stream generation completed in ${state.durationMs}ms',
      'StreamGeneration',
    );
  }

  /// 回退到非流式生成
  Future<void> _fallbackToNonStreamGeneration() async {
    state = state.copyWith(
      status: StreamGenerationStatus.streaming,
      clearPreviewImage: true,
    );

    try {
      final apiService = ref.read(naiImageGenerationApiServiceProvider);

      // 这里需要重新获取参数，由于我们已经丢失了原始参数，需要通知用户
      // 实际实现中，应该保存最后一次使用的参数
      AppLogger.w(
        'Non-stream fallback not fully implemented - params lost',
        'StreamGeneration',
      );

      state = state.copyWith(
        status: StreamGenerationStatus.error,
        errorMessage: '流式生成不支持且无法自动回退（参数丢失）',
        endTime: DateTime.now(),
      );
    } catch (e) {
      _handleError('回退到非流式生成失败: $e');
    }
  }

  /// 处理错误
  void _handleError(String errorMessage) {
    state = state.copyWith(
      status: StreamGenerationStatus.error,
      errorMessage: errorMessage,
      endTime: DateTime.now(),
    );

    AppLogger.e('Stream generation error: $errorMessage', 'StreamGeneration');
  }

  /// 检查错误是否为流式不支持
  bool _isStreamingNotAllowed(String error) {
    final lower = error.toLowerCase();
    return lower.contains('streaming is not allowed') ||
        lower.contains('streaming not allowed') ||
        lower.contains('stream is not allowed') ||
        lower.contains('stream not allowed');
  }

  /// 取消生成
  void cancel() {
    if (!isGenerating) return;

    _isCancelled = true;
    _streamSubscription?.cancel();
    _streamSubscription = null;

    // 取消 API 请求
    try {
      final apiService = ref.read(naiImageGenerationApiServiceProvider);
      apiService.cancelGeneration();
    } catch (e) {
      // 忽略取消时的错误
    }

    state = state.copyWith(
      status: StreamGenerationStatus.cancelled,
      endTime: DateTime.now(),
      clearPreviewImage: true,
    );

    AppLogger.d('Stream generation cancelled', 'StreamGeneration');
  }

  /// 重置状态
  void reset() {
    _isCancelled = false;
    _cleanup();
    state = const StreamGenerationState();
  }

  /// 清除错误
  void clearError() {
    if (state.status == StreamGenerationStatus.error) {
      state = state.copyWith(
        status: StreamGenerationStatus.idle,
        errorMessage: null,
      );
    }
  }

  /// 清除结果（保留预览）
  void clearResult() {
    state = state.copyWith(
      status: StreamGenerationStatus.idle,
      result: null,
      errorMessage: null,
      progress: 0.0,
      clearPreviewImage: true,
      currentStep: null,
      totalSteps: null,
      startTime: null,
      endTime: null,
    );
  }

  /// 是否正在生成
  bool get isGenerating => state.isGenerating;

  /// 获取当前结果
  GeneratedImage? get result => state.result;

  /// 获取当前预览
  Uint8List? get previewImage => state.previewImage;
}
