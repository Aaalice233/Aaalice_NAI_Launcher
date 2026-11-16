import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/data/datasources/remote/nai_generation_transport.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_generation_api_service.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/image/image_stream_chunk.dart';
import 'package:nai_launcher/presentation/providers/generation/batch_generation_notifier.dart';
import 'package:nai_launcher/presentation/providers/generation/stream_generation_notifier.dart';
import 'package:nai_launcher/presentation/providers/generation/stream_preview_decode.dart';

import '../../../helpers/controlled_preview_images.dart';

class _Api extends Mock implements NAIImageGenerationApiService {}

class _Harness {
  _Harness(this.batch) {
    when(
      () => api.generateImageStream(any()),
    ).thenAnswer((_) => streams.removeAt(0).stream);
    when(() => api.cancelGeneration(any())).thenReturn(null);
    container = ProviderContainer(
      overrides: [
        naiImageGenerationApiServiceProvider.overrideWithValue(api),
        streamPreviewImageResolverProvider.overrideWithValue(images.resolve),
      ],
    );
    if (batch) {
      container.listen(
        batchGenerationNotifierProvider,
        (_, next) => updates.add(next),
      );
    } else {
      container.listen(
        streamGenerationNotifierProvider,
        (_, next) => updates.add(next),
      );
    }
  }

  final bool batch;
  final api = _Api();
  final images = ControlledPreviewImages();
  final streams = <StreamController<ImageStreamChunk>>[];
  final updates = <Object>[];
  late final ProviderContainer container;

  Object get state => batch
      ? container.read(batchGenerationNotifierProvider)
      : container.read(streamGenerationNotifierProvider);

  Uint8List? get preview => batch
      ? container.read(batchGenerationNotifierProvider).streamPreview
      : container.read(streamGenerationNotifierProvider).previewImage;

  double get progress => batch
      ? container.read(batchGenerationNotifierProvider).items.single.progress
      : container.read(streamGenerationNotifierProvider).progress;

  Future<void> start(StreamController<ImageStreamChunk> stream) {
    streams.add(stream);
    const params = ImageParams(prompt: 'test');
    return batch
        ? container
              .read(batchGenerationNotifierProvider.notifier)
              .generateBatch(params, count: 1)
        : container
              .read(streamGenerationNotifierProvider.notifier)
              .generate(params);
  }

  void cancel() {
    if (batch) {
      container.read(batchGenerationNotifierProvider.notifier).cancel();
    } else {
      container.read(streamGenerationNotifierProvider.notifier).cancel();
    }
  }

  void dispose() {
    container.dispose();
    images.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    registerFallbackValue(const ImageParams());
    registerFallbackValue(NaiGenerationCancellationLease());
  });
  setUp(() {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  });

  for (final batch in [true, false]) {
    final name = batch ? 'batch' : 'stream';
    _Harness createHarness() {
      final harness = _Harness(batch);
      addTearDown(harness.dispose);
      return harness;
    }

    test('$name publishes progress, bytes and steps atomically', () async {
      final harness = createHarness();
      final stream = StreamController<ImageStreamChunk>();
      final generation = harness.start(stream);
      await pumpEventQueue();
      final before = harness.state;
      stream.add(_chunk(0.5));
      await pumpEventQueue();
      expect(harness.state, same(before));
      harness.updates.clear();
      harness.images.complete(0);
      await pumpEventQueue();
      expect(harness.updates, hasLength(1));
      expect(harness.progress, 0.5);
      expect(harness.preview, same(harness.images.requests[0]));
      if (batch) {
        expect(
          harness.container
              .read(batchGenerationNotifierProvider)
              .overallProgress,
          0.5,
        );
      } else {
        final state = harness.container.read(streamGenerationNotifierProvider);
        expect(state.currentStep, 14);
        expect(state.totalSteps, 28);
      }
      harness.cancel();
      await stream.close();
      await generation;
      await pumpEventQueue();
    });

    test('$name keeps B when A finishes last', () async {
      final harness = createHarness();
      final stream = StreamController<ImageStreamChunk>();
      final generation = harness.start(stream);
      stream
        ..add(_chunk(0.25))
        ..add(_chunk(0.75));
      await pumpEventQueue();
      harness.images.complete(1);
      await pumpEventQueue();
      final before = harness.state;
      harness.images.complete(0);
      await pumpEventQueue();
      expect(harness.state, same(before));
      expect(harness.progress, 0.75);
      expect(harness.preview, same(harness.images.requests[1]));
      harness.cancel();
      await stream.close();
      await generation;
      await pumpEventQueue();
    });

    test(
      '$name rejects pending preview as soon as final bytes arrive',
      () async {
        final harness = createHarness();
        final stream = StreamController<ImageStreamChunk>();
        final generation = harness.start(stream);
        stream.add(_chunk(0.5));
        await pumpEventQueue();
        stream.add(ImageStreamChunk.complete(Uint8List.fromList([2])));
        await pumpEventQueue();
        final before = harness.state;
        harness.images.complete(0);
        await pumpEventQueue();
        expect(harness.state, same(before));
        expect(harness.preview, isNull);
        await stream.close();
        await generation;
      },
    );

    for (final ending in ['final', 'cancel', 'failure', 'restart', 'dispose']) {
      test('$name rejects pending preview after $ending', () async {
        final harness = createHarness();
        final stream = StreamController<ImageStreamChunk>();
        final generation = harness.start(stream);
        stream.add(_chunk(0.5));
        await pumpEventQueue();
        if (ending == 'final') {
          stream.add(ImageStreamChunk.complete(Uint8List.fromList([2])));
        } else if (ending == 'failure') {
          stream.add(
            ImageStreamChunk.error('GENERATION_ERROR_EMPTY_INPAINT_MASK'),
          );
        } else {
          harness.cancel();
        }
        await stream.close();
        await generation;
        if (ending == 'dispose') harness.container.dispose();
        final nextStream = StreamController<ImageStreamChunk>();
        Future<void>? nextGeneration;
        if (ending == 'restart') nextGeneration = harness.start(nextStream);
        await pumpEventQueue();
        final before = ending == 'dispose' ? null : harness.state;
        harness.images.complete(0);
        await pumpEventQueue();
        if (ending != 'dispose') expect(harness.state, same(before));
        expect(
          PaintingBinding.instance.imageCache
              .statusForKey(MemoryImage(harness.images.requests[0]))
              .live,
          isFalse,
        );
        if (nextGeneration != null) {
          harness.cancel();
          await nextStream.close();
          await nextGeneration;
        }
        await pumpEventQueue();
      });
    }

    test(
      '$name publishes progress and original bytes on decode failure',
      () async {
        final harness = createHarness();
        final stream = StreamController<ImageStreamChunk>();
        final generation = harness.start(stream);
        stream.add(_chunk(0.5));
        await pumpEventQueue();
        harness.images.fail(0);
        await pumpEventQueue();
        expect(harness.progress, 0.5);
        expect(harness.preview, same(harness.images.requests[0]));
        harness.cancel();
        await stream.close();
        await generation;
        await pumpEventQueue();
      },
    );
  }
}

ImageStreamChunk _chunk(double progress) => ImageStreamChunk.progress(
  progress: progress,
  previewImage: Uint8List.fromList([1]),
  currentStep: 14,
  totalSteps: 28,
);
