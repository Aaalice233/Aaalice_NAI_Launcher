import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import '../../../data/datasources/remote/nai_generation_transport.dart';
import '../../../data/models/image/image_params.dart';
import '../../../data/models/image/image_postprocess_phase.dart';
import '../../../data/models/image/image_stream_chunk.dart';

/// Immutable description of one user-initiated generation run.
class GenerationCommand {
  const GenerationCommand({
    required this.runId,
    required this.params,
    required this.batchCount,
    required this.batchSize,
    required this.prepareBatch,
    this.focusedInpaintEnabled = false,
    this.minimumContextMegaPixels = 88.0,
    this.focusedSelectionRect,
    this.materializeRandomSeed = true,
    this.requestEachImage = false,
    this.cancellableFallback = true,
    this.streamPreviewEnabled = true,
  });

  final int runId;
  final ImageParams params;
  final int batchCount;
  final int batchSize;
  final Future<ImageParams> Function(int batchIndex, ImageParams currentParams)
  prepareBatch;
  final bool focusedInpaintEnabled;
  final double minimumContextMegaPixels;
  final Rect? focusedSelectionRect;
  final bool materializeRandomSeed;
  final bool requestEachImage;
  final bool cancellableFallback;
  final bool streamPreviewEnabled;

  int get totalImages => batchCount * batchSize;
}

/// Immutable identity for one run. Cancellation is an explicit dependency so
/// stale runs cannot affect a newer handle with a different token identity.
class GenerationRunHandle {
  const GenerationRunHandle({
    required this.runId,
    required this.cancellation,
    required this.requestLease,
  });

  final int runId;
  final GenerationCancellationToken cancellation;
  final NaiGenerationCancellationLease requestLease;

  bool get isCancelled => cancellation.isCancelled;
}

class GenerationCancellationToken {
  bool _isCancelled = false;
  final Completer<void> _cancelled = Completer<void>();

  bool get isCancelled => _isCancelled;
  Future<void> get whenCancelled => _cancelled.future;

  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    _cancelled.complete();
  }
}

sealed class GenerationEvent {
  const GenerationEvent({required this.runId});

  final int runId;
}

class GenerationStarted extends GenerationEvent {
  const GenerationStarted({
    required super.runId,
    required this.params,
    required this.totalImages,
  });

  final ImageParams params;
  final int totalImages;
}

class GenerationRequestStarted extends GenerationEvent {
  const GenerationRequestStarted({
    required super.runId,
    required this.params,
    required this.startImage,
    required this.requestSize,
    required this.totalImages,
  });

  final ImageParams params;
  final int startImage;
  final int requestSize;
  final int totalImages;
}

class GenerationImageStarted extends GenerationEvent {
  const GenerationImageStarted({
    required super.runId,
    required this.params,
    required this.imageNumber,
    required this.totalImages,
  });

  final ImageParams params;
  final int imageNumber;
  final int totalImages;
}

class GenerationPreviewReceived extends GenerationEvent {
  const GenerationPreviewReceived({
    required super.runId,
    required this.params,
    required this.imageNumber,
    required this.totalImages,
    required this.progress,
    required this.bytes,
    this.currentStep,
    this.totalSteps,
    this.focusedPreviewPlacement,
  });

  final ImageParams params;
  final int imageNumber;
  final int totalImages;
  final double progress;
  final Uint8List bytes;
  final int? currentStep;
  final int? totalSteps;
  final FocusedStreamPreviewPlacement? focusedPreviewPlacement;
}

/// 服务端已交付该样本的最终图，流正在收尾。
class GenerationImageFinalizing extends GenerationEvent {
  const GenerationImageFinalizing({
    required super.runId,
    required this.imageNumber,
    required this.totalImages,
  });

  final int imageNumber;
  final int totalImages;
}

class GenerationPostprocessChanged extends GenerationEvent {
  const GenerationPostprocessChanged({
    required super.runId,
    required this.imageNumber,
    required this.totalImages,
    required this.phase,
  });
  final int imageNumber;
  final int totalImages;
  final ImagePostprocessPhase phase;
}

class GenerationRequestCompleted extends GenerationEvent {
  const GenerationRequestCompleted({
    required super.runId,
    required this.params,
    required this.startImage,
    required this.totalImages,
    required this.images,
    this.postprocessErrors = const {},
    this.vibeEncodings = const <int, String>{},
    this.indexedVibeEncodings = const <GenerationVibeEncoding>[],
  });

  final ImageParams params;
  final int startImage;
  final int totalImages;
  final List<Uint8List> images;
  final Map<int, String> postprocessErrors;

  /// Request-shared slot encodings retained for existing event consumers.
  final Map<int, String> vibeEncodings;

  /// Encodings whose originating image is known, used by per-image requests.
  final List<GenerationVibeEncoding> indexedVibeEncodings;
}

class GenerationVibeEncoding {
  const GenerationVibeEncoding({
    required this.imageIndex,
    required this.slot,
    required this.encoding,
  });

  final int imageIndex;
  final int slot;
  final String encoding;
}

class GenerationRequestSkipped extends GenerationEvent {
  const GenerationRequestSkipped({
    required super.runId,
    required this.startImage,
    required this.requestSize,
  });

  final int startImage;
  final int requestSize;
}

class GenerationRequestFailed extends GenerationEvent {
  const GenerationRequestFailed({
    required super.runId,
    required this.startImage,
    required this.requestSize,
    required this.error,
    required this.isTerminal,
  });

  final int startImage;
  final int requestSize;
  final Object error;
  final bool isTerminal;
}

class GenerationCompleted extends GenerationEvent {
  const GenerationCompleted({
    required super.runId,
    required this.params,
    required this.images,
  });

  final ImageParams params;
  final List<Uint8List> images;
}

class GenerationCancelled extends GenerationEvent {
  const GenerationCancelled(int runId) : super(runId: runId);
}

class GenerationFailed extends GenerationEvent {
  const GenerationFailed(int runId, this.error) : super(runId: runId);

  final Object error;
}
