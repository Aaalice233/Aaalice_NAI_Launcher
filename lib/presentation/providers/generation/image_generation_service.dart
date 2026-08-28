import 'dart:typed_data';

import '../../../data/datasources/remote/nai_image_generation_api_service.dart';
import '../../../data/models/image/image_params.dart';
import 'generation_command.dart';
import 'generation_models.dart';
import 'image_generation_coordinator.dart';

/// Compatibility result retained for callers of the former service facade.
class ImageGenerationResult {
  const ImageGenerationResult({
    required this.images,
    this.vibeEncodings = const {},
    this.isCancelled = false,
    this.error,
  });

  final List<GeneratedImage> images;
  final Map<String, String> vibeEncodings;
  final bool isCancelled;
  final String? error;

  bool get isSuccess => error == null && !isCancelled && images.isNotEmpty;

  factory ImageGenerationResult.cancelled() =>
      const ImageGenerationResult(images: [], isCancelled: true);

  factory ImageGenerationResult.error(String message) =>
      ImageGenerationResult(images: const [], error: message);
}

typedef GenerationProgressCallback =
    void Function(
      int current,
      int total,
      double progress, {
      Uint8List? previewImage,
    });

typedef GenerationStepProgressCallback =
    void Function(int? currentStep, int? totalSteps);

/// Backward-compatible facade over [ImageGenerationCoordinator].
///
/// There is deliberately no generation algorithm here: provider generation,
/// batch generation and legacy callers all execute the same coordinator.
class ImageGenerationService {
  ImageGenerationService({
    required NAIImageGenerationApiService apiService,
    List<Duration> retryDelays = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ],
    Future<void> Function(Duration) delay = Future<void>.delayed,
  }) : _apiService = apiService,
       _coordinator = ImageGenerationCoordinator(
         apiService: apiService,
         retryDelays: retryDelays,
         delay: delay,
       );

  final NAIImageGenerationApiService _apiService;
  final ImageGenerationCoordinator _coordinator;
  GenerationRunHandle? _activeRun;
  var _runCounter = 0;
  var _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() {
    _cancelled = true;
    final run = _activeRun;
    if (run != null) {
      _coordinator.cancel(run);
    } else {
      _apiService.cancelGeneration();
    }
  }

  void resetCancellation() {
    _cancelled = false;
  }

  Future<ImageGenerationResult> generateSingle(
    ImageParams params, {
    GenerationProgressCallback? onProgress,
    GenerationStepProgressCallback? onStepProgress,
    void Function()? onCompleting,
  }) => _execute(
    params.copyWith(nSamples: 1),
    batchCount: 1,
    batchSize: 1,
    onProgress: onProgress,
    onStepProgress: onStepProgress,
    onCompleting: onCompleting,
  );

  Future<ImageGenerationResult> generateBatch(
    ImageParams params, {
    required int batchCount,
    required int batchSize,
    void Function(int batchIndex, int currentImage, int totalImages)?
    onBatchStart,
    GenerationProgressCallback? onProgress,
    GenerationStepProgressCallback? onStepProgress,
    void Function()? onCompleting,
    void Function(List<GeneratedImage> batchImages)? onBatchComplete,
  }) async {
    if (batchCount <= 0 || batchSize <= 0) {
      return ImageGenerationResult.error('批次数量和批次大小必须大于0');
    }
    return _execute(
      params,
      batchCount: batchCount,
      batchSize: batchSize,
      onBatchStart: onBatchStart,
      onProgress: onProgress,
      onStepProgress: onStepProgress,
      onCompleting: onCompleting,
      onBatchComplete: onBatchComplete,
    );
  }

  Future<ImageGenerationResult> _execute(
    ImageParams params, {
    required int batchCount,
    required int batchSize,
    GenerationProgressCallback? onProgress,
    GenerationStepProgressCallback? onStepProgress,
    void Function()? onCompleting,
    void Function(int batchIndex, int currentImage, int totalImages)?
    onBatchStart,
    void Function(List<GeneratedImage> batchImages)? onBatchComplete,
  }) async {
    final runId = ++_runCounter;
    _cancelled = false;
    final command = GenerationCommand(
      runId: runId,
      params: params,
      batchCount: batchCount,
      batchSize: batchSize,
      prepareBatch: (_, current) async => current,
      materializeRandomSeed: false,
      requestEachImage: true,
      cancellableFallback: false,
    );
    final handle = _coordinator.start(command);
    _activeRun = handle;
    final images = <GeneratedImage>[];
    final encodings = <String, String>{};
    Object? error;
    var cancelled = false;
    var batchIndex = 0;

    try {
      await for (final event in _coordinator.execute(command, handle)) {
        switch (event) {
          case GenerationRequestStarted(:final startImage, :final totalImages):
            onBatchStart?.call(batchIndex, startImage, totalImages);
          case GenerationImageStarted(:final imageNumber, :final totalImages):
            onProgress?.call(
              imageNumber,
              totalImages,
              (imageNumber - 1) / totalImages,
            );
          case GenerationPreviewReceived(
            :final imageNumber,
            :final totalImages,
            :final progress,
            :final bytes,
            :final currentStep,
            :final totalSteps,
          ):
            if (progress < 1) {
              onProgress?.call(
                imageNumber,
                totalImages,
                ((imageNumber - 1) + progress) / totalImages,
                previewImage: bytes,
              );
              onStepProgress?.call(currentStep, totalSteps);
            } else {
              onCompleting?.call();
            }
          case GenerationRequestCompleted(
            :final params,
            images: final bytes,
            :final indexedVibeEncodings,
          ):
            final generated = bytes
                .map(
                  (image) => GeneratedImage.create(
                    image,
                    width: params.width,
                    height: params.height,
                  ),
                )
                .toList();
            images.addAll(generated);
            for (final entry in indexedVibeEncodings) {
              encodings['${entry.imageIndex}_${entry.slot}'] = entry.encoding;
            }
            onBatchComplete?.call(generated);
            batchIndex++;
          case GenerationRequestFailed(error: final requestError):
            error = requestError;
            batchIndex++;
          case GenerationFailed(error: final runError):
            error = runError;
          case GenerationCancelled():
            cancelled = true;
          case GenerationStarted() ||
              GenerationRequestSkipped() ||
              GenerationCompleted():
            break;
        }
      }
      if (cancelled || handle.isCancelled || _isCancelledError(error)) {
        _cancelled = true;
        return ImageGenerationResult.cancelled();
      }
      if (images.isEmpty && error != null) {
        return ImageGenerationResult.error(error.toString());
      }
      return ImageGenerationResult(images: images, vibeEncodings: encodings);
    } catch (caughtError) {
      if (handle.isCancelled || _cancelled || _isCancelledError(caughtError)) {
        _cancelled = true;
        return ImageGenerationResult.cancelled();
      }
      return ImageGenerationResult.error(caughtError.toString());
    } finally {
      if (identical(_activeRun, handle)) _activeRun = null;
    }
  }

  static bool _isCancelledError(Object? error) =>
      error?.toString().toLowerCase().contains('cancelled') ?? false;
}
