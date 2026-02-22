import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_generation_api_service.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/image/image_stream_chunk.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_models.dart';
import 'package:nai_launcher/presentation/providers/generation/image_generation_service.dart';

class MockNAIImageGenerationApiService extends Mock
    implements NAIImageGenerationApiService {}

class FakeImageParams extends Fake implements ImageParams {}

void main() {
  setUpAll(() {
    registerFallbackValue(const ImageParams());
    registerFallbackValue(FakeImageParams());
  });

  group('ImageGenerationService', () {
    late MockNAIImageGenerationApiService mockApiService;
    late ImageGenerationService service;

    setUp(() {
      mockApiService = MockNAIImageGenerationApiService();
      service = ImageGenerationService(apiService: mockApiService);
    });

    tearDown(() {
      reset(mockApiService);
    });

    group('generateSingle', () {
      test('should return successful result with generated image', () async {
        const params = ImageParams(
          prompt: 'test prompt',
          width: 832,
          height: 1216,
        );
        final imageBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

        when(() => mockApiService.generateImageStream(any()))
            .thenAnswer((_) => Stream.value(
                  ImageStreamChunk.complete(imageBytes),
                ),);

        final result = await service.generateSingle(params);

        expect(result.isSuccess, isTrue);
        expect(result.images.length, 1);
        expect(result.images.first.bytes, imageBytes);
        expect(result.images.first.width, 832);
        expect(result.images.first.height, 1216);
        expect(result.isCancelled, isFalse);
        expect(result.error, isNull);
      });

      test('should return cancelled result when cancelled', () async {
        const params = ImageParams(prompt: 'test prompt');
        final imageBytes = Uint8List.fromList([1, 2, 3]);

        when(() => mockApiService.generateImageStream(any()))
            .thenAnswer((_) => Stream.fromIterable([
                  ImageStreamChunk.progress(progress: 0.5),
                  ImageStreamChunk.complete(imageBytes),
                ]),);

        when(() => mockApiService.cancelGeneration()).thenReturn(null);

        // Start generation
        final future = service.generateSingle(params);

        // Cancel immediately
        service.cancel();

        final result = await future;

        expect(result.isCancelled, isTrue);
        expect(result.images, isEmpty);
        verify(() => mockApiService.cancelGeneration()).called(1);
      });

      test('should return error result when stream throws error', () async {
        const params = ImageParams(prompt: 'test prompt');

        when(() => mockApiService.generateImageStream(any()))
            .thenAnswer((_) => Stream.error(Exception('Stream error')));

        final result = await service.generateSingle(params);

        expect(result.isSuccess, isFalse);
        expect(result.error, isNotNull);
        expect(result.images, isEmpty);
      });

      test('should return error result when stream emits error chunk', () async {
        const params = ImageParams(prompt: 'test prompt');

        when(() => mockApiService.generateImageStream(any()))
            .thenAnswer((_) => Stream.value(
                  ImageStreamChunk.error('API error'),
                ),);

        final result = await service.generateSingle(params);

        expect(result.isSuccess, isFalse);
        expect(result.error, 'API error');
      });

      test('should fallback to non-stream when streaming not allowed', () async {
        const params = ImageParams(
          prompt: 'test prompt',
          width: 512,
          height: 512,
        );
        final imageBytes = Uint8List.fromList([1, 2, 3]);

        when(() => mockApiService.generateImageStream(any()))
            .thenAnswer((_) => Stream.value(
                  ImageStreamChunk.error('Streaming is not allowed for this'),
                ),);

        when(() => mockApiService.generateImage(any(), onProgress: any(named: 'onProgress')))
            .thenAnswer((_) async => ([imageBytes], <int, String>{}));

        final result = await service.generateSingle(params);

        expect(result.isSuccess, isTrue);
        expect(result.images.length, 1);
        verify(() => mockApiService.generateImage(any(), onProgress: any(named: 'onProgress')))
            .called(1);
      });

      test('should call progress callback with preview images', () async {
        const params = ImageParams(prompt: 'test prompt');
        final previewBytes = Uint8List.fromList([1, 2, 3]);
        final finalBytes = Uint8List.fromList([4, 5, 6]);

        final progressCalls = <Map<String, dynamic>>[];

        when(() => mockApiService.generateImageStream(any()))
            .thenAnswer((_) => Stream.fromIterable([
                  ImageStreamChunk.progress(
                    progress: 0.3,
                    previewImage: previewBytes,
                  ),
                  ImageStreamChunk.progress(
                    progress: 0.6,
                    previewImage: previewBytes,
                  ),
                  ImageStreamChunk.complete(finalBytes),
                ]),);

        await service.generateSingle(
          params,
          onProgress: (current, total, progress, {previewImage}) {
            progressCalls.add({
              'current': current,
              'total': total,
              'progress': progress,
              'hasPreview': previewImage != null,
            });
          },
        );

        expect(progressCalls.length, 2);
        expect(progressCalls[0]['progress'], closeTo(0.3, 0.01));
        expect(progressCalls[0]['hasPreview'], isTrue);
        expect(progressCalls[1]['progress'], closeTo(0.6, 0.01));
      });

      test('should force nSamples to 1 regardless of input', () async {
        const params = ImageParams(
          prompt: 'test prompt',
          nSamples: 5, // Should be overridden to 1
        );
        final imageBytes = Uint8List.fromList([1, 2, 3]);

        when(() => mockApiService.generateImageStream(any()))
            .thenAnswer((_) => Stream.value(
                  ImageStreamChunk.complete(imageBytes),
                ),);

        await service.generateSingle(params);

        final capturedParams =
            verify(() => mockApiService.generateImageStream(captureAny()))
                .captured
                .single as ImageParams;
        expect(capturedParams.nSamples, 1);
      });
    });

    group('generateBatch', () {
      test('should delegate to generateSingle when batchCount=1 and batchSize=1',
          () async {
        const params = ImageParams(prompt: 'test prompt');
        final imageBytes = Uint8List.fromList([1, 2, 3]);

        when(() => mockApiService.generateImageStream(any()))
            .thenAnswer((_) => Stream.value(
                  ImageStreamChunk.complete(imageBytes),
                ),);

        final result = await service.generateBatch(
          params,
          batchCount: 1,
          batchSize: 1,
        );

        expect(result.isSuccess, isTrue);
        expect(result.images.length, 1);
      });

      test('should generate multiple images in batch', () async {
        const params = ImageParams(
          prompt: 'test prompt',
          seed: 42,
        );
        final imageBytes1 = Uint8List.fromList([1, 2, 3]);
        final imageBytes2 = Uint8List.fromList([4, 5, 6]);

        when(() => mockApiService.generateImageStream(any()))
            .thenAnswer((invocation) {
          final capturedParams =
              invocation.positionalArguments[0] as ImageParams;
          // Return different bytes based on seed
          if (capturedParams.seed == 42) {
            return Stream.value(ImageStreamChunk.complete(imageBytes1));
          } else {
            return Stream.value(ImageStreamChunk.complete(imageBytes2));
          }
        });

        final result = await service.generateBatch(
          params,
          batchCount: 1,
          batchSize: 2,
        );

        expect(result.images.length, 2);
      });

      test('should call onBatchStart and onBatchComplete callbacks', () async {
        const params = ImageParams(prompt: 'test prompt');
        final imageBytes = Uint8List.fromList([1, 2, 3]);

        final batchStartCalls = <List<int>>[];
        final batchCompleteCalls = <int>[];

        when(() => mockApiService.generateImageStream(any()))
            .thenAnswer((_) => Stream.value(
                  ImageStreamChunk.complete(imageBytes),
                ),);

        await service.generateBatch(
          params,
          batchCount: 2,
          batchSize: 1,
          onBatchStart: (batchIndex, currentImage, totalImages) {
            batchStartCalls.add([batchIndex, currentImage, totalImages]);
          },
          onBatchComplete: (batchImages) {
            batchCompleteCalls.add(batchImages.length);
          },
        );

        expect(batchStartCalls.length, 2);
        expect(batchStartCalls[0], [0, 1, 2]);
        expect(batchStartCalls[1], [1, 2, 2]);
        expect(batchCompleteCalls.length, 2);
        expect(batchCompleteCalls[0], 1);
        expect(batchCompleteCalls[1], 1);
      });

      test('should handle batch cancellation', () async {
        const params = ImageParams(prompt: 'test prompt');
        final imageBytes = Uint8List.fromList([1, 2, 3]);

        final completer = Completer<void>();

        when(() => mockApiService.generateImageStream(any()))
            .thenAnswer((_) async* {
          await completer.future;
          yield ImageStreamChunk.complete(imageBytes);
        });

        when(() => mockApiService.cancelGeneration()).thenReturn(null);

        final future = service.generateBatch(
          params,
          batchCount: 2,
          batchSize: 1,
        );

        // Cancel after a short delay
        Future.delayed(const Duration(milliseconds: 50), () {
          service.cancel();
          completer.complete();
        });

        final result = await future;

        expect(result.isCancelled, isTrue);
      });

      test('should continue on batch error', () async {
        const params = ImageParams(
          prompt: 'test prompt',
          seed: 123,
        );
        final imageBytes = Uint8List.fromList([1, 2, 3]);

        var callCount = 0;
        when(() => mockApiService.generateImageStream(any()))
            .thenAnswer((_) {
          callCount++;
          if (callCount == 1) {
            return Stream.error(Exception('Batch error'));
          }
          return Stream.value(ImageStreamChunk.complete(imageBytes));
        });

        final result = await service.generateBatch(
          params,
          batchCount: 2,
          batchSize: 1,
        );

        // Should complete but with potentially fewer images
        expect(result.isCancelled, isFalse);
      });

      test('should increment seed for each batch when seed is not -1', () async {
        const params = ImageParams(
          prompt: 'test prompt',
          seed: 100,
          nSamples: 2,
        );
        final imageBytes = Uint8List.fromList([1, 2, 3]);

        final capturedSeeds = <int>[];

        when(() => mockApiService.generateImageStream(any()))
            .thenAnswer((invocation) {
          final capturedParams =
              invocation.positionalArguments[0] as ImageParams;
          capturedSeeds.add(capturedParams.seed);
          return Stream.value(ImageStreamChunk.complete(imageBytes));
        });

        await service.generateBatch(
          params,
          batchCount: 2,
          batchSize: 2,
        );

        // Seeds should increment: batch 0 uses 100, batch 1 uses 101
        expect(capturedSeeds.contains(100), isTrue);
        expect(capturedSeeds.contains(101), isTrue);
      });

      test('should keep seed as -1 when random seed is requested', () async {
        const params = ImageParams(
          prompt: 'test prompt',
          seed: -1,
        );
        final imageBytes = Uint8List.fromList([1, 2, 3]);

        when(() => mockApiService.generateImageStream(any()))
            .thenAnswer((_) => Stream.value(
                  ImageStreamChunk.complete(imageBytes),
                ),);

        await service.generateBatch(
          params,
          batchCount: 2,
          batchSize: 1,
        );

        final capturedParams =
            verify(() => mockApiService.generateImageStream(captureAny()))
                .captured;

        for (final p in capturedParams) {
          expect((p as ImageParams).seed, -1);
        }
      });
    });

    group('cancel and resetCancellation', () {
      test('should set isCancelled to true when cancel is called', () {
        expect(service.isCancelled, isFalse);

        when(() => mockApiService.cancelGeneration()).thenReturn(null);

        service.cancel();

        expect(service.isCancelled, isTrue);
        verify(() => mockApiService.cancelGeneration()).called(1);
      });

      test('should reset cancellation state', () {
        when(() => mockApiService.cancelGeneration()).thenReturn(null);

        service.cancel();
        expect(service.isCancelled, isTrue);

        service.resetCancellation();
        expect(service.isCancelled, isFalse);
      });
    });

    group('ImageGenerationResult', () {
      test('should create successful result correctly', () {
        final image = GeneratedImage.create(
          Uint8List.fromList([1, 2, 3]),
          width: 512,
          height: 512,
        );

        final result = ImageGenerationResult(
          images: [image],
          vibeEncodings: {'0': 'encoding1'},
        );

        expect(result.isSuccess, isTrue);
        expect(result.images.length, 1);
        expect(result.vibeEncodings, {'0': 'encoding1'});
        expect(result.isCancelled, isFalse);
        expect(result.error, isNull);
      });

      test('should create cancelled result correctly', () {
        final result = ImageGenerationResult.cancelled();

        expect(result.isSuccess, isFalse);
        expect(result.images, isEmpty);
        expect(result.isCancelled, isTrue);
        expect(result.error, isNull);
      });

      test('should create error result correctly', () {
        final result = ImageGenerationResult.error('Something went wrong');

        expect(result.isSuccess, isFalse);
        expect(result.images, isEmpty);
        expect(result.isCancelled, isFalse);
        expect(result.error, 'Something went wrong');
      });

      test('should be unsuccessful when images list is empty', () {
        const result = ImageGenerationResult(
          images: [],
        );

        expect(result.isSuccess, isFalse);
      });
    });

    group('streaming fallback scenarios', () {
      test('should handle streaming not allowed error in various formats', () async {
        const params = ImageParams(prompt: 'test prompt');
        final imageBytes = Uint8List.fromList([1, 2, 3]);

        // Test different error message formats
        final errorFormats = [
          'Streaming is not allowed',
          'streaming not allowed',
          'Stream is not allowed',
          'stream not allowed',
        ];

        for (final errorMsg in errorFormats) {
          reset(mockApiService);

          when(() => mockApiService.generateImageStream(any()))
              .thenAnswer((_) => Stream.value(
                    ImageStreamChunk.error(errorMsg),
                  ),);

          when(() => mockApiService.generateImage(any(), onProgress: any(named: 'onProgress')))
              .thenAnswer((_) async => ([imageBytes], <int, String>{}));

          final service = ImageGenerationService(apiService: mockApiService);
          final result = await service.generateSingle(params);

          expect(result.isSuccess, isTrue, reason: 'Failed for error: $errorMsg');
        }
      });

      test('should handle stream errors gracefully', () async {
        const params = ImageParams(prompt: 'test prompt');

        when(() => mockApiService.generateImageStream(any()))
            .thenAnswer((_) => Stream.error(Exception('Temporary error')));

        final result = await service.generateSingle(params);

        // Stream errors in generateSingle return error results (no retry at stream level)
        expect(result.isSuccess, isFalse);
        expect(result.error, isNotNull);
      });
    });

    group('progress callback', () {
      test('should provide correct current and total values with preview', () async {
        const params = ImageParams(prompt: 'test prompt');
        final previewBytes = Uint8List.fromList([1, 2, 3]);
        final finalBytes = Uint8List.fromList([4, 5, 6]);

        final progressValues = <Map<String, dynamic>>[];

        when(() => mockApiService.generateImageStream(any()))
            .thenAnswer((_) => Stream.fromIterable([
                  ImageStreamChunk.progress(
                    progress: 0.5,
                    previewImage: previewBytes,
                  ),
                  ImageStreamChunk.complete(finalBytes),
                ]),);

        await service.generateSingle(
          params,
          onProgress: (current, total, progress, {previewImage}) {
            progressValues.add({
              'current': current,
              'total': total,
              'progress': progress,
            });
          },
        );

        // Progress callback is only called for preview chunks, not for final completion
        expect(progressValues.isNotEmpty, isTrue);
        expect(progressValues.last['current'], 1);
        expect(progressValues.last['total'], 1);
        expect(progressValues.last['progress'], closeTo(0.5, 0.01));
      });
    });
  });
}
