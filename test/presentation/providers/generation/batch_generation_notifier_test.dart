import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_generation_api_service.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/image/image_stream_chunk.dart';
import 'package:nai_launcher/presentation/providers/generation/batch_generation_notifier.dart';

class MockNAIImageGenerationApiService extends Mock
    implements NAIImageGenerationApiService {}

void main() {
  setUpAll(() {
    registerFallbackValue(const ImageParams());
  });

  group('BatchGenerationNotifier', () {
    late MockNAIImageGenerationApiService mockApiService;
    late ProviderContainer container;

    setUp(() {
      mockApiService = MockNAIImageGenerationApiService();
      container = ProviderContainer(
        overrides: [
          naiImageGenerationApiServiceProvider.overrideWithValue(mockApiService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      reset(mockApiService);
    });

    BatchGenerationNotifier createNotifier() {
      return container.read(batchGenerationNotifierProvider.notifier);
    }

    group('build', () {
      test('should return initial state', () {
        final notifier = createNotifier();

        expect(notifier.state.status, BatchGenerationStatus.idle);
        expect(notifier.state.items, isEmpty);
        expect(notifier.state.overallProgress, 0.0);
        expect(notifier.state.completedCount, 0);
        expect(notifier.state.failedCount, 0);
      });
    });

    group('generateBatch', () {
      test('should generate single image successfully', () async {
        final notifier = createNotifier();
        final imageBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        const params = ImageParams(
          prompt: 'test prompt',
          width: 832,
          height: 1216,
        );

        when(() => mockApiService.generateImageStream(any()))
            .thenAnswer((_) => Stream.value(
                  ImageStreamChunk.complete(imageBytes),
                ),);

        await notifier.generateBatch(params, count: 1);

        expect(notifier.state.status, BatchGenerationStatus.completed);
        expect(notifier.state.items.length, 1);
        expect(notifier.state.items.first.isCompleted, isTrue);
        expect(notifier.state.items.first.image, equals(imageBytes));
        expect(notifier.state.completedCount, 1);
        expect(notifier.state.overallProgress, 1.0);
      });

      test('should generate multiple images', () async {
        final notifier = createNotifier();
        final imageBytes1 = Uint8List.fromList([1, 2, 3]);
        final imageBytes2 = Uint8List.fromList([4, 5, 6]);
        const params = ImageParams(
          prompt: 'test prompt',
          seed: 42,
        );

        var callCount = 0;
        when(() => mockApiService.generateImageStream(any()))
            .thenAnswer((_) {
          callCount++;
          if (callCount == 1) {
            return Stream.value(ImageStreamChunk.complete(imageBytes1));
          }
          return Stream.value(ImageStreamChunk.complete(imageBytes2));
        });

        await notifier.generateBatch(params, count: 2);

        expect(notifier.state.status, BatchGenerationStatus.completed);
        expect(notifier.state.items.length, 2);
        expect(notifier.state.completedCount, 2);
        expect(notifier.state.items[0].isCompleted, isTrue);
        expect(notifier.state.items[1].isCompleted, isTrue);
      });

      test('should set error status when count is 0 or negative', () async {
        final notifier = createNotifier();
        const params = ImageParams(prompt: 'test prompt');

        await notifier.generateBatch(params, count: 0);

        expect(notifier.state.status, BatchGenerationStatus.error);
        expect(notifier.state.errorMessage, '生成数量必须大于0');
      });

      test('should handle generation errors', () async {
        final notifier = createNotifier();
        const params = ImageParams(prompt: 'test prompt');

        when(() => mockApiService.generateImageStream(any()))
            .thenAnswer((_) => Stream.error(Exception('Generation failed')));

        await notifier.generateBatch(params, count: 1);

        expect(notifier.state.items.first.isFailed, isTrue);
        expect(notifier.state.items.first.error, isNotNull);
      });

      test('should handle error chunks from stream', () async {
        final notifier = createNotifier();
        const params = ImageParams(prompt: 'test prompt');

        when(() => mockApiService.generateImageStream(any()))
            .thenAnswer((_) => Stream.value(
                  ImageStreamChunk.error('API error'),
                ),);

        await notifier.generateBatch(params, count: 1);

        expect(notifier.state.items.first.isFailed, isTrue);
        expect(notifier.state.failedCount, 1);
      });

      test('should update progress during generation', () async {
        final notifier = createNotifier();
        final previewBytes = Uint8List.fromList([1, 2, 3]);
        final finalBytes = Uint8List.fromList([4, 5, 6]);
        const params = ImageParams(prompt: 'test prompt');

        when(() => mockApiService.generateImageStream(any()))
            .thenAnswer((_) => Stream.fromIterable([
                  ImageStreamChunk.progress(
                    progress: 0.3,
                    previewImage: previewBytes,
                  ),
                  ImageStreamChunk.progress(
                    progress: 0.7,
                    previewImage: previewBytes,
                  ),
                  ImageStreamChunk.complete(finalBytes),
                ]),);

        await notifier.generateBatch(params, count: 1);

        expect(notifier.state.overallProgress, 1.0);
        expect(notifier.state.streamPreview, isNull); // cleared after completion
      });

      test('should use different seeds for each image when seed is specified',
          () async {
        final notifier = createNotifier();
        final imageBytes = Uint8List.fromList([1, 2, 3]);
        const params = ImageParams(
          prompt: 'test prompt',
          seed: 100,
        );

        final capturedSeeds = <int>[];
        when(() => mockApiService.generateImageStream(any()))
            .thenAnswer((invocation) {
          final p = invocation.positionalArguments[0] as ImageParams;
          capturedSeeds.add(p.seed);
          return Stream.value(ImageStreamChunk.complete(imageBytes));
        });

        await notifier.generateBatch(params, count: 3);

        // Each image should have a different seed: 100, 101, 102
        expect(capturedSeeds, [100, 101, 102]);
      });

      test('should keep seed as -1 for all images when random seed is used',
          () async {
        final notifier = createNotifier();
        final imageBytes = Uint8List.fromList([1, 2, 3]);
        const params = ImageParams(
          prompt: 'test prompt',
          seed: -1,
        );

        final capturedSeeds = <int>[];
        when(() => mockApiService.generateImageStream(any()))
            .thenAnswer((invocation) {
          final p = invocation.positionalArguments[0] as ImageParams;
          capturedSeeds.add(p.seed);
          return Stream.value(ImageStreamChunk.complete(imageBytes));
        });

        await notifier.generateBatch(params, count: 3);

        // All should use -1 (random seed)
        expect(capturedSeeds, [-1, -1, -1]);
      });

      test('should handle concurrent generation', () async {
        final notifier = createNotifier();
        final imageBytes = Uint8List.fromList([1, 2, 3]);
        const params = ImageParams(prompt: 'test prompt');

        when(() => mockApiService.generateImageStream(any()))
            .thenAnswer((_) => Stream.value(
                  ImageStreamChunk.complete(imageBytes),
                ),);

        await notifier.generateBatch(params, count: 4, concurrency: 2);

        expect(notifier.state.status, BatchGenerationStatus.completed);
        expect(notifier.state.items.length, 4);
        expect(notifier.state.completedCount, 4);
      });

      test('should set error status when all generations fail', () async {
        final notifier = createNotifier();
        const params = ImageParams(prompt: 'test prompt');

        when(() => mockApiService.generateImageStream(any()))
            .thenAnswer((_) => Stream.value(
                  ImageStreamChunk.error('API error'),
                ),);

        await notifier.generateBatch(params, count: 2);

        expect(notifier.state.status, BatchGenerationStatus.error);
        expect(notifier.state.errorMessage, '所有生成任务失败');
        expect(notifier.state.failedCount, 2);
      });

      test('should complete successfully when some generations fail',
          () async {
        final notifier = createNotifier();
        final imageBytes = Uint8List.fromList([1, 2, 3]);
        const params = ImageParams(prompt: 'test prompt');

        var callCount = 0;
        when(() => mockApiService.generateImageStream(any()))
            .thenAnswer((_) {
          callCount++;
          if (callCount == 1) {
            return Stream.value(ImageStreamChunk.error('API error'));
          }
          return Stream.value(ImageStreamChunk.complete(imageBytes));
        });

        await notifier.generateBatch(params, count: 2);

        expect(notifier.state.status, BatchGenerationStatus.completed);
        expect(notifier.state.completedCount, 1);
        expect(notifier.state.failedCount, 1);
      });

      test('should store batch width and height from params', () async {
        final notifier = createNotifier();
        final imageBytes = Uint8List.fromList([1, 2, 3]);
        const params = ImageParams(
          prompt: 'test prompt',
          width: 1024,
          height: 1024,
        );

        when(() => mockApiService.generateImageStream(any()))
            .thenAnswer((_) => Stream.value(
                  ImageStreamChunk.complete(imageBytes),
                ),);

        await notifier.generateBatch(params, count: 1);

        expect(notifier.state.batchWidth, 1024);
        expect(notifier.state.batchHeight, 1024);
      });
    });

    group('cancel', () {
      test('should cancel batch generation', () async {
        final notifier = createNotifier();
        const params = ImageParams(prompt: 'test prompt');

        final completer = Completer<void>();

        when(() => mockApiService.generateImageStream(any()))
            .thenAnswer((_) async* {
          await completer.future;
          yield ImageStreamChunk.complete(Uint8List.fromList([1, 2, 3]));
        });

        when(() => mockApiService.cancelGeneration()).thenReturn(null);

        // Start generation
        final future = notifier.generateBatch(params, count: 1);

        // Cancel after a short delay
        Future.delayed(const Duration(milliseconds: 10), () {
          notifier.cancel();
          completer.complete();
        });

        await future;

        expect(notifier.state.status, BatchGenerationStatus.cancelled);
        verify(() => mockApiService.cancelGeneration()).called(1);
      });

      test('should clear stream preview on cancel', () async {
        final notifier = createNotifier();
        const params = ImageParams(prompt: 'test prompt');
        final previewBytes = Uint8List.fromList([1, 2, 3]);

        final completer = Completer<void>();

        when(() => mockApiService.generateImageStream(any()))
            .thenAnswer((_) async* {
          yield ImageStreamChunk.progress(
            progress: 0.5,
            previewImage: previewBytes,
          );
          await completer.future;
          yield ImageStreamChunk.complete(Uint8List.fromList([4, 5, 6]));
        });

        when(() => mockApiService.cancelGeneration()).thenReturn(null);

        final future = notifier.generateBatch(params, count: 1);

        // Wait a bit for progress to be emitted
        await Future.delayed(const Duration(milliseconds: 20));
        expect(notifier.state.streamPreview, isNotNull);

        notifier.cancel();
        completer.complete();
        await future;

        expect(notifier.state.streamPreview, isNull);
      });
    });

    group('reset', () {
      test('should reset state to initial', () async {
        final notifier = createNotifier();
        final imageBytes = Uint8List.fromList([1, 2, 3]);
        const params = ImageParams(prompt: 'test prompt');

        when(() => mockApiService.generateImageStream(any()))
            .thenAnswer((_) => Stream.value(
                  ImageStreamChunk.complete(imageBytes),
                ),);

        await notifier.generateBatch(params, count: 1);
        expect(notifier.state.status, BatchGenerationStatus.completed);

        notifier.reset();

        expect(notifier.state.status, BatchGenerationStatus.idle);
        expect(notifier.state.items, isEmpty);
        expect(notifier.state.overallProgress, 0.0);
        expect(notifier.state.completedCount, 0);
        expect(notifier.state.failedCount, 0);
        expect(notifier.state.errorMessage, isNull);
      });
    });

    group('clearError', () {
      test('should clear error status', () async {
        final notifier = createNotifier();
        const params = ImageParams(prompt: 'test prompt');

        when(() => mockApiService.generateImageStream(any()))
            .thenAnswer((_) => Stream.value(
                  ImageStreamChunk.error('API error'),
                ),);

        await notifier.generateBatch(params, count: 1);
        expect(notifier.state.status, BatchGenerationStatus.error);

        notifier.clearError();

        expect(notifier.state.status, BatchGenerationStatus.idle);
        expect(notifier.state.errorMessage, isNull);
      });

      test('should not change status when not in error state', () async {
        final notifier = createNotifier();

        notifier.clearError();

        expect(notifier.state.status, BatchGenerationStatus.idle);
      });
    });

    group('retryFailed', () {
      test('should retry failed items', () async {
        final notifier = createNotifier();
        final imageBytes = Uint8List.fromList([1, 2, 3]);
        const params = ImageParams(prompt: 'test prompt');

        var callCount = 0;
        when(() => mockApiService.generateImageStream(any()))
            .thenAnswer((_) {
          callCount++;
          if (callCount == 1) {
            return Stream.value(ImageStreamChunk.error('API error'));
          }
          return Stream.value(ImageStreamChunk.complete(imageBytes));
        });

        // First attempt: one fails
        await notifier.generateBatch(params, count: 1);
        expect(notifier.state.failedCount, 1);
        expect(notifier.state.items.first.isFailed, isTrue);

        // Retry
        await notifier.retryFailed(params);

        expect(notifier.state.status, BatchGenerationStatus.completed);
        expect(notifier.state.items.first.isCompleted, isTrue);
        expect(notifier.state.completedCount, 1);
        expect(notifier.state.failedCount, 0);
      });

      test('should do nothing when no failed items', () async {
        final notifier = createNotifier();
        final imageBytes = Uint8List.fromList([1, 2, 3]);
        const params = ImageParams(prompt: 'test prompt');

        when(() => mockApiService.generateImageStream(any()))
            .thenAnswer((_) => Stream.value(
                  ImageStreamChunk.complete(imageBytes),
                ),);

        await notifier.generateBatch(params, count: 1);
        expect(notifier.state.status, BatchGenerationStatus.completed);

        // Should not change anything
        await notifier.retryFailed(params);

        expect(notifier.state.status, BatchGenerationStatus.completed);
      });
    });

    group('getSuccessfulImages', () {
      test('should return successful generated images', () async {
        final notifier = createNotifier();
        final imageBytes = Uint8List.fromList([1, 2, 3]);
        const params = ImageParams(
          prompt: 'test prompt',
          width: 512,
          height: 512,
        );

        when(() => mockApiService.generateImageStream(any()))
            .thenAnswer((_) => Stream.value(
                  ImageStreamChunk.complete(imageBytes),
                ),);

        await notifier.generateBatch(params, count: 1);

        final successfulImages = notifier.getSuccessfulImages();

        expect(successfulImages.length, 1);
        expect(successfulImages.first.bytes, equals(imageBytes));
        expect(successfulImages.first.width, 512);
        expect(successfulImages.first.height, 512);
      });
    });

    group('getStatistics', () {
      test('should return correct statistics', () async {
        final notifier = createNotifier();
        final imageBytes = Uint8List.fromList([1, 2, 3]);
        const params = ImageParams(prompt: 'test prompt');

        when(() => mockApiService.generateImageStream(any()))
            .thenAnswer((_) => Stream.value(
                  ImageStreamChunk.complete(imageBytes),
                ),);

        await notifier.generateBatch(params, count: 3);

        final stats = notifier.getStatistics();

        expect(stats.total, 3);
        expect(stats.completed, 3);
        expect(stats.failed, 0);
        expect(stats.successRate, 1.0);
        expect(stats.isAllSuccessful, isTrue);
      });

      test('should calculate average duration', () async {
        final notifier = createNotifier();
        final imageBytes = Uint8List.fromList([1, 2, 3]);
        const params = ImageParams(prompt: 'test prompt');

        when(() => mockApiService.generateImageStream(any()))
            .thenAnswer((_) => Stream.value(
                  ImageStreamChunk.complete(imageBytes),
                ),);

        await notifier.generateBatch(params, count: 2);

        final stats = notifier.getStatistics();

        expect(stats.averageDurationMs, isNotNull);
        expect(stats.averageDurationMs, greaterThan(0));
      });
    });
  });

  group('BatchGenerationState', () {
    test('should create default state', () {
      const state = BatchGenerationState();

      expect(state.status, BatchGenerationStatus.idle);
      expect(state.items, isEmpty);
      expect(state.overallProgress, 0.0);
      expect(state.completedCount, 0);
      expect(state.failedCount, 0);
    });

    test('should correctly identify isGenerating', () {
      const generatingState = BatchGenerationState(
        status: BatchGenerationStatus.generating,
      );
      const idleState = BatchGenerationState(
        status: BatchGenerationStatus.idle,
      );

      expect(generatingState.isGenerating, isTrue);
      expect(idleState.isGenerating, isFalse);
    });

    test('should correctly identify isIdle', () {
      const idleState = BatchGenerationState(
        status: BatchGenerationStatus.idle,
      );
      const generatingState = BatchGenerationState(
        status: BatchGenerationStatus.generating,
      );

      expect(idleState.isIdle, isTrue);
      expect(generatingState.isIdle, isFalse);
    });

    test('should correctly identify isAllCompleted', () {
      const state = BatchGenerationState(
        items: [
          BatchGenerationItem(id: '1', index: 0, isCompleted: true),
          BatchGenerationItem(id: '2', index: 1, isCompleted: true),
        ],
        completedCount: 2,
        failedCount: 0,
      );

      expect(state.isAllCompleted, isTrue);
      expect(state.totalCount, 2);
    });

    test('should return successful images', () {
      final imageBytes = Uint8List.fromList([1, 2, 3]);
      final state = BatchGenerationState(
        items: [
          BatchGenerationItem(
            id: '1',
            index: 0,
            isCompleted: true,
            image: imageBytes,
          ),
          const BatchGenerationItem(
            id: '2',
            index: 1,
            isCompleted: false,
          ),
        ],
        batchWidth: 512,
        batchHeight: 512,
      );

      expect(state.successfulImages.length, 1);
      expect(state.successfulImages.first, equals(imageBytes));
    });

    test('should convert items to GeneratedImage list', () {
      final imageBytes = Uint8List.fromList([1, 2, 3]);
      final state = BatchGenerationState(
        items: [
          BatchGenerationItem(
            id: '1',
            index: 0,
            isCompleted: true,
            image: imageBytes,
          ),
        ],
        batchWidth: 512,
        batchHeight: 768,
      );

      expect(state.generatedImages.length, 1);
      expect(state.generatedImages.first.bytes, equals(imageBytes));
      expect(state.generatedImages.first.width, 512);
      expect(state.generatedImages.first.height, 768);
    });

    test('should use default dimensions when batch dimensions are null', () {
      final imageBytes = Uint8List.fromList([1, 2, 3]);
      final state = BatchGenerationState(
        items: [
          BatchGenerationItem(
            id: '1',
            index: 0,
            isCompleted: true,
            image: imageBytes,
          ),
        ],
      );

      expect(state.generatedImages.first.width, 832);
      expect(state.generatedImages.first.height, 1216);
    });

    test('should clear stream preview when clearStreamPreview is true', () {
      final state = BatchGenerationState(
        streamPreview: Uint8List.fromList([1, 2, 3]),
      );

      final newState = state.copyWith(clearStreamPreview: true);

      expect(newState.streamPreview, isNull);
    });
  });

  group('BatchGenerationItem', () {
    test('should create default item', () {
      const item = BatchGenerationItem(id: '1', index: 0);

      expect(item.id, '1');
      expect(item.index, 0);
      expect(item.isCompleted, isFalse);
      expect(item.progress, 0.0);
      expect(item.error, isNull);
    });

    test('should create completed item', () {
      final imageBytes = Uint8List.fromList([1, 2, 3]);
      final item = BatchGenerationItem(
        id: '1',
        index: 0,
        isCompleted: true,
        image: imageBytes,
        progress: 1.0,
        startTime: DateTime.now(),
        endTime: DateTime.now(),
      );

      expect(item.isCompleted, isTrue);
      expect(item.image, equals(imageBytes));
      expect(item.progress, 1.0);
    });

    test('should correctly identify isGenerating', () {
      final generatingItem = BatchGenerationItem(
        id: '1',
        index: 0,
        startTime: DateTime.now(),
      );
      const completedItem = BatchGenerationItem(
        id: '2',
        index: 1,
        isCompleted: true,
      );

      expect(generatingItem.isGenerating, isTrue);
      expect(completedItem.isGenerating, isFalse);
    });

    test('should correctly identify isFailed', () {
      const failedItem = BatchGenerationItem(
        id: '1',
        index: 0,
        error: 'Failed',
      );
      const successItem = BatchGenerationItem(
        id: '2',
        index: 1,
        isCompleted: true,
      );

      expect(failedItem.isFailed, isTrue);
      expect(successItem.isFailed, isFalse);
    });

    test('should calculate duration', () {
      final startTime = DateTime.now().subtract(const Duration(seconds: 2));
      final item = BatchGenerationItem(
        id: '1',
        index: 0,
        startTime: startTime,
        endTime: DateTime.now(),
      );

      expect(item.durationMs, isNotNull);
      expect(item.durationMs, greaterThan(1000));
    });

    test('should return null duration when startTime is null', () {
      const item = BatchGenerationItem(id: '1', index: 0);

      expect(item.durationMs, isNull);
    });

    test('should use current time for ongoing generation duration', () {
      final startTime = DateTime.now().subtract(const Duration(seconds: 1));
      final item = BatchGenerationItem(
        id: '1',
        index: 0,
        startTime: startTime,
      );

      expect(item.durationMs, isNotNull);
      expect(item.durationMs, greaterThan(0));
    });

    test('should copy with new values', () {
      const item = BatchGenerationItem(id: '1', index: 0);

      final copied = item.copyWith(
        isCompleted: true,
        progress: 1.0,
      );

      expect(copied.id, item.id);
      expect(copied.index, item.index);
      expect(copied.isCompleted, isTrue);
      expect(copied.progress, 1.0);
    });
  });

  group('BatchStatistics', () {
    test('should create statistics correctly', () {
      const stats = BatchStatistics(
        total: 10,
        completed: 8,
        failed: 1,
        overallProgress: 0.9,
        averageDurationMs: 5000,
      );

      expect(stats.total, 10);
      expect(stats.completed, 8);
      expect(stats.failed, 1);
      expect(stats.overallProgress, 0.9);
      expect(stats.averageDurationMs, 5000);
    });

    test('should calculate success rate correctly', () {
      const stats = BatchStatistics(
        total: 10,
        completed: 7,
        failed: 3,
        overallProgress: 1.0,
      );

      expect(stats.successRate, 0.7);
      expect(stats.failureRate, 0.3);
    });

    test('should return 0.0 for rates when total is 0', () {
      const stats = BatchStatistics(
        total: 0,
        completed: 0,
        failed: 0,
        overallProgress: 0.0,
      );

      expect(stats.successRate, 0.0);
      expect(stats.failureRate, 0.0);
    });

    test('should identify all successful', () {
      const allSuccess = BatchStatistics(
        total: 5,
        completed: 5,
        failed: 0,
        overallProgress: 1.0,
      );
      const someFailed = BatchStatistics(
        total: 5,
        completed: 4,
        failed: 1,
        overallProgress: 1.0,
      );

      expect(allSuccess.isAllSuccessful, isTrue);
      expect(someFailed.isAllSuccessful, isFalse);
    });

    test('should identify all done', () {
      const allDone = BatchStatistics(
        total: 5,
        completed: 3,
        failed: 2,
        overallProgress: 1.0,
      );
      const notDone = BatchStatistics(
        total: 5,
        completed: 3,
        failed: 0,
        overallProgress: 0.6,
      );

      expect(allDone.isAllDone, isTrue);
      expect(notDone.isAllDone, isFalse);
    });
  });

  group('BatchGenerationStatus', () {
    test('should have all expected statuses', () {
      expect(BatchGenerationStatus.values, [
        BatchGenerationStatus.idle,
        BatchGenerationStatus.generating,
        BatchGenerationStatus.completed,
        BatchGenerationStatus.error,
        BatchGenerationStatus.cancelled,
      ]);
    });
  });
}
