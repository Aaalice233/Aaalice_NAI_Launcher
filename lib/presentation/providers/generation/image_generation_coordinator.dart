import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/utils/app_logger.dart';
import '../../../data/datasources/remote/nai_generation_transport.dart';
import '../../../data/datasources/remote/nai_image_generation_api_service.dart';
import '../../../data/models/image/image_params.dart';
import 'generation_command.dart';
import 'generation_error_classifier.dart';

/// Owns the single generation algorithm. It has no Riverpod dependency and
/// reports effects as immutable events for the notifier to reduce.
class ImageGenerationCoordinator {
  ImageGenerationCoordinator({
    required NAIImageGenerationApiService apiService,
    List<Duration> retryDelays = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ],
    this.concurrencyRetryInterval = const Duration(seconds: 3),
    this.concurrencyRetryBudget = const Duration(seconds: 90),
    Future<void> Function(Duration) delay = Future<void>.delayed,
    Random? random,
  }) : _apiService = apiService,
       _retryDelays = retryDelays,
       _delay = delay,
       _random = random ?? Random();

  static const int randomSeedExclusiveUpperBound = 4294967295;

  final NAIImageGenerationApiService _apiService;
  final List<Duration> _retryDelays;
  final Future<void> Function(Duration) _delay;
  final Duration concurrencyRetryInterval;
  final Duration concurrencyRetryBudget;
  final Random _random;

  GenerationRunHandle? _activeRun;
  bool _skipCurrentRequest = false;
  bool _hasRemainingImages = false;

  GenerationRunHandle start(GenerationCommand command) {
    final handle = GenerationRunHandle(
      runId: command.runId,
      cancellation: GenerationCancellationToken(),
      requestLease: NaiGenerationCancellationLease(),
    );
    _activeRun = handle;
    _skipCurrentRequest = false;
    _hasRemainingImages = false;
    return handle;
  }

  void cancel(GenerationRunHandle handle) {
    if (!identical(_activeRun, handle)) return;
    handle.cancellation.cancel();
    _apiService.cancelGeneration(handle.requestLease);
  }

  bool skipCurrentRequest(GenerationRunHandle handle) {
    if (!identical(_activeRun, handle) || !_hasRemainingImages) {
      cancel(handle);
      return false;
    }
    _skipCurrentRequest = true;
    _apiService.cancelCurrentGenerationRequest(handle.requestLease);
    return true;
  }

  Stream<GenerationEvent> execute(
    GenerationCommand command,
    GenerationRunHandle handle,
  ) async* {
    if (!identical(_activeRun, handle) || handle.runId != command.runId) return;

    try {
      var currentParams = command.params;
      final allImages = <Uint8List>[];
      Object? lastError;
      var consumedImages = 0;

      yield GenerationStarted(
        runId: command.runId,
        params: currentParams,
        totalImages: command.totalImages,
      );

      for (var batch = 0; batch < command.batchCount; batch++) {
        if (_aborted(handle)) break;
        try {
          currentParams = await command.prepareBatch(batch, currentParams);
        } catch (error) {
          lastError = error;
          break;
        }
        if (_aborted(handle)) break;

        final batchSeed = command.materializeRandomSeed
            ? command.totalImages == 1 && currentParams.seed != -1
                  ? currentParams.seed
                  : _random.nextInt(randomSeedExclusiveUpperBound)
            : currentParams.seed == -1
            ? -1
            : currentParams.seed + batch;
        final startImage = consumedImages + 1;
        final eventParams = currentParams.copyWith(
          nSamples: 1,
          seed: batchSeed,
        );
        _skipCurrentRequest = false;
        _hasRemainingImages =
            command.totalImages > startImage + command.batchSize - 1;
        yield GenerationRequestStarted(
          runId: command.runId,
          params: eventParams,
          startImage: startImage,
          requestSize: command.batchSize,
          totalImages: command.totalImages,
        );

        try {
          final batchImages = <Uint8List>[];
          final batchEncodings = <int, String>{};
          final batchIndexedEncodings = <GenerationVibeEncoding>[];
          Object? batchError;
          var nonStreamOnly = false;

          if (!command.requestEachImage) {
            final requestParams = currentParams.copyWith(
              nSamples: command.batchSize,
              seed: batchSeed,
            );
            try {
              var result = const _RequestResult();
              await for (final signal in _runRequest(
                command: command,
                handle: handle,
                params: requestParams,
                startImage: startImage,
                nonStreamOnly: false,
                retryStreamFailures: command.totalImages > 1,
              )) {
                if (signal.event != null) yield signal.event!;
                if (signal.result != null) result = signal.result!;
              }
              batchImages.addAll(result.images);
              batchEncodings.addAll(result.slotEncodings);
            } catch (error) {
              batchError = error;
            }
          } else {
            for (var image = 0; image < command.batchSize; image++) {
              if (_aborted(handle) || _skipCurrentRequest) break;
              final imageNumber = startImage + image;
              final requestParams = currentParams.copyWith(
                nSamples: 1,
                seed: batchSeed == -1 ? -1 : batchSeed + image,
              );
              if (command.totalImages > 1) {
                yield GenerationImageStarted(
                  runId: command.runId,
                  params: requestParams,
                  imageNumber: imageNumber,
                  totalImages: command.totalImages,
                );
              }
              try {
                var result = const _RequestResult();
                await for (final signal in _runRequest(
                  command: command,
                  handle: handle,
                  params: requestParams,
                  startImage: imageNumber,
                  nonStreamOnly: nonStreamOnly,
                  retryStreamFailures: command.totalImages > 1,
                )) {
                  if (signal.event != null) yield signal.event!;
                  if (signal.result != null) result = signal.result!;
                  if (signal.nonStreamOnly) nonStreamOnly = true;
                }
                if (result.images.isNotEmpty) {
                  batchImages.add(result.images.first);
                  batchEncodings.addAll(result.slotEncodings);
                  final encodingImageIndex = command.totalImages == 1
                      ? 0
                      : imageNumber;
                  batchIndexedEncodings.addAll(
                    result.slotEncodings.entries.map(
                      (entry) => GenerationVibeEncoding(
                        imageIndex: encodingImageIndex,
                        slot: entry.key,
                        encoding: entry.value,
                      ),
                    ),
                  );
                }
              } catch (error) {
                if (_aborted(handle) || _skipCurrentRequest) break;
                batchError = error;
                AppLogger.e('Failed to generate image $imageNumber: $error');
              }
            }
          }

          if (_aborted(handle)) break;
          if (_skipCurrentRequest) {
            yield GenerationRequestSkipped(
              runId: command.runId,
              startImage: startImage,
              requestSize: command.batchSize,
            );
            consumedImages += command.batchSize;
            continue;
          }
          if (batchImages.isNotEmpty) {
            allImages.addAll(batchImages);
            yield GenerationRequestCompleted(
              runId: command.runId,
              params: eventParams,
              startImage: startImage,
              totalImages: command.totalImages,
              images: batchImages,
              vibeEncodings: batchEncodings,
              indexedVibeEncodings: batchIndexedEncodings,
            );
          } else if (batchError != null) {
            lastError = batchError;
            yield GenerationRequestFailed(
              runId: command.runId,
              startImage: startImage,
              requestSize: command.batchSize,
              error: batchError,
              isTerminal: command.batchCount == 1,
            );
          }
          consumedImages += command.batchSize;
        } finally {
          _skipCurrentRequest = false;
          _hasRemainingImages = false;
        }
      }

      if (_aborted(handle)) {
        yield GenerationCancelled(command.runId);
      } else if (allImages.isEmpty) {
        yield GenerationFailed(
          command.runId,
          lastError ?? StateError('No images returned from generation'),
        );
      } else {
        yield GenerationCompleted(
          runId: command.runId,
          params: currentParams,
          images: List<Uint8List>.unmodifiable(allImages),
        );
      }

      if (identical(_activeRun, handle)) _activeRun = null;
    } finally {
      _apiService.releaseCancellationLease(handle.requestLease);
    }
  }

  Stream<_RequestSignal> _runRequest({
    required GenerationCommand command,
    required GenerationRunHandle handle,
    required ImageParams params,
    required int startImage,
    required bool nonStreamOnly,
    required bool retryStreamFailures,
  }) async* {
    DateTime? concurrencyDeadline;
    final startWithFallback = nonStreamOnly || !command.streamPreviewEnabled;
    var mode = startWithFallback ? _RequestMode.fallback : _RequestMode.stream;
    var persistFallbackMode = startWithFallback;

    for (var attempt = 0; ; attempt++) {
      if (_aborted(handle) || _skipCurrentRequest) return;
      try {
        if (mode == _RequestMode.fallback) {
          final result = await _runFallbackWithRetry(command, handle, params);
          if (_aborted(handle) || _skipCurrentRequest) return;
          yield _RequestSignal.result(
            result,
            nonStreamOnly: persistFallbackMode,
          );
          return;
        }

        final images = <int, Uint8List>{};
        await for (final chunk
            in NAIImageGenerationApiService.withCancellationLease(
              handle.requestLease,
              () => _apiService.generateImageStream(
                params,
                focusedInpaintEnabled: command.focusedInpaintEnabled,
                minimumContextMegaPixels: command.minimumContextMegaPixels,
                focusedSelectionRect: command.focusedSelectionRect,
              ),
            )) {
          if (_aborted(handle) || _skipCurrentRequest) return;
          if (chunk.hasError) {
            final error = chunk.error ?? 'Unknown stream error';
            if (isStreamingGenerationUnsupportedError(error)) {
              mode = _RequestMode.fallback;
              persistFallbackMode = true;
              break;
            }
            throw _GenerationRemoteException(error);
          }
          final sample = chunk.sampleIndex.clamp(0, params.nSamples - 1);
          final imageNumber = startImage + sample;
          if (chunk.hasPreview) {
            yield _RequestSignal.event(
              GenerationPreviewReceived(
                runId: command.runId,
                params: params,
                imageNumber: imageNumber,
                totalImages: command.totalImages,
                progress: chunk.progress.clamp(0.0, 0.99),
                bytes: Uint8List.fromList(chunk.previewImage!),
                currentStep: chunk.currentStep,
                totalSteps: chunk.totalSteps,
                focusedPreviewPlacement: chunk.focusedPreviewPlacement,
              ),
            );
          }
          if (chunk.isComplete && chunk.hasFinalImage) {
            images[chunk.sampleIndex] = chunk.finalImage!;
            yield _RequestSignal.event(
              GenerationImageFinalizing(
                runId: command.runId,
                imageNumber: imageNumber,
                totalImages: command.totalImages,
              ),
            );
          }
        }
        if (mode == _RequestMode.fallback || images.isEmpty) {
          if (_aborted(handle) || _skipCurrentRequest) return;
          mode = _RequestMode.fallback;
          continue;
        }
        final ordered = images.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        yield _RequestSignal.result(
          _RequestResult(images: ordered.map((entry) => entry.value).toList()),
        );
        return;
      } catch (error) {
        if (_aborted(handle) || _skipCurrentRequest) return;
        // A server-side "Cancelled" result is a generation error. Only the
        // local run token maps cancellation to GenerationCancelled.
        if (_isRemoteCancelled(error) || mode == _RequestMode.fallback) {
          rethrow;
        }
        if (_isConcurrencyLimited(error)) {
          concurrencyDeadline ??= DateTime.now().add(concurrencyRetryBudget);
          if (DateTime.now().isBefore(concurrencyDeadline)) {
            if (!await _waitForRetry(handle, concurrencyRetryInterval)) return;
            continue;
          }
          rethrow;
        }
        if (isStreamingGenerationUnsupportedError(error)) {
          mode = _RequestMode.fallback;
          persistFallbackMode = true;
          continue;
        }
        if (!retryStreamFailures || attempt >= _retryDelays.length) rethrow;
        AppLogger.w(
          '生成失败，${_retryDelays[attempt].inMilliseconds}ms 后重试 '
          '(${attempt + 1}/${_retryDelays.length}): $error',
        );
        if (!await _waitForRetry(handle, _retryDelays[attempt])) return;
      }
    }
  }

  Future<bool> _waitForRetry(
    GenerationRunHandle handle,
    Duration duration,
  ) async {
    await Future.any<void>([
      _delay(duration),
      handle.cancellation.whenCancelled,
    ]);
    return !_aborted(handle) && !_skipCurrentRequest;
  }

  Future<_RequestResult> _runFallbackWithRetry(
    GenerationCommand command,
    GenerationRunHandle handle,
    ImageParams params,
  ) async {
    for (var attempt = 0; ; attempt++) {
      if (_aborted(handle) || _skipCurrentRequest) {
        return const _RequestResult();
      }
      try {
        return await _runFallback(command, handle, params);
      } catch (error) {
        if (_aborted(handle) || _skipCurrentRequest) {
          return const _RequestResult();
        }
        if (_isRemoteCancelled(error) || attempt >= _retryDelays.length) {
          rethrow;
        }
        AppLogger.w(
          '非流式生成失败，${_retryDelays[attempt].inMilliseconds}ms 后重试 '
          '(${attempt + 1}/${_retryDelays.length}): $error',
        );
        if (!await _waitForRetry(handle, _retryDelays[attempt])) {
          return const _RequestResult();
        }
      }
    }
  }

  Future<_RequestResult> _runFallback(
    GenerationCommand command,
    GenerationRunHandle handle,
    ImageParams params,
  ) async {
    if (_aborted(handle) || _skipCurrentRequest) {
      return const _RequestResult();
    }
    if (command.cancellableFallback && command.totalImages > 1) {
      final (
        images,
        encodings,
      ) = await NAIImageGenerationApiService.withCancellationLease(
        handle.requestLease,
        () => _apiService.generateImageWithEncodingsCancellable(
          params,
          onProgress: (_, _) {},
          focusedInpaintEnabled: command.focusedInpaintEnabled,
          minimumContextMegaPixels: command.minimumContextMegaPixels,
          focusedSelectionRect: command.focusedSelectionRect,
        ),
      );
      if (_aborted(handle) || _skipCurrentRequest) {
        return const _RequestResult();
      }
      return _RequestResult(images: images, slotEncodings: encodings);
    }

    final (
      images,
      encodings,
    ) = await NAIImageGenerationApiService.withCancellationLease(
      handle.requestLease,
      () => _apiService.generateImage(
        params,
        onProgress: (_, _) {},
        focusedInpaintEnabled: command.focusedInpaintEnabled,
        minimumContextMegaPixels: command.minimumContextMegaPixels,
        focusedSelectionRect: command.focusedSelectionRect,
      ),
    );
    if (_aborted(handle) || _skipCurrentRequest) {
      return const _RequestResult();
    }
    return _RequestResult(images: images, slotEncodings: encodings);
  }

  bool _aborted(GenerationRunHandle handle) =>
      handle.isCancelled || !identical(_activeRun, handle);

  static bool _isRemoteCancelled(Object error) =>
      error.toString().toLowerCase().contains('cancelled');

  static bool _isConcurrencyLimited(Object error) {
    if (error is DioException) return error.response?.statusCode == 429;
    final text = error.toString();
    return text.contains('API_ERROR_429') || text.contains(' 429');
  }
}

enum _RequestMode { stream, fallback }

class _GenerationRemoteException implements Exception {
  const _GenerationRemoteException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _RequestResult {
  const _RequestResult({this.images = const [], this.slotEncodings = const {}});

  final List<Uint8List> images;
  final Map<int, String> slotEncodings;
}

class _RequestSignal {
  const _RequestSignal._({this.event, this.result, this.nonStreamOnly = false});

  factory _RequestSignal.event(GenerationEvent event) =>
      _RequestSignal._(event: event);
  factory _RequestSignal.result(
    _RequestResult result, {
    bool nonStreamOnly = false,
  }) => _RequestSignal._(result: result, nonStreamOnly: nonStreamOnly);

  final GenerationEvent? event;
  final _RequestResult? result;
  final bool nonStreamOnly;
}
