import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_generation_api_service.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/image/image_stream_chunk.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_command.dart';
import 'package:nai_launcher/presentation/providers/generation/image_generation_coordinator.dart';

class _MockNAIImageGenerationApiService extends Mock
    implements NAIImageGenerationApiService {}

void main() {
  setUpAll(() {
    registerFallbackValue(const ImageParams());
  });

  test('prepareBatch exceptions become terminal failure events', () async {
    final apiService = _MockNAIImageGenerationApiService();
    final coordinator = ImageGenerationCoordinator(apiService: apiService);
    final command = GenerationCommand(
      runId: 1,
      params: const ImageParams(prompt: 'test'),
      batchCount: 1,
      batchSize: 1,
      prepareBatch: (_, _) =>
          Future<ImageParams>.error(StateError('prepareBatch failed')),
    );
    final handle = coordinator.start(command);

    final events = await coordinator.execute(command, handle).toList();

    expect(events, hasLength(2));
    expect(events.first, isA<GenerationStarted>());
    expect(events.last, isA<GenerationFailed>());
    expect(
      (events.last as GenerationFailed).error.toString(),
      contains('prepareBatch failed'),
    );
    verifyNever(
      () => apiService.generateImageStream(
        any(),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    );
  });

  test(
    'disabled stream preview uses the non-stream endpoint directly',
    () async {
      final apiService = _MockNAIImageGenerationApiService();
      final image = Uint8List.fromList([1, 2, 3]);
      when(
        () => apiService.generateImage(
          any(),
          onProgress: any(named: 'onProgress'),
          focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
          minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
          focusedSelectionRect: any(named: 'focusedSelectionRect'),
        ),
      ).thenAnswer((_) async => (<Uint8List>[image], <int, String>{}));

      final coordinator = ImageGenerationCoordinator(apiService: apiService);
      final command = GenerationCommand(
        runId: 1,
        params: const ImageParams(prompt: 'test'),
        batchCount: 1,
        batchSize: 1,
        prepareBatch: (_, params) async => params,
        streamPreviewEnabled: false,
      );
      final handle = coordinator.start(command);

      final events = await coordinator.execute(command, handle).toList();

      expect(events.whereType<GenerationPreviewReceived>(), isEmpty);
      expect(events.whereType<GenerationRequestCompleted>(), hasLength(1));
      expect(events.last, isA<GenerationCompleted>());
      verifyNever(
        () => apiService.generateImageStream(
          any(),
          focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
          minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
          focusedSelectionRect: any(named: 'focusedSelectionRect'),
        ),
      );
      verify(
        () => apiService.generateImage(
          any(),
          onProgress: any(named: 'onProgress'),
          focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
          minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
          focusedSelectionRect: any(named: 'focusedSelectionRect'),
        ),
      ).called(1);
    },
  );

  test('cancel interrupts an injected 429 concurrency retry delay', () async {
    final apiService = _MockNAIImageGenerationApiService();
    final delayStarted = Completer<void>();
    final blockedDelay = Completer<void>();
    when(
      () => apiService.generateImageStream(
        any(),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenAnswer((_) => Stream.value(ImageStreamChunk.error('API_ERROR_429')));
    when(() => apiService.cancelGeneration(any())).thenReturn(null);

    final coordinator = ImageGenerationCoordinator(
      apiService: apiService,
      delay: (_) {
        if (!delayStarted.isCompleted) delayStarted.complete();
        return blockedDelay.future;
      },
    );
    final command = GenerationCommand(
      runId: 1,
      params: const ImageParams(prompt: 'test'),
      batchCount: 1,
      batchSize: 1,
      prepareBatch: (_, params) async => params,
    );
    final handle = coordinator.start(command);
    final events = coordinator.execute(command, handle).toList();

    await delayStarted.future;
    coordinator.cancel(handle);

    final completedEvents = await events.timeout(const Duration(seconds: 1));
    expect(completedEvents.last, isA<GenerationCancelled>());
    expect(blockedDelay.isCompleted, isFalse);
    blockedDelay.complete();
  });

  test(
    'cancel before an empty stream ends prevents fallback request',
    () async {
      final apiService = _MockNAIImageGenerationApiService();
      final streamStarted = Completer<void>();
      final stream = StreamController<ImageStreamChunk>(
        onListen: streamStarted.complete,
      );
      when(
        () => apiService.generateImageStream(
          any(),
          focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
          minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
          focusedSelectionRect: any(named: 'focusedSelectionRect'),
        ),
      ).thenAnswer((_) => stream.stream);
      when(() => apiService.cancelGeneration(any())).thenReturn(null);

      final coordinator = ImageGenerationCoordinator(apiService: apiService);
      final command = GenerationCommand(
        runId: 1,
        params: const ImageParams(prompt: 'test'),
        batchCount: 1,
        batchSize: 1,
        prepareBatch: (_, params) async => params,
        cancellableFallback: false,
      );
      final handle = coordinator.start(command);
      final events = coordinator.execute(command, handle).toList();

      await streamStarted.future;
      coordinator.cancel(handle);
      await stream.close();

      final completedEvents = await events.timeout(const Duration(seconds: 1));
      expect(completedEvents.last, isA<GenerationCancelled>());
      verifyNever(
        () => apiService.generateImage(
          any(),
          onProgress: any(named: 'onProgress'),
          focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
          minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
          focusedSelectionRect: any(named: 'focusedSelectionRect'),
        ),
      );
    },
  );

  test(
    'cancel as an empty stream finishes prevents fallback request',
    () async {
      final apiService = _MockNAIImageGenerationApiService();
      final streamStarted = Completer<void>();
      final streamEnded = Completer<void>();
      late final ImageGenerationCoordinator coordinator;
      late final GenerationRunHandle handle;
      final stream = StreamController<ImageStreamChunk>(
        onListen: streamStarted.complete,
        onCancel: () {
          coordinator.cancel(handle);
          streamEnded.complete();
        },
      );
      when(
        () => apiService.generateImageStream(
          any(),
          focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
          minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
          focusedSelectionRect: any(named: 'focusedSelectionRect'),
        ),
      ).thenAnswer((_) => stream.stream);
      when(() => apiService.cancelGeneration(any())).thenReturn(null);

      coordinator = ImageGenerationCoordinator(apiService: apiService);
      final command = GenerationCommand(
        runId: 1,
        params: const ImageParams(prompt: 'test'),
        batchCount: 1,
        batchSize: 1,
        prepareBatch: (_, params) async => params,
        cancellableFallback: false,
      );
      handle = coordinator.start(command);
      final events = coordinator.execute(command, handle).toList();

      await streamStarted.future;
      await stream.close();
      await streamEnded.future.timeout(const Duration(seconds: 1));

      final completedEvents = await events.timeout(const Duration(seconds: 1));
      expect(completedEvents.last, isA<GenerationCancelled>());
      verifyNever(
        () => apiService.generateImage(
          any(),
          onProgress: any(named: 'onProgress'),
          focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
          minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
          focusedSelectionRect: any(named: 'focusedSelectionRect'),
        ),
      );
    },
  );

  test('multi-image stream fallback preserves vibe encodings', () async {
    final apiService = _MockNAIImageGenerationApiService();
    final images = <Uint8List>[
      Uint8List.fromList([1, 2, 3]),
      Uint8List.fromList([4, 5, 6]),
    ];
    const encodings = <int, String>{0: 'vibe-encoding'};
    when(
      () => apiService.generateImageStream(
        any(),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenAnswer(
      (_) => Stream.value(ImageStreamChunk.error('Streaming is not allowed')),
    );
    when(
      () => apiService.generateImageWithEncodingsCancellable(
        any(),
        onProgress: any(named: 'onProgress'),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenAnswer((_) async => (images, encodings));

    final coordinator = ImageGenerationCoordinator(apiService: apiService);
    final command = GenerationCommand(
      runId: 1,
      params: const ImageParams(prompt: 'test', seed: 42),
      batchCount: 1,
      batchSize: 2,
      prepareBatch: (_, params) async => params,
      materializeRandomSeed: false,
    );
    final handle = coordinator.start(command);

    final events = await coordinator.execute(command, handle).toList();

    final requestCompleted = events
        .whereType<GenerationRequestCompleted>()
        .single;
    final completed = events.whereType<GenerationCompleted>().single;
    expect(requestCompleted.images, images);
    expect(requestCompleted.vibeEncodings, encodings);
    expect(completed.images, images);
    final streamParams =
        verify(
              () => apiService.generateImageStream(
                captureAny(),
                focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
                minimumContextMegaPixels: any(
                  named: 'minimumContextMegaPixels',
                ),
                focusedSelectionRect: any(named: 'focusedSelectionRect'),
              ),
            ).captured.single
            as ImageParams;
    final fallbackParams =
        verify(
              () => apiService.generateImageWithEncodingsCancellable(
                captureAny(),
                onProgress: any(named: 'onProgress'),
                focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
                minimumContextMegaPixels: any(
                  named: 'minimumContextMegaPixels',
                ),
                focusedSelectionRect: any(named: 'focusedSelectionRect'),
              ),
            ).captured.single
            as ImageParams;
    expect(streamParams.seed, 42);
    expect(fallbackParams.seed, 42);
    expect(streamParams.nSamples, 2);
    expect(fallbackParams.nSamples, 2);
  });

  test('cancel interrupts multi-image fallback with encodings', () async {
    final apiService = _MockNAIImageGenerationApiService();
    final fallbackStarted = Completer<void>();
    final fallbackResult = Completer<(List<Uint8List>, Map<int, String>)>();
    when(
      () => apiService.generateImageStream(
        any(),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenAnswer(
      (_) => Stream.value(ImageStreamChunk.error('Streaming is not allowed')),
    );
    when(
      () => apiService.generateImageWithEncodingsCancellable(
        any(),
        onProgress: any(named: 'onProgress'),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenAnswer((_) {
      fallbackStarted.complete();
      return fallbackResult.future;
    });
    when(() => apiService.cancelGeneration(any())).thenAnswer((_) {
      fallbackResult.completeError(
        DioException(
          requestOptions: RequestOptions(path: '/generate-image'),
          type: DioExceptionType.cancel,
        ),
      );
    });

    final coordinator = ImageGenerationCoordinator(apiService: apiService);
    final command = GenerationCommand(
      runId: 1,
      params: const ImageParams(prompt: 'test'),
      batchCount: 1,
      batchSize: 2,
      prepareBatch: (_, params) async => params,
    );
    final handle = coordinator.start(command);
    final events = coordinator.execute(command, handle).toList();

    await fallbackStarted.future;
    coordinator.cancel(handle);

    final completedEvents = await events.timeout(const Duration(seconds: 1));
    expect(completedEvents.last, isA<GenerationCancelled>());
    expect(completedEvents, isNot(contains(isA<GenerationRequestCompleted>())));
    verify(() => apiService.cancelGeneration(any())).called(1);
  });

  test(
    'streaming-not-allowed fallback retries ordinary failures and succeeds',
    () async {
      final apiService = _MockNAIImageGenerationApiService();
      final delays = <Duration>[];
      var fallbackCalls = 0;
      when(
        () => apiService.generateImageStream(
          any(),
          focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
          minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
          focusedSelectionRect: any(named: 'focusedSelectionRect'),
        ),
      ).thenAnswer(
        (_) => Stream.value(ImageStreamChunk.error('Streaming is not allowed')),
      );
      when(
        () => apiService.generateImage(
          any(),
          onProgress: any(named: 'onProgress'),
          focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
          minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
          focusedSelectionRect: any(named: 'focusedSelectionRect'),
        ),
      ).thenAnswer((_) async {
        fallbackCalls++;
        if (fallbackCalls < 4) throw StateError('temporary fallback failure');
        return (
          <Uint8List>[
            Uint8List.fromList([4]),
          ],
          <int, String>{2: 'fallback-vibe'},
        );
      });

      final coordinator = ImageGenerationCoordinator(
        apiService: apiService,
        delay: (duration) async => delays.add(duration),
      );
      final command = GenerationCommand(
        runId: 1,
        params: const ImageParams(prompt: 'test'),
        batchCount: 1,
        batchSize: 1,
        prepareBatch: (_, params) async => params,
        materializeRandomSeed: false,
        cancellableFallback: false,
      );
      final handle = coordinator.start(command);

      final completed = (await coordinator.execute(command, handle).toList())
          .whereType<GenerationRequestCompleted>()
          .single;

      expect(fallbackCalls, 4);
      expect(delays, const [
        Duration(seconds: 1),
        Duration(seconds: 2),
        Duration(seconds: 4),
      ]);
      expect(completed.images.single, Uint8List.fromList([4]));
      expect(completed.vibeEncodings, {2: 'fallback-vibe'});
      verify(
        () => apiService.generateImageStream(
          any(),
          focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
          minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
          focusedSelectionRect: any(named: 'focusedSelectionRect'),
        ),
      ).called(1);
    },
  );

  test(
    'streaming-not-allowed fallback retries 429 with the same budget',
    () async {
      final apiService = _MockNAIImageGenerationApiService();
      final delays = <Duration>[];
      var fallbackCalls = 0;
      when(
        () => apiService.generateImageStream(
          any(),
          focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
          minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
          focusedSelectionRect: any(named: 'focusedSelectionRect'),
        ),
      ).thenAnswer(
        (_) => Stream.value(ImageStreamChunk.error('Streaming is not allowed')),
      );
      when(
        () => apiService.generateImage(
          any(),
          onProgress: any(named: 'onProgress'),
          focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
          minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
          focusedSelectionRect: any(named: 'focusedSelectionRect'),
        ),
      ).thenAnswer((_) async {
        fallbackCalls++;
        if (fallbackCalls < 4) {
          throw DioException(
            requestOptions: RequestOptions(path: '/generate-image'),
            response: Response<void>(
              requestOptions: RequestOptions(path: '/generate-image'),
              statusCode: 429,
            ),
          );
        }
        return (
          <Uint8List>[
            Uint8List.fromList([9]),
          ],
          <int, String>{},
        );
      });

      final coordinator = ImageGenerationCoordinator(
        apiService: apiService,
        delay: (duration) async => delays.add(duration),
      );
      final command = GenerationCommand(
        runId: 1,
        params: const ImageParams(prompt: 'test'),
        batchCount: 1,
        batchSize: 1,
        prepareBatch: (_, params) async => params,
        materializeRandomSeed: false,
        cancellableFallback: false,
      );
      final handle = coordinator.start(command);

      final events = await coordinator.execute(command, handle).toList();

      expect(events.last, isA<GenerationCompleted>());
      expect(fallbackCalls, 4);
      expect(delays, const [
        Duration(seconds: 1),
        Duration(seconds: 2),
        Duration(seconds: 4),
      ]);
      verify(
        () => apiService.generateImageStream(
          any(),
          focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
          minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
          focusedSelectionRect: any(named: 'focusedSelectionRect'),
        ),
      ).called(1);
    },
  );

  test('cancel during fallback retry delay prevents another request', () async {
    final apiService = _MockNAIImageGenerationApiService();
    final delayStarted = Completer<void>();
    final blockedDelay = Completer<void>();
    when(
      () => apiService.generateImageStream(
        any(),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenAnswer(
      (_) => Stream.value(ImageStreamChunk.error('Streaming is not allowed')),
    );
    when(
      () => apiService.generateImage(
        any(),
        onProgress: any(named: 'onProgress'),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenThrow(StateError('temporary fallback failure'));
    when(() => apiService.cancelGeneration(any())).thenReturn(null);

    final coordinator = ImageGenerationCoordinator(
      apiService: apiService,
      delay: (_) {
        delayStarted.complete();
        return blockedDelay.future;
      },
    );
    final command = GenerationCommand(
      runId: 1,
      params: const ImageParams(prompt: 'test'),
      batchCount: 1,
      batchSize: 1,
      prepareBatch: (_, params) async => params,
      materializeRandomSeed: false,
      cancellableFallback: false,
    );
    final handle = coordinator.start(command);
    final events = coordinator.execute(command, handle).toList();

    await delayStarted.future;
    coordinator.cancel(handle);

    final completedEvents = await events.timeout(const Duration(seconds: 1));
    expect(completedEvents.last, isA<GenerationCancelled>());
    verify(
      () => apiService.generateImage(
        any(),
        onProgress: any(named: 'onProgress'),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).called(1);
    verify(
      () => apiService.generateImageStream(
        any(),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).called(1);
    expect(blockedDelay.isCompleted, isFalse);
    blockedDelay.complete();
  });

  test('exhausted fallback retries fail without returning to stream', () async {
    final apiService = _MockNAIImageGenerationApiService();
    final delays = <Duration>[];
    when(
      () => apiService.generateImageStream(
        any(),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenAnswer(
      (_) => Stream.value(ImageStreamChunk.error('Streaming is not allowed')),
    );
    when(
      () => apiService.generateImage(
        any(),
        onProgress: any(named: 'onProgress'),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenThrow(StateError('persistent fallback failure'));

    final coordinator = ImageGenerationCoordinator(
      apiService: apiService,
      delay: (duration) async => delays.add(duration),
    );
    final command = GenerationCommand(
      runId: 1,
      params: const ImageParams(prompt: 'test'),
      batchCount: 1,
      batchSize: 1,
      prepareBatch: (_, params) async => params,
      materializeRandomSeed: false,
      cancellableFallback: false,
    );
    final handle = coordinator.start(command);

    final events = await coordinator.execute(command, handle).toList();

    expect(events.whereType<GenerationRequestFailed>(), hasLength(1));
    expect(events.last, isA<GenerationFailed>());
    expect(
      (events.last as GenerationFailed).error.toString(),
      contains('persistent fallback failure'),
    );
    expect(delays, const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ]);
    verify(
      () => apiService.generateImage(
        any(),
        onProgress: any(named: 'onProgress'),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).called(4);
    verify(
      () => apiService.generateImageStream(
        any(),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).called(1);
  });

  test(
    'per-image requests retain global image indexes for every slot',
    () async {
      final apiService = _MockNAIImageGenerationApiService();
      var fallbackCall = 0;
      when(
        () => apiService.generateImageStream(
          any(),
          focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
          minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
          focusedSelectionRect: any(named: 'focusedSelectionRect'),
        ),
      ).thenAnswer(
        (_) => Stream.value(ImageStreamChunk.error('Streaming is not allowed')),
      );
      when(
        () => apiService.generateImage(
          any(),
          onProgress: any(named: 'onProgress'),
          focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
          minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
          focusedSelectionRect: any(named: 'focusedSelectionRect'),
        ),
      ).thenAnswer((_) async {
        fallbackCall++;
        return (
          <Uint8List>[
            Uint8List.fromList([fallbackCall]),
          ],
          <int, String>{
            0: 'image-$fallbackCall-slot-0',
            2: 'image-$fallbackCall-slot-2',
          },
        );
      });

      final coordinator = ImageGenerationCoordinator(apiService: apiService);
      final command = GenerationCommand(
        runId: 1,
        params: const ImageParams(prompt: 'test', seed: 10),
        batchCount: 1,
        batchSize: 2,
        prepareBatch: (_, params) async => params,
        materializeRandomSeed: false,
        requestEachImage: true,
        cancellableFallback: false,
      );
      final handle = coordinator.start(command);

      final completed = (await coordinator.execute(command, handle).toList())
          .whereType<GenerationRequestCompleted>()
          .single;

      expect(completed.images, hasLength(2));
      expect(
        completed.indexedVibeEncodings
            .map(
              (entry) => '${entry.imageIndex}_${entry.slot}:${entry.encoding}',
            )
            .toList(),
        [
          '1_0:image-1-slot-0',
          '1_2:image-1-slot-2',
          '2_0:image-2-slot-0',
          '2_2:image-2-slot-2',
        ],
      );
      verify(
        () => apiService.generateImage(
          any(),
          onProgress: any(named: 'onProgress'),
          focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
          minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
          focusedSelectionRect: any(named: 'focusedSelectionRect'),
        ),
      ).called(2);
    },
  );

  test(
    'cancel stops per-image fallback without publishing partial encodings',
    () async {
      final apiService = _MockNAIImageGenerationApiService();
      final secondFallbackStarted = Completer<void>();
      final secondFallback = Completer<(List<Uint8List>, Map<int, String>)>();
      var fallbackCall = 0;
      when(
        () => apiService.generateImageStream(
          any(),
          focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
          minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
          focusedSelectionRect: any(named: 'focusedSelectionRect'),
        ),
      ).thenAnswer(
        (_) => Stream.value(ImageStreamChunk.error('Streaming is not allowed')),
      );
      when(
        () => apiService.generateImage(
          any(),
          onProgress: any(named: 'onProgress'),
          focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
          minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
          focusedSelectionRect: any(named: 'focusedSelectionRect'),
        ),
      ).thenAnswer((_) {
        fallbackCall++;
        if (fallbackCall == 1) {
          return Future.value((
            <Uint8List>[
              Uint8List.fromList([1]),
            ],
            <int, String>{0: 'first'},
          ));
        }
        secondFallbackStarted.complete();
        return secondFallback.future;
      });
      when(() => apiService.cancelGeneration(any())).thenAnswer((_) {
        secondFallback.completeError(StateError('cancelled locally'));
      });

      final coordinator = ImageGenerationCoordinator(apiService: apiService);
      final command = GenerationCommand(
        runId: 1,
        params: const ImageParams(prompt: 'test'),
        batchCount: 1,
        batchSize: 2,
        prepareBatch: (_, params) async => params,
        requestEachImage: true,
        cancellableFallback: false,
      );
      final handle = coordinator.start(command);
      final events = coordinator.execute(command, handle).toList();

      await secondFallbackStarted.future;
      coordinator.cancel(handle);
      final completedEvents = await events.timeout(const Duration(seconds: 1));

      expect(completedEvents.last, isA<GenerationCancelled>());
      expect(
        completedEvents,
        isNot(contains(isA<GenerationRequestCompleted>())),
      );
      verify(() => apiService.cancelGeneration(any())).called(1);
    },
  );

  test(
    'shared request keeps slot map semantics without image indexes',
    () async {
      final apiService = _MockNAIImageGenerationApiService();
      final images = <Uint8List>[
        Uint8List.fromList([1]),
        Uint8List.fromList([2]),
      ];
      const encodings = <int, String>{0: 'shared-0', 2: 'shared-2'};
      when(
        () => apiService.generateImageStream(
          any(),
          focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
          minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
          focusedSelectionRect: any(named: 'focusedSelectionRect'),
        ),
      ).thenAnswer(
        (_) => Stream.value(ImageStreamChunk.error('Streaming is not allowed')),
      );
      when(
        () => apiService.generateImageWithEncodingsCancellable(
          any(),
          onProgress: any(named: 'onProgress'),
          focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
          minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
          focusedSelectionRect: any(named: 'focusedSelectionRect'),
        ),
      ).thenAnswer((_) async => (images, encodings));

      final coordinator = ImageGenerationCoordinator(apiService: apiService);
      final command = GenerationCommand(
        runId: 1,
        params: const ImageParams(prompt: 'test'),
        batchCount: 1,
        batchSize: 2,
        prepareBatch: (_, params) async => params,
      );
      final handle = coordinator.start(command);

      final completed = (await coordinator.execute(command, handle).toList())
          .whereType<GenerationRequestCompleted>()
          .single;

      expect(completed.vibeEncodings, encodings);
      expect(completed.indexedVibeEncodings, isEmpty);
    },
  );
}
