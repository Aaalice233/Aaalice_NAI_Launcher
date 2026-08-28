import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_generation_api_service.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/image/image_stream_chunk.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_models.dart';
import 'package:nai_launcher/presentation/providers/generation/stream_generation_notifier.dart';

class _MockApiService extends Mock implements NAIImageGenerationApiService {}

void main() {
  setUpAll(() {
    registerFallbackValue(const ImageParams());
  });

  group('StreamGenerationState', () {
    test('copyWith can explicitly clear result, steps, and timing', () {
      final generatedImage = GeneratedImage(
        id: 'result',
        bytes: Uint8List.fromList([1, 2, 3]),
        width: 1,
        height: 1,
      );
      final state = StreamGenerationState(
        status: StreamGenerationStatus.completed,
        result: generatedImage,
        currentStep: 14,
        totalSteps: 28,
        startTime: DateTime(2025),
        endTime: DateTime(2025, 1, 1, 0, 0, 1),
      );

      final cleared = state.copyWith(
        status: StreamGenerationStatus.idle,
        clearResult: true,
        clearSteps: true,
        clearTiming: true,
      );

      expect(cleared.status, StreamGenerationStatus.idle);
      expect(cleared.result, isNull);
      expect(cleared.currentStep, isNull);
      expect(cleared.totalSteps, isNull);
      expect(cleared.startTime, isNull);
      expect(cleared.endTime, isNull);
    });
  });

  group('StreamGenerationNotifier', () {
    late _MockApiService apiService;
    late StreamController<ImageStreamChunk> streamController;
    late ProviderContainer container;

    setUp(() {
      apiService = _MockApiService();
      streamController = StreamController<ImageStreamChunk>();
      when(
        () => apiService.generateImageStream(any()),
      ).thenAnswer((_) => streamController.stream);
      when(() => apiService.cancelGeneration(any())).thenReturn(null);
      container = ProviderContainer(
        overrides: [
          naiImageGenerationApiServiceProvider.overrideWithValue(apiService),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      if (!streamController.isClosed) await streamController.close();
    });

    test(
      'projects stream steps and emits completing before completed',
      () async {
        final statuses = <StreamGenerationStatus>[];
        container.listen(
          streamGenerationNotifierProvider,
          (_, next) => statuses.add(next.status),
          fireImmediately: true,
        );

        final generation = container
            .read(streamGenerationNotifierProvider.notifier)
            .generate(const ImageParams(prompt: 'test'));
        streamController.add(
          ImageStreamChunk.progress(
            progress: 0.5,
            currentStep: 14,
            totalSteps: 28,
            previewImage: Uint8List.fromList([1, 2, 3]),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        final streaming = container.read(streamGenerationNotifierProvider);
        expect(streaming.currentStep, 14);
        expect(streaming.totalSteps, 28);

        streamController.add(
          ImageStreamChunk.complete(Uint8List.fromList([4, 5, 6])),
        );
        await streamController.close();
        await generation;

        expect(statuses, contains(StreamGenerationStatus.completing));
        expect(
          container.read(streamGenerationNotifierProvider).status,
          StreamGenerationStatus.completed,
        );
      },
    );

    test('clearResult clears steps and elapsed-time fields', () async {
      final generation = container
          .read(streamGenerationNotifierProvider.notifier)
          .generate(const ImageParams(prompt: 'test'));
      streamController.add(
        ImageStreamChunk.progress(
          progress: 0.5,
          currentStep: 7,
          totalSteps: 14,
          previewImage: Uint8List.fromList([1]),
        ),
      );
      streamController.add(ImageStreamChunk.complete(Uint8List.fromList([2])));
      await streamController.close();
      await generation;

      container.read(streamGenerationNotifierProvider.notifier).clearResult();
      final cleared = container.read(streamGenerationNotifierProvider);

      expect(cleared.result, isNull);
      expect(cleared.currentStep, isNull);
      expect(cleared.totalSteps, isNull);
      expect(cleared.startTime, isNull);
      expect(cleared.endTime, isNull);
      expect(cleared.durationMs, isNull);
    });

    test(
      'disposing the provider container cancels the active service',
      () async {
        final generation = container
            .read(streamGenerationNotifierProvider.notifier)
            .generate(const ImageParams(prompt: 'test'));
        await Future<void>.delayed(Duration.zero);

        container.dispose();
        await streamController.close();
        await generation;

        verify(() => apiService.cancelGeneration(any())).called(1);
      },
    );
  });
}
