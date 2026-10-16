import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/data/datasources/remote/nai_generation_transport.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_generation_api_service.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/image/image_stream_chunk.dart';
import 'package:nai_launcher/data/services/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/generation/stream_snapshot_composition.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/image_save_settings_provider.dart';
import 'package:nai_launcher/presentation/providers/notification_settings_provider.dart';

class MockNAIImageGenerationApiService extends Mock
    implements NAIImageGenerationApiService {}

class _AuthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.authenticated);
}

/// Holds every composition until the test releases it, so a snapshot can be
/// observed after capture but before it lands in history.
class _HeldComposer {
  final List<StreamPreviewFrame> frames = [];
  final List<int> coordinatorSignalsAtCompose = [];
  final List<Completer<Uint8List>> _results = [];
  int Function() coordinatorSignals = () => 0;

  Future<Uint8List> call(StreamPreviewFrame frame) {
    frames.add(frame);
    coordinatorSignalsAtCompose.add(coordinatorSignals());
    final result = Completer<Uint8List>();
    _results.add(result);
    return result.future;
  }

  void complete(int index, Uint8List bytes) => _results[index].complete(bytes);

  void fail(int index, Object error) => _results[index].completeError(error);

  void completeRemaining() {
    for (final result in _results) {
      if (!result.isCompleted) result.complete(Uint8List(0));
    }
  }
}

class _Harness {
  _Harness(this.container, this.api, this.composer);

  final ProviderContainer container;
  final MockNAIImageGenerationApiService api;
  final _HeldComposer composer;
  int cancelGenerationCalls = 0;
  int skipRequestCalls = 0;

  ImageGenerationNotifier get notifier =>
      container.read(imageGenerationNotifierProvider.notifier);

  ImageGenerationState get state =>
      container.read(imageGenerationNotifierProvider);

  ImageParams params({int nSamples = 1}) => container
      .read(generationParamsNotifierProvider)
      .copyWith(
        prompt: 'focused snapshot',
        width: 512,
        height: 768,
        nSamples: nSamples,
        model: ImageModels.animeDiffusionV45Full,
      );

  Future<void> waitForPreviews(int count) => _pumpUntil(
    () =>
        state.streamPreviewSlots
            .where((slot) => slot.previewBytes?.isNotEmpty == true)
            .length >=
        count,
    reason: 'stream previews were not published',
  );
}

Future<_Harness> _createHarness(
  List<Stream<ImageStreamChunk> Function()> streams, {
  int imagesPerRequest = 1,
}) async {
  final api = MockNAIImageGenerationApiService();
  final composer = _HeldComposer();
  var streamCall = 0;
  when(
    () => api.generateImage(
      any(),
      onProgress: any(named: 'onProgress'),
      focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
      minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
      focusedSelectionRect: any(named: 'focusedSelectionRect'),
    ),
  ).thenAnswer((_) async => (<Uint8List>[], <int, String>{}));
  when(
    () => api.generateImageStream(
      any(),
      focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
      minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
      focusedSelectionRect: any(named: 'focusedSelectionRect'),
    ),
  ).thenAnswer((_) => streams[streamCall++]());

  final container = ProviderContainer(
    overrides: [
      authNotifierProvider.overrideWith(_AuthenticatedAuthNotifier.new),
      naiImageGenerationApiServiceProvider.overrideWithValue(api),
      streamSnapshotComposerProvider.overrideWithValue(composer.call),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(composer.completeRemaining);

  final harness = _Harness(container, api, composer);
  when(() => api.cancelGeneration(any())).thenAnswer((_) {
    harness.cancelGenerationCalls++;
  });
  when(() => api.cancelCurrentGenerationRequest(any())).thenAnswer((_) {
    harness.skipRequestCalls++;
  });
  composer.coordinatorSignals = () =>
      harness.cancelGenerationCalls + harness.skipRequestCalls;

  await container
      .read(notificationSettingsNotifierProvider.notifier)
      .setSoundEnabled(false);
  await container
      .read(imageSaveSettingsNotifierProvider.notifier)
      .setAutoSave(false);
  container.read(imagesPerRequestProvider.notifier).set(imagesPerRequest);
  return harness;
}

Future<void> _pumpUntil(bool Function() condition, {String? reason}) async {
  for (var i = 0; i < 400; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail(reason ?? 'Condition not met within timeout');
}

void main() {
  late Directory hiveTempDir;

  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    registerFallbackValue(const ImageParams());
    registerFallbackValue(NaiGenerationCancellationLease());
    hiveTempDir = await Directory.systemTemp.createTemp('nai_launcher_hive_');
    Hive.init(hiveTempDir.path);
    await Hive.openBox(StorageKeys.settingsBox);
    await Hive.openBox(StorageKeys.historyBox);
    await Hive.openBox(StorageKeys.statisticsCacheBox);
  });

  setUp(() async {
    await Hive.box(StorageKeys.historyBox).clear();
    await Hive.box(
      StorageKeys.settingsBox,
    ).put(StorageKeys.imagesPerRequest, 1);
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveTempDir.exists()) {
      await hiveTempDir.delete(recursive: true);
    }
  });

  test(
    'cancel reaches the coordinator before the snapshot is composed',
    () async {
      final stream = StreamController<ImageStreamChunk>();
      final preview = _png(width: 64, height: 64);
      final composed = _png(width: 128, height: 128);
      final harness = await _createHarness([() => stream.stream]);

      final generation = harness.notifier.generate(harness.params());
      stream.add(_focusedPreview(preview));
      await harness.waitForPreviews(1);

      harness.notifier.cancel();

      expect(harness.cancelGenerationCalls, 1);
      expect(harness.composer.frames, hasLength(1));
      expect(harness.composer.coordinatorSignalsAtCompose, [1]);
      expect(harness.composer.frames.single.bytes, orderedEquals(preview));
      expect(harness.state.status, GenerationStatus.cancelled);
      expect(harness.state.history, isEmpty);

      await stream.close();
      await generation;
      expect(harness.state.history, isEmpty);

      harness.composer.complete(0, composed);
      await harness.notifier.flushGenerationHistory();

      final snapshot = harness.state.history.single;
      expect(snapshot.kind, GeneratedImageKind.failedStreamSnapshot);
      expect(snapshot.bytes, same(composed));
      expect((snapshot.width, snapshot.height), (128, 128));
      expect(snapshot.metadata!.prompt, 'focused snapshot');
      expect(snapshot.metadata!.width, 128);
      expect(harness.state.status, GenerationStatus.cancelled);
    },
  );

  test(
    'skip reaches the coordinator first and later results stay above',
    () async {
      final stream = StreamController<ImageStreamChunk>();
      final finalImage = _png(width: 512, height: 768);
      final composed = _png(width: 128, height: 128);
      final harness = await _createHarness([
        () => stream.stream,
        () => Stream.value(ImageStreamChunk.complete(finalImage)),
      ]);

      final generation = harness.notifier.generate(harness.params(nSamples: 2));
      stream.add(_focusedPreview(_png(width: 64, height: 64)));
      await harness.waitForPreviews(1);

      harness.notifier.skipCurrentRequest();

      expect(harness.skipRequestCalls, 1);
      expect(harness.composer.frames, hasLength(1));
      expect(harness.composer.coordinatorSignalsAtCompose, [1]);
      expect(harness.state.history, isEmpty);

      await stream.close();
      await generation;
      expect(harness.state.status, GenerationStatus.completed);
      expect(harness.state.history.single.bytes, orderedEquals(finalImage));

      harness.composer.complete(0, composed);
      await harness.notifier.flushGenerationHistory();

      final history = harness.state.history;
      expect(history, hasLength(2));
      expect(history[0].kind, GeneratedImageKind.completed);
      expect(history[1].kind, GeneratedImageKind.failedStreamSnapshot);
      expect(history[1].bytes, same(composed));
    },
  );

  test(
    'a new generation finished before composition keeps the snapshot below it',
    () async {
      final oldImage = _png(width: 512, height: 768);
      final newImage = _png(width: 512, height: 704);
      final stream = StreamController<ImageStreamChunk>();
      final composed = _png(width: 128, height: 128);
      final harness = await _createHarness([
        () => Stream.value(ImageStreamChunk.complete(oldImage)),
        () => stream.stream,
        () => Stream.value(ImageStreamChunk.complete(newImage)),
      ]);

      await harness.notifier.generate(harness.params());
      final oldId = harness.state.history.single.id;

      final cancelled = harness.notifier.generate(harness.params());
      stream.add(_focusedPreview(_png(width: 64, height: 64)));
      await harness.waitForPreviews(1);
      harness.notifier.cancel();
      await stream.close();
      await cancelled;

      await harness.notifier.generate(harness.params());
      final newId = harness.state.currentImages.single.id;
      expect(harness.state.history.map((image) => image.id), [newId, oldId]);

      harness.composer.complete(0, composed);
      await harness.notifier.flushGenerationHistory();

      final history = harness.state.history;
      expect(history.map((image) => image.id).toList(), [
        newId,
        history[1].id,
        oldId,
      ]);
      expect(history[1].kind, GeneratedImageKind.failedStreamSnapshot);
      expect(history[1].bytes, same(composed));
    },
  );

  test(
    'snapshots of one request keep slot order when composed out of order',
    () async {
      final stream = StreamController<ImageStreamChunk>();
      final firstPreview = _png(width: 64, height: 64);
      final secondPreview = _png(width: 64, height: 48);
      final firstComposed = _png(width: 128, height: 128);
      final secondComposed = _png(width: 128, height: 96);
      final harness = await _createHarness([
        () => stream.stream,
      ], imagesPerRequest: 2);

      final generation = harness.notifier.generate(harness.params());
      stream
        ..add(_focusedPreview(firstPreview, sampleIndex: 0))
        ..add(_focusedPreview(secondPreview, sampleIndex: 1));
      await harness.waitForPreviews(2);

      harness.notifier.cancel();
      await stream.close();
      await generation;

      final frames = harness.composer.frames;
      expect(frames, hasLength(2));
      final firstIndex = frames.indexWhere(
        (frame) => _height(frame.bytes) == 64,
      );
      final secondIndex = frames.indexWhere(
        (frame) => _height(frame.bytes) == 48,
      );
      expect({firstIndex, secondIndex}, {0, 1});

      harness.composer.complete(firstIndex, firstComposed);
      await pumpEventQueue();
      harness.composer.complete(secondIndex, secondComposed);
      await harness.notifier.flushGenerationHistory();

      final history = harness.state.history;
      expect(history, hasLength(2));
      expect(history[0].bytes, same(firstComposed));
      expect(history[1].bytes, same(secondComposed));
    },
  );

  test('focused failure keeps its error after the snapshot lands', () async {
    final composed = _png(width: 128, height: 128);
    final harness = await _createHarness([
      () => Stream<ImageStreamChunk>.fromIterable([
        _focusedPreview(_png(width: 64, height: 64)),
        ImageStreamChunk.error('API_ERROR_500|focused stream failed'),
      ]),
    ]);

    await harness.notifier.generate(harness.params());
    expect(harness.state.status, GenerationStatus.error);
    expect(harness.state.history, isEmpty);

    harness.composer.complete(0, composed);
    await harness.notifier.flushGenerationHistory();

    expect(harness.state.history.single.bytes, same(composed));
    expect(harness.state.status, GenerationStatus.error);
    expect(harness.state.errorMessage, contains('focused stream failed'));
  });

  test('composition errors keep the raw preview as the snapshot', () async {
    final stream = StreamController<ImageStreamChunk>();
    final preview = _png(width: 64, height: 64);
    final harness = await _createHarness([() => stream.stream]);

    final generation = harness.notifier.generate(harness.params());
    stream.add(_focusedPreview(preview));
    await harness.waitForPreviews(1);
    harness.notifier.cancel();
    await stream.close();
    await generation;

    harness.composer.fail(0, StateError('isolate unavailable'));
    await harness.notifier.flushGenerationHistory();

    final snapshot = harness.state.history.single;
    expect(snapshot.kind, GeneratedImageKind.failedStreamSnapshot);
    expect(snapshot.bytes, orderedEquals(preview));
    expect((snapshot.width, snapshot.height), (64, 64));
  });

  test('clearing history while composing drops the snapshot', () async {
    final stream = StreamController<ImageStreamChunk>();
    final harness = await _createHarness([() => stream.stream]);

    final generation = harness.notifier.generate(harness.params());
    stream.add(_focusedPreview(_png(width: 64, height: 64)));
    await harness.waitForPreviews(1);
    harness.notifier.cancel();
    await stream.close();
    await generation;

    harness.notifier.clearHistory();
    harness.composer.complete(0, _png(width: 128, height: 128));
    await harness.notifier.flushGenerationHistory();

    expect(harness.state.history, isEmpty);
  });

  test('disposing while composing neither writes state nor throws', () async {
    final stream = StreamController<ImageStreamChunk>();
    final harness = await _createHarness([() => stream.stream]);
    final notifier = harness.notifier;

    final generation = notifier.generate(harness.params());
    stream.add(_focusedPreview(_png(width: 64, height: 64)));
    await harness.waitForPreviews(1);
    notifier.cancel();
    await stream.close();
    await generation;

    final stateAtDispose = harness.state;
    harness.container.dispose();
    harness.composer.complete(0, _png(width: 128, height: 128));
    await pumpEventQueue();

    expect(notifier.state, same(stateAtDispose));
    expect(notifier.state.history, isEmpty);
  });
}

ImageStreamChunk _focusedPreview(Uint8List preview, {int sampleIndex = 0}) {
  final mask = img.Image(width: 64, height: 64, numChannels: 4);
  img.fill(mask, color: img.ColorRgba8(255, 255, 255, 255));
  return ImageStreamChunk.progress(
    progress: 0.5,
    sampleIndex: sampleIndex,
    currentStep: 14,
    totalSteps: 28,
    previewImage: preview,
    focusedPreviewPlacement: FocusedStreamPreviewPlacement(
      sourceImage: _png(width: 128, height: 128),
      maskImage: Uint8List.fromList(img.encodePng(mask)),
      xPercent: 0.25,
      yPercent: 0.25,
      widthPercent: 0.5,
      heightPercent: 0.5,
    ),
  );
}

int _height(Uint8List png) => img.decodePng(png)!.height;

Uint8List _png({required int width, required int height}) {
  return Uint8List.fromList(
    img.encodePng(img.Image(width: width, height: height)),
  );
}
