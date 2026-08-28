import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/app_logger.dart';
import '../../../data/datasources/remote/nai_image_generation_api_service.dart';
import '../../../data/models/image/image_params.dart';
import 'generation_models.dart';
import 'image_generation_service.dart';

part 'stream_generation_notifier.g.dart';

enum StreamGenerationStatus {
  idle,
  connecting,
  streaming,
  completing,
  completed,
  error,
  cancelled,
}

class StreamGenerationState {
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

  final StreamGenerationStatus status;
  final GeneratedImage? result;
  final String? errorMessage;
  final double progress;
  final Uint8List? previewImage;
  final int? currentStep;
  final int? totalSteps;
  final DateTime? startTime;
  final DateTime? endTime;

  StreamGenerationState copyWith({
    StreamGenerationStatus? status,
    GeneratedImage? result,
    bool clearResult = false,
    String? errorMessage,
    double? progress,
    Uint8List? previewImage,
    bool clearPreviewImage = false,
    int? currentStep,
    int? totalSteps,
    bool clearSteps = false,
    DateTime? startTime,
    DateTime? endTime,
    bool clearTiming = false,
  }) {
    return StreamGenerationState(
      status: status ?? this.status,
      result: clearResult ? null : (result ?? this.result),
      errorMessage: errorMessage,
      progress: progress ?? this.progress,
      previewImage: clearPreviewImage
          ? null
          : (previewImage ?? this.previewImage),
      currentStep: clearSteps ? null : (currentStep ?? this.currentStep),
      totalSteps: clearSteps ? null : (totalSteps ?? this.totalSteps),
      startTime: clearTiming ? null : (startTime ?? this.startTime),
      endTime: clearTiming ? null : (endTime ?? this.endTime),
    );
  }

  bool get isGenerating =>
      status == StreamGenerationStatus.connecting ||
      status == StreamGenerationStatus.streaming ||
      status == StreamGenerationStatus.completing;
  bool get isIdle => status == StreamGenerationStatus.idle;
  bool get isCompleted => status == StreamGenerationStatus.completed;
  bool get hasPreview => previewImage?.isNotEmpty == true;
  bool get hasResult => result != null;

  int? get durationMs {
    if (startTime == null) return null;
    return (endTime ?? DateTime.now()).difference(startTime!).inMilliseconds;
  }
}

/// Compatibility notifier that projects the shared coordinator result into the
/// legacy stream-specific state shape.
@Riverpod(keepAlive: true)
class StreamGenerationNotifier extends _$StreamGenerationNotifier {
  ImageGenerationService? _service;

  @override
  StreamGenerationState build() {
    ref.onDispose(_cleanup);
    return const StreamGenerationState();
  }

  void _cleanup() {
    _service?.cancel();
    _service = null;
  }

  Future<void> generate(ImageParams params) async {
    if (isGenerating) {
      AppLogger.w('Generation already in progress', 'StreamGeneration');
      return;
    }
    final service = ImageGenerationService(
      apiService: ref.read(naiImageGenerationApiServiceProvider),
    );
    _service = service;
    state = StreamGenerationState(
      status: StreamGenerationStatus.connecting,
      startTime: DateTime.now(),
    );
    final result = await service.generateSingle(
      params,
      onProgress: (_, _, progress, {previewImage}) {
        if (!identical(_service, service) || service.isCancelled) return;
        state = state.copyWith(
          status: StreamGenerationStatus.streaming,
          progress: progress,
          previewImage: previewImage,
        );
      },
      onStepProgress: (currentStep, totalSteps) {
        if (!identical(_service, service) || service.isCancelled) return;
        state = state.copyWith(
          currentStep: currentStep,
          totalSteps: totalSteps,
        );
      },
      onCompleting: () {
        if (!identical(_service, service) || service.isCancelled) return;
        state = state.copyWith(
          status: StreamGenerationStatus.completing,
          progress: 1,
        );
      },
    );
    if (!identical(_service, service)) return;
    _service = null;
    if (result.isCancelled) {
      state = state.copyWith(
        status: StreamGenerationStatus.cancelled,
        endTime: DateTime.now(),
        clearPreviewImage: true,
      );
    } else if (result.isSuccess) {
      state = state.copyWith(
        status: StreamGenerationStatus.completed,
        result: result.images.first,
        progress: 1,
        endTime: DateTime.now(),
      );
    } else {
      state = state.copyWith(
        status: StreamGenerationStatus.error,
        errorMessage: result.error ?? 'No image returned from generation',
        endTime: DateTime.now(),
      );
    }
  }

  void cancel() {
    if (!isGenerating) return;
    final service = _service;
    _service = null;
    service?.cancel();
    state = state.copyWith(
      status: StreamGenerationStatus.cancelled,
      endTime: DateTime.now(),
      clearPreviewImage: true,
    );
  }

  void reset() {
    _cleanup();
    state = const StreamGenerationState();
  }

  void clearError() {
    if (state.status == StreamGenerationStatus.error) {
      state = state.copyWith(
        status: StreamGenerationStatus.idle,
        errorMessage: null,
      );
    }
  }

  void clearResult() {
    state = state.copyWith(
      status: StreamGenerationStatus.idle,
      clearResult: true,
      errorMessage: null,
      progress: 0,
      clearPreviewImage: true,
      clearSteps: true,
      clearTiming: true,
    );
  }

  bool get isGenerating => state.isGenerating;
  GeneratedImage? get result => state.result;
  Uint8List? get previewImage => state.previewImage;
}
