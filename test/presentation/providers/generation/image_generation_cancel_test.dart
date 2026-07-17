import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/network/dio_client.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_generation_api_service.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart'
    as ui_character;
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/image/image_stream_chunk.dart';
import 'package:nai_launcher/data/models/user/user_subscription.dart';
import 'package:nai_launcher/presentation/providers/character_prompt_provider.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/image_save_settings_provider.dart';
import 'package:nai_launcher/presentation/providers/notification_settings_provider.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';

class MockNAIImageGenerationApiService extends Mock
    implements NAIImageGenerationApiService {}

class TestSubscriptionNotifier extends SubscriptionNotifier {
  @override
  SubscriptionState build() {
    return const SubscriptionState.loaded(
      UserSubscription(
        tier: 3,
        active: true,
        trainingStepsLeft: TrainingStepsInfo(
          fixedTrainingStepsLeft: 10000,
        ),
      ),
    );
  }

  @override
  Future<bool> refreshBalance() async => true;
}

/// 记录请求与取消状态的假 HTTP 适配器。
///
/// 响应永不返回，模拟仍在服务器上运行的 NAI 生成请求。
class _RecordingHttpAdapter implements HttpClientAdapter {
  final List<bool> cancelled = [];

  int get requestCount => cancelled.length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    final index = cancelled.length;
    cancelled.add(false);
    cancelFuture?.whenComplete(() => cancelled[index] = true);
    return Completer<ResponseBody>().future;
  }

  @override
  void close({bool force = false}) {}
}

Future<void> _pumpUntil(
  bool Function() condition, {
  String? reason,
}) async {
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
    hiveTempDir = await Directory.systemTemp.createTemp('nai_launcher_hive_');
    Hive.init(hiveTempDir.path);
    await Hive.openBox(StorageKeys.settingsBox);
    await Hive.openBox(StorageKeys.historyBox);
    await Hive.openBox(StorageKeys.statisticsCacheBox);
  });

  setUp(() async {
    await Hive.box(StorageKeys.settingsBox).put(
      StorageKeys.imagesPerRequest,
      1,
    );
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveTempDir.exists()) {
      await hiveTempDir.delete(recursive: true);
    }
  });

  test('cancelled generation must ignore late stream images after restart',
      () async {
    final mockApiService = MockNAIImageGenerationApiService();
    final firstStream = StreamController<ImageStreamChunk>();
    final secondStream = StreamController<ImageStreamChunk>();
    final staleImage = _validImageBytes(width: 512, height: 768);
    final freshImage = _validImageBytes(width: 640, height: 960);
    var streamCall = 0;

    when(
      () => mockApiService.generateImage(
        any(),
        onProgress: any(named: 'onProgress'),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenAnswer((_) async => (<Uint8List>[], <int, String>{}));
    when(
      () => mockApiService.generateImageStream(
        any(),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenAnswer((_) {
      streamCall += 1;
      return streamCall == 1 ? firstStream.stream : secondStream.stream;
    });
    when(() => mockApiService.cancelGeneration()).thenReturn(null);

    final container = ProviderContainer(
      overrides: [
        naiImageGenerationApiServiceProvider.overrideWithValue(mockApiService),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(notificationSettingsNotifierProvider.notifier)
        .setSoundEnabled(false);

    final notifier = container.read(imageGenerationNotifierProvider.notifier);
    final params = container.read(generationParamsNotifierProvider).copyWith(
          prompt: '1girl',
          width: 512,
          height: 768,
        );

    final firstGeneration = notifier.generate(params);
    await Future<void>.delayed(Duration.zero);

    notifier.cancel();

    final secondGeneration = notifier.generate(
      params.copyWith(width: 640, height: 960),
    );
    await Future<void>.delayed(Duration.zero);

    secondStream.add(ImageStreamChunk.complete(freshImage));
    await secondStream.close();
    await secondGeneration;

    firstStream.add(ImageStreamChunk.complete(staleImage));
    await firstStream.close();
    await firstGeneration;

    final state = container.read(imageGenerationNotifierProvider);
    expect(state.status, GenerationStatus.completed);
    expect(state.currentImages, hasLength(1));
    expect(state.currentImages.single.bytes, orderedEquals(freshImage));
    expect(state.displayImages, hasLength(1));
    expect(state.displayImages.single.bytes, orderedEquals(freshImage));
    expect(state.history, hasLength(1));
    expect(state.history.single.bytes, orderedEquals(freshImage));
  });

  test('immediate cancel before stream starts must not poison next generation',
      () async {
    final mockApiService = MockNAIImageGenerationApiService();
    final stream = StreamController<ImageStreamChunk>();
    final freshImage = _validImageBytes(width: 640, height: 960);
    var streamCall = 0;

    when(
      () => mockApiService.generateImage(
        any(),
        onProgress: any(named: 'onProgress'),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenAnswer((_) async => (<Uint8List>[], <int, String>{}));
    when(
      () => mockApiService.generateImageStream(
        any(),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenAnswer((_) {
      streamCall += 1;
      return stream.stream;
    });
    when(() => mockApiService.cancelGeneration()).thenReturn(null);

    final container = ProviderContainer(
      overrides: [
        naiImageGenerationApiServiceProvider.overrideWithValue(mockApiService),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(notificationSettingsNotifierProvider.notifier)
        .setSoundEnabled(false);

    final notifier = container.read(imageGenerationNotifierProvider.notifier);
    final params = container.read(generationParamsNotifierProvider).copyWith(
          prompt: '1girl',
          width: 512,
          height: 768,
        );

    final cancelledGeneration = notifier.generate(params);
    notifier.cancel();
    await cancelledGeneration;

    final secondGeneration = notifier.generate(
      params.copyWith(width: 640, height: 960),
    );
    await Future<void>.delayed(Duration.zero);

    expect(streamCall, 1);

    stream.add(ImageStreamChunk.complete(freshImage));
    await stream.close();
    await secondGeneration;

    final state = container.read(imageGenerationNotifierProvider);
    expect(state.status, GenerationStatus.completed);
    expect(state.currentImages, hasLength(1));
    expect(state.currentImages.single.bytes, orderedEquals(freshImage));
    expect(state.history, hasLength(1));
    expect(state.history.single.bytes, orderedEquals(freshImage));
  });

  test('cancel after stream preview keeps read-only failed snapshot in history',
      () async {
    final mockApiService = MockNAIImageGenerationApiService();
    final stream = StreamController<ImageStreamChunk>();
    final preview = _validImageBytes(width: 512, height: 768);

    when(
      () => mockApiService.generateImage(
        any(),
        onProgress: any(named: 'onProgress'),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenAnswer((_) async => (<Uint8List>[], <int, String>{}));
    when(
      () => mockApiService.generateImageStream(
        any(),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenAnswer((_) => stream.stream);
    when(() => mockApiService.cancelGeneration()).thenReturn(null);

    final container = ProviderContainer(
      overrides: [
        naiImageGenerationApiServiceProvider.overrideWithValue(mockApiService),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(notificationSettingsNotifierProvider.notifier)
        .setSoundEnabled(false);

    final notifier = container.read(imageGenerationNotifierProvider.notifier);
    final params = container.read(generationParamsNotifierProvider).copyWith(
          prompt: '1girl',
          negativePrompt: 'bad anatomy',
          width: 512,
          height: 768,
          steps: 28,
          scale: 5,
          seed: 1234,
          model: ImageModels.animeDiffusionV45Full,
        );

    final generation = notifier.generate(params);
    stream.add(
      ImageStreamChunk.progress(
        progress: 0.5,
        currentStep: 14,
        totalSteps: 28,
        previewImage: preview,
      ),
    );
    await _pumpUntil(
      () => container.read(imageGenerationNotifierProvider).hasStreamPreview,
      reason: 'stream preview was not published before cancellation',
    );

    notifier.cancel();
    await stream.close();
    await generation;

    final state = container.read(imageGenerationNotifierProvider);
    expect(state.status, GenerationStatus.cancelled);
    expect(state.currentImages, isEmpty);
    expect(state.displayImages, isEmpty);
    expect(state.history, hasLength(1));

    final snapshot = state.history.single;
    expect(snapshot.bytes, orderedEquals(preview));
    expect(snapshot.kind, GeneratedImageKind.failedStreamSnapshot);
    expect(snapshot.canSave, isFalse);
    expect(snapshot.canFavorite, isFalse);
    expect(snapshot.canUseAsGenerationInput, isFalse);
    expect(snapshot.canBulkSelect, isFalse);
    expect(snapshot.canDrag, isFalse);
    expect(snapshot.filePath, isNull);
    expect(snapshot.metadata, isA<NaiImageMetadata>());
    expect(snapshot.metadata!.prompt, equals('1girl'));
    expect(snapshot.metadata!.negativePrompt, equals('bad anatomy'));
    expect(snapshot.metadata!.width, equals(512));
    expect(snapshot.metadata!.height, equals(768));
    expect(snapshot.metadata!.steps, equals(28));
    expect(snapshot.metadata!.scale, equals(5));
    expect(snapshot.metadata!.seed, equals(1234));
    expect(snapshot.metadata!.model, equals(ImageModels.animeDiffusionV45Full));
  });

  test('multi-sample request cancel keeps failed snapshot for each sample',
      () async {
    final mockApiService = MockNAIImageGenerationApiService();
    final stream = StreamController<ImageStreamChunk>();
    final firstPreview = _validImageBytes(width: 512, height: 768);
    final secondPreview = _validImageBytes(width: 640, height: 768);
    final requestSampleCounts = <int>[];

    when(
      () => mockApiService.generateImage(
        any(),
        onProgress: any(named: 'onProgress'),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenAnswer((_) async => (<Uint8List>[], <int, String>{}));
    when(
      () => mockApiService.generateImageStream(
        any(),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenAnswer((invocation) {
      final params = invocation.positionalArguments.first as ImageParams;
      requestSampleCounts.add(params.nSamples);
      return stream.stream;
    });
    when(() => mockApiService.cancelGeneration()).thenReturn(null);

    final container = ProviderContainer(
      overrides: [
        naiImageGenerationApiServiceProvider.overrideWithValue(mockApiService),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(notificationSettingsNotifierProvider.notifier)
        .setSoundEnabled(false);
    container.read(imagesPerRequestProvider.notifier).set(2);

    final notifier = container.read(imageGenerationNotifierProvider.notifier);
    final params = container.read(generationParamsNotifierProvider).copyWith(
          prompt: 'multi sample cancel',
          width: 512,
          height: 768,
          nSamples: 1,
          model: ImageModels.animeDiffusionV45Full,
        );

    final generation = notifier.generate(params);
    await _pumpUntil(
      () => requestSampleCounts.isNotEmpty,
      reason: 'stream request was not started',
    );

    stream.add(
      ImageStreamChunk.progress(
        progress: 0.25,
        sampleIndex: 0,
        currentStep: 7,
        totalSteps: 28,
        previewImage: firstPreview,
      ),
    );
    stream.add(
      ImageStreamChunk.progress(
        progress: 0.35,
        sampleIndex: 1,
        currentStep: 10,
        totalSteps: 28,
        previewImage: secondPreview,
      ),
    );
    await _pumpUntil(
      () {
        final slots =
            container.read(imageGenerationNotifierProvider).streamPreviewSlots;
        return slots.length == 2 &&
            slots.every((slot) => slot.previewBytes?.isNotEmpty == true);
      },
      reason: 'both stream preview slots were not published before cancel',
    );

    final streamingState = container.read(imageGenerationNotifierProvider);
    expect(requestSampleCounts, equals([2]));
    expect(
      streamingState.streamPreviewSlots.map((slot) => slot.imageNumber),
      orderedEquals([1, 2]),
    );

    notifier.cancel();
    await stream.close();
    await generation;

    final state = container.read(imageGenerationNotifierProvider);
    expect(state.status, GenerationStatus.cancelled);
    expect(state.currentImages, isEmpty);
    expect(state.displayImages, isEmpty);
    expect(state.history, hasLength(2));
    expect(state.history[0].kind, GeneratedImageKind.failedStreamSnapshot);
    expect(state.history[0].bytes, orderedEquals(firstPreview));
    expect(state.history[1].kind, GeneratedImageKind.failedStreamSnapshot);
    expect(state.history[1].bytes, orderedEquals(secondPreview));
    verify(() => mockApiService.cancelGeneration()).called(1);
  });

  test('sequential repeat cancel stops all remaining batches', () async {
    final mockApiService = MockNAIImageGenerationApiService();
    final firstStream = StreamController<ImageStreamChunk>();
    final failedPreview = _validImageBytes(width: 512, height: 768);
    final finalImage = _validImageBytes(width: 640, height: 768);
    final requestSampleCounts = <int>[];

    when(
      () => mockApiService.generateImage(
        any(),
        onProgress: any(named: 'onProgress'),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenAnswer((_) async => (<Uint8List>[], <int, String>{}));
    when(
      () => mockApiService.generateImageStream(
        any(),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenAnswer((invocation) {
      final params = invocation.positionalArguments.first as ImageParams;
      requestSampleCounts.add(params.nSamples);
      if (requestSampleCounts.length == 1) {
        return firstStream.stream;
      }
      return Stream<ImageStreamChunk>.value(
        ImageStreamChunk.complete(finalImage),
      );
    });
    when(() => mockApiService.cancelGeneration()).thenReturn(null);

    final container = ProviderContainer(
      overrides: [
        naiImageGenerationApiServiceProvider.overrideWithValue(mockApiService),
        subscriptionNotifierProvider.overrideWith(TestSubscriptionNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(notificationSettingsNotifierProvider.notifier)
        .setSoundEnabled(false);
    await container
        .read(imageSaveSettingsNotifierProvider.notifier)
        .setAutoSave(false);
    container.read(imagesPerRequestProvider.notifier).set(1);

    final notifier = container.read(imageGenerationNotifierProvider.notifier);
    final params = container.read(generationParamsNotifierProvider).copyWith(
          prompt: 'sequential cancel',
          width: 512,
          height: 768,
          nSamples: 2,
          model: ImageModels.animeDiffusionV45Full,
        );

    final generation = notifier.generate(params);
    await _pumpUntil(
      () => requestSampleCounts.length == 1,
      reason: 'first stream request was not started',
    );

    firstStream.add(
      ImageStreamChunk.progress(
        progress: 0.5,
        sampleIndex: 0,
        currentStep: 14,
        totalSteps: 28,
        previewImage: failedPreview,
      ),
    );
    await _pumpUntil(
      () => container
          .read(imageGenerationNotifierProvider)
          .streamPreviewSlots
          .any((slot) => slot.previewBytes?.isNotEmpty == true),
      reason: 'first preview was not published before stop-all cancel',
    );

    notifier.cancel();
    await firstStream.close();
    await generation;

    final state = container.read(imageGenerationNotifierProvider);
    expect(requestSampleCounts, equals([1]));
    expect(state.status, GenerationStatus.cancelled);
    expect(state.currentImages, isEmpty);
    expect(state.displayImages, isEmpty);
    expect(state.history, hasLength(1));
    expect(state.history.single.kind, GeneratedImageKind.failedStreamSnapshot);
    expect(state.history.single.bytes, orderedEquals(failedPreview));
    verify(() => mockApiService.cancelGeneration()).called(1);
  });

  test('skip current request continues remaining repeat batches', () async {
    final mockApiService = MockNAIImageGenerationApiService();
    final firstStream = StreamController<ImageStreamChunk>();
    final failedPreview = _validImageBytes(width: 512, height: 768);
    final finalImage = _validImageBytes(width: 640, height: 768);
    final requestSampleCounts = <int>[];

    when(
      () => mockApiService.generateImage(
        any(),
        onProgress: any(named: 'onProgress'),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenAnswer((_) async => (<Uint8List>[], <int, String>{}));
    when(
      () => mockApiService.generateImageStream(
        any(),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenAnswer((invocation) {
      final params = invocation.positionalArguments.first as ImageParams;
      requestSampleCounts.add(params.nSamples);
      if (requestSampleCounts.length == 1) {
        return firstStream.stream;
      }
      return Stream<ImageStreamChunk>.value(
        ImageStreamChunk.complete(finalImage),
      );
    });
    when(() => mockApiService.cancelGeneration()).thenReturn(null);

    final container = ProviderContainer(
      overrides: [
        naiImageGenerationApiServiceProvider.overrideWithValue(mockApiService),
        subscriptionNotifierProvider.overrideWith(TestSubscriptionNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(notificationSettingsNotifierProvider.notifier)
        .setSoundEnabled(false);
    await container
        .read(imageSaveSettingsNotifierProvider.notifier)
        .setAutoSave(false);
    container.read(imagesPerRequestProvider.notifier).set(1);

    final notifier = container.read(imageGenerationNotifierProvider.notifier);
    final params = container.read(generationParamsNotifierProvider).copyWith(
          prompt: 'sequential skip current request',
          width: 512,
          height: 768,
          nSamples: 2,
          model: ImageModels.animeDiffusionV45Full,
        );

    final generation = notifier.generate(params);
    await _pumpUntil(
      () => requestSampleCounts.length == 1,
      reason: 'first stream request was not started',
    );

    firstStream.add(
      ImageStreamChunk.progress(
        progress: 0.5,
        sampleIndex: 0,
        currentStep: 14,
        totalSteps: 28,
        previewImage: failedPreview,
      ),
    );
    await _pumpUntil(
      () => container
          .read(imageGenerationNotifierProvider)
          .streamPreviewSlots
          .any((slot) => slot.previewBytes?.isNotEmpty == true),
      reason: 'first preview was not published before skipping request',
    );

    notifier.skipCurrentRequest();
    await firstStream.close();
    await generation;

    final state = container.read(imageGenerationNotifierProvider);
    expect(requestSampleCounts, equals([1, 1]));
    expect(state.status, GenerationStatus.completed);
    expect(state.currentImages, hasLength(1));
    expect(state.currentImages.single.bytes, orderedEquals(finalImage));
    expect(state.displayImages, hasLength(1));
    expect(state.displayImages.single.bytes, orderedEquals(finalImage));
    expect(state.history, hasLength(2));
    expect(state.history[0].kind, GeneratedImageKind.completed);
    expect(state.history[0].bytes, orderedEquals(finalImage));
    expect(state.history[1].kind, GeneratedImageKind.failedStreamSnapshot);
    expect(state.history[1].bytes, orderedEquals(failedPreview));
    verify(() => mockApiService.cancelGeneration()).called(1);
  });

  test('random seed is materialized for failed stream snapshot metadata',
      () async {
    final mockApiService = MockNAIImageGenerationApiService();
    final stream = StreamController<ImageStreamChunk>();
    final preview = _validImageBytes(width: 512, height: 768);
    ImageParams? streamParams;

    when(
      () => mockApiService.generateImage(
        any(),
        onProgress: any(named: 'onProgress'),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenAnswer((_) async => (<Uint8List>[], <int, String>{}));
    when(
      () => mockApiService.generateImageStream(
        any(),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenAnswer((invocation) {
      streamParams = invocation.positionalArguments.first as ImageParams;
      return stream.stream;
    });
    when(() => mockApiService.cancelGeneration()).thenReturn(null);

    final container = ProviderContainer(
      overrides: [
        naiImageGenerationApiServiceProvider.overrideWithValue(mockApiService),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(notificationSettingsNotifierProvider.notifier)
        .setSoundEnabled(false);

    final notifier = container.read(imageGenerationNotifierProvider.notifier);
    final params = container.read(generationParamsNotifierProvider).copyWith(
          prompt: 'random seed snapshot',
          width: 512,
          height: 768,
          seed: -1,
          model: ImageModels.animeDiffusionV45Full,
        );

    final generation = notifier.generate(params);
    stream.add(
      ImageStreamChunk.progress(
        progress: 0.5,
        currentStep: 14,
        totalSteps: 28,
        previewImage: preview,
      ),
    );
    await _pumpUntil(
      () => container.read(imageGenerationNotifierProvider).hasStreamPreview,
      reason: 'stream preview was not published before cancellation',
    );

    notifier.cancel();
    await stream.close();
    await generation;

    final requestSeed = streamParams?.seed;
    expect(requestSeed, isNotNull);
    expect(requestSeed, isNot(-1));

    final state = container.read(imageGenerationNotifierProvider);
    expect(state.status, GenerationStatus.cancelled);
    expect(state.history, hasLength(1));
    final snapshot = state.history.single;
    expect(snapshot.kind, GeneratedImageKind.failedStreamSnapshot);
    expect(snapshot.metadata!.seed, equals(requestSeed));
  });

  test('stream error after preview keeps read-only failed snapshot and error',
      () async {
    final mockApiService = MockNAIImageGenerationApiService();
    final preview = _validImageBytes(width: 512, height: 768);

    when(
      () => mockApiService.generateImage(
        any(),
        onProgress: any(named: 'onProgress'),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenAnswer((_) async => (<Uint8List>[], <int, String>{}));
    when(
      () => mockApiService.generateImageStream(
        any(),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenAnswer(
      (_) => Stream<ImageStreamChunk>.fromIterable([
        ImageStreamChunk.progress(
          progress: 0.25,
          currentStep: 7,
          totalSteps: 28,
          previewImage: preview,
        ),
        ImageStreamChunk.error('API_ERROR_500|stream failed'),
      ]),
    );
    when(() => mockApiService.cancelGeneration()).thenReturn(null);

    final container = ProviderContainer(
      overrides: [
        naiImageGenerationApiServiceProvider.overrideWithValue(mockApiService),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(notificationSettingsNotifierProvider.notifier)
        .setSoundEnabled(false);

    final notifier = container.read(imageGenerationNotifierProvider.notifier);
    final characterNotifier =
        container.read(characterPromptNotifierProvider.notifier);
    characterNotifier.replaceAll([
      ui_character.CharacterPrompt.create(
        name: 'Character 1',
        prompt: 'red hair, sword',
        negativePrompt: 'helmet',
      ),
      ui_character.CharacterPrompt.create(
        name: 'Character 2',
        prompt: 'blue hair, staff',
        negativePrompt: 'cape',
      ),
    ]);
    characterNotifier.setGlobalAiChoice(false);

    final params = container.read(generationParamsNotifierProvider).copyWith(
          prompt: 'failed prompt',
          width: 512,
          height: 768,
          model: ImageModels.animeDiffusionV45Full,
        );

    await notifier.generate(params);

    final state = container.read(imageGenerationNotifierProvider);
    expect(state.status, GenerationStatus.error);
    expect(state.errorMessage, contains('stream failed'));
    expect(state.currentImages, isEmpty);
    expect(state.displayImages, isEmpty);
    expect(state.history, hasLength(1));
    expect(state.history.single.kind, GeneratedImageKind.failedStreamSnapshot);
    expect(state.history.single.bytes, orderedEquals(preview));
    expect(state.history.single.metadata!.prompt, equals('failed prompt'));
    expect(
      state.history.single.metadata!.model,
      equals(ImageModels.animeDiffusionV45Full),
    );
    expect(
      state.history.single.metadata!.characterPrompts,
      containsAll([
        contains('red hair, sword'),
        contains('blue hair, staff'),
      ]),
    );
    expect(
      state.history.single.metadata!.characterNegativePrompts,
      containsAll(['helmet', 'cape']),
    );
  });

  test('focused stream error snapshot uses shared soft-mask placement',
      () async {
    final mockApiService = MockNAIImageGenerationApiService();
    final source = _solidImageBytes(
      width: 256,
      height: 256,
      red: 10,
      green: 20,
      blue: 30,
    );
    final preview = _solidImageBytes(
      width: 128,
      height: 128,
      red: 200,
      green: 210,
      blue: 220,
    );
    final compositeMask = img.Image(
      width: 128,
      height: 128,
      numChannels: 4,
    );
    img.fill(compositeMask, color: img.ColorRgba8(0, 0, 0, 0));
    img.fillRect(
      compositeMask,
      x1: 32,
      y1: 32,
      x2: 95,
      y2: 95,
      color: img.ColorRgba8(255, 255, 255, 255),
    );
    compositeMask.setPixelRgba(16, 16, 128, 128, 128, 128);
    final placement = FocusedStreamPreviewPlacement(
      sourceImage: source,
      maskImage: Uint8List.fromList(img.encodePng(compositeMask)),
      xPercent: 0.25,
      yPercent: 0.25,
      widthPercent: 0.5,
      heightPercent: 0.5,
    );

    when(
      () => mockApiService.generateImage(
        any(),
        onProgress: any(named: 'onProgress'),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenAnswer((_) async => (<Uint8List>[], <int, String>{}));
    when(
      () => mockApiService.generateImageStream(
        any(),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenAnswer(
      (_) => Stream<ImageStreamChunk>.fromIterable([
        ImageStreamChunk.progress(
          progress: 0.5,
          currentStep: 14,
          totalSteps: 28,
          previewImage: preview,
          focusedPreviewPlacement: placement,
        ),
        ImageStreamChunk.error('API_ERROR_500|focused stream failed'),
      ]),
    );
    when(() => mockApiService.cancelGeneration()).thenReturn(null);

    final container = ProviderContainer(
      overrides: [
        naiImageGenerationApiServiceProvider.overrideWithValue(mockApiService),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(notificationSettingsNotifierProvider.notifier)
        .setSoundEnabled(false);

    final notifier = container.read(imageGenerationNotifierProvider.notifier);
    final rawMask = img.Image(width: 256, height: 256, numChannels: 4);
    img.fill(rawMask, color: img.ColorRgba8(0, 0, 0, 255));
    rawMask.setPixelRgba(128, 128, 255, 255, 255, 255);
    final params = container.read(generationParamsNotifierProvider).copyWith(
          prompt: 'focused failed snapshot',
          action: ImageGenerationAction.infill,
          model: 'nai-diffusion-4-5-full-inpainting',
          width: 256,
          height: 256,
          sourceImage: source,
          maskImage: Uint8List.fromList(img.encodePng(rawMask)),
        );

    await notifier.generate(params);

    final state = container.read(imageGenerationNotifierProvider);
    expect(state.status, GenerationStatus.error);
    expect(state.history, hasLength(1));
    final snapshot = img.decodeImage(state.history.single.bytes)!;
    expect((snapshot.width, snapshot.height), (256, 256));
    expect(_rgb(snapshot, 0, 0), (10, 20, 30));
    expect(_rgb(snapshot, 128, 128), (200, 210, 220));
    final softPixel = _rgb(snapshot, 80, 80);
    expect(softPixel.$1, inInclusiveRange(100, 110));
    expect(softPixel.$2, inInclusiveRange(110, 120));
    expect(softPixel.$3, inInclusiveRange(120, 130));
  });

  test('batch empty fallback after preview keeps failed snapshot in history',
      () async {
    final mockApiService = MockNAIImageGenerationApiService();
    final preview = _validImageBytes(width: 512, height: 768);
    var streamCall = 0;

    when(
      () => mockApiService.generateImage(
        any(),
        onProgress: any(named: 'onProgress'),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenAnswer((_) async => (<Uint8List>[], <int, String>{}));
    when(
      () => mockApiService.generateImageCancellable(
        any(),
        onProgress: any(named: 'onProgress'),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenAnswer((_) async => <Uint8List>[]);
    when(
      () => mockApiService.generateImageStream(
        any(),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenAnswer((_) {
      streamCall += 1;
      if (streamCall == 1) {
        return Stream<ImageStreamChunk>.fromIterable([
          ImageStreamChunk.progress(
            progress: 0.5,
            currentStep: 14,
            totalSteps: 28,
            previewImage: preview,
          ),
        ]);
      }
      return const Stream<ImageStreamChunk>.empty();
    });
    when(() => mockApiService.cancelGeneration()).thenReturn(null);

    final container = ProviderContainer(
      overrides: [
        naiImageGenerationApiServiceProvider.overrideWithValue(mockApiService),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(notificationSettingsNotifierProvider.notifier)
        .setSoundEnabled(false);
    container.read(imagesPerRequestProvider.notifier).set(2);

    final notifier = container.read(imageGenerationNotifierProvider.notifier);
    final params = container.read(generationParamsNotifierProvider).copyWith(
          prompt: 'batch failed prompt',
          width: 512,
          height: 768,
          nSamples: 1,
          model: ImageModels.animeDiffusionV45Full,
        );

    await notifier.generate(params);
    container.read(imagesPerRequestProvider.notifier).set(1);

    final state = container.read(imageGenerationNotifierProvider);
    expect(state.status, GenerationStatus.error);
    expect(state.currentImages, isEmpty);
    expect(state.displayImages, isEmpty);
    expect(state.history, hasLength(1));
    expect(state.history.single.kind, GeneratedImageKind.failedStreamSnapshot);
    expect(state.history.single.bytes, orderedEquals(preview));
    expect(
      state.history.single.metadata!.prompt,
      equals('batch failed prompt'),
    );
  });

  test(
      'cancel after successful stream completion must not create failed snapshot',
      () async {
    final mockApiService = MockNAIImageGenerationApiService();
    final preview = _validImageBytes(width: 512, height: 768);
    final finalImage = _validImageBytes(width: 512, height: 768);

    when(
      () => mockApiService.generateImage(
        any(),
        onProgress: any(named: 'onProgress'),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenAnswer((_) async => (<Uint8List>[], <int, String>{}));
    when(
      () => mockApiService.generateImageStream(
        any(),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenAnswer(
      (_) => Stream<ImageStreamChunk>.fromIterable([
        ImageStreamChunk.progress(
          progress: 0.25,
          currentStep: 7,
          totalSteps: 28,
          previewImage: preview,
        ),
        ImageStreamChunk.complete(finalImage),
      ]),
    );
    when(() => mockApiService.cancelGeneration()).thenReturn(null);

    final container = ProviderContainer(
      overrides: [
        naiImageGenerationApiServiceProvider.overrideWithValue(mockApiService),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(notificationSettingsNotifierProvider.notifier)
        .setSoundEnabled(false);

    final notifier = container.read(imageGenerationNotifierProvider.notifier);
    final params = container.read(generationParamsNotifierProvider).copyWith(
          prompt: 'successful prompt',
          width: 512,
          height: 768,
          model: ImageModels.animeDiffusionV45Full,
        );

    await notifier.generate(params);

    final completedState = container.read(imageGenerationNotifierProvider);
    expect(completedState.status, GenerationStatus.completed);
    expect(completedState.currentImages, hasLength(1));
    expect(completedState.displayImages, hasLength(1));
    expect(completedState.history, hasLength(1));
    expect(completedState.history.single.kind, GeneratedImageKind.completed);
    expect(completedState.history.single.bytes, orderedEquals(finalImage));

    notifier.cancel();

    final cancelledState = container.read(imageGenerationNotifierProvider);
    expect(cancelledState.history, hasLength(1));
    expect(
      cancelledState.history
          .where(
            (image) => image.kind == GeneratedImageKind.failedStreamSnapshot,
          )
          .toList(),
      isEmpty,
    );
  });
  test(
      'non-cancelled batch cancelled error must surface instead of completing empty',
      () async {
    final mockApiService = MockNAIImageGenerationApiService();

    when(
      () => mockApiService.generateImage(
        any(),
        onProgress: any(named: 'onProgress'),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenAnswer((_) async => (<Uint8List>[], <int, String>{}));
    when(
      () => mockApiService.generateImageStream(
        any(),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenAnswer((_) => Stream.value(ImageStreamChunk.error('Cancelled')));
    when(() => mockApiService.cancelGeneration()).thenReturn(null);

    final container = ProviderContainer(
      overrides: [
        naiImageGenerationApiServiceProvider.overrideWithValue(mockApiService),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(notificationSettingsNotifierProvider.notifier)
        .setSoundEnabled(false);

    final notifier = container.read(imageGenerationNotifierProvider.notifier);
    final params = container.read(generationParamsNotifierProvider).copyWith(
          prompt: '1girl',
          nSamples: 2,
        );

    await notifier.generate(params);

    final state = container.read(imageGenerationNotifierProvider);
    expect(state.status, GenerationStatus.error);
    expect(state.currentImages, isEmpty);
    expect(state.history, isEmpty);
    expect(state.errorMessage, contains('Cancelled'));
  });

  test('single generation must not complete when stream and fallback are empty',
      () async {
    final mockApiService = MockNAIImageGenerationApiService();

    when(
      () => mockApiService.generateImage(
        any(),
        onProgress: any(named: 'onProgress'),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenAnswer((_) async => (<Uint8List>[], <int, String>{}));
    when(
      () => mockApiService.generateImageStream(
        any(),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenAnswer((_) => const Stream<ImageStreamChunk>.empty());
    when(() => mockApiService.cancelGeneration()).thenReturn(null);

    final container = ProviderContainer(
      overrides: [
        naiImageGenerationApiServiceProvider.overrideWithValue(mockApiService),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(notificationSettingsNotifierProvider.notifier)
        .setSoundEnabled(false);

    final notifier = container.read(imageGenerationNotifierProvider.notifier);
    final params = container.read(generationParamsNotifierProvider).copyWith(
          prompt: '1girl',
          nSamples: 1,
        );

    await notifier.generate(params);

    final state = container.read(imageGenerationNotifierProvider);
    expect(state.status, GenerationStatus.error);
    expect(state.currentImages, isEmpty);
    expect(state.displayImages, isEmpty);
    expect(state.history, isEmpty);
    expect(state.errorMessage, contains('No images returned'));
  });

  test('cancel must abort the in-flight HTTP request', () async {
    // 不替换 naiImageGenerationApiServiceProvider：走真实服务链路，
    // 复现 generate() 与 cancel() 分别 ref.read 服务实例的生产行为。
    final adapter = _RecordingHttpAdapter();
    final container = ProviderContainer(
      overrides: [
        imageGenerationDioClientProvider.overrideWithValue(
          Dio()..httpClientAdapter = adapter,
        ),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(notificationSettingsNotifierProvider.notifier)
        .setSoundEnabled(false);

    final notifier = container.read(imageGenerationNotifierProvider.notifier);
    final params = container.read(generationParamsNotifierProvider).copyWith(
          prompt: '1girl',
          nSamples: 1,
        );

    final firstGeneration = notifier.generate(params);
    await _pumpUntil(
      () => adapter.requestCount >= 1,
      reason: 'first generation never reached the HTTP layer',
    );

    notifier.cancel();
    await _pumpUntil(
      () => adapter.cancelled.first,
      reason: 'cancel() must cancel the CancelToken of the in-flight request; '
          'otherwise the orphaned generation keeps holding the NAI '
          'per-account concurrency slot and later generations fail with 429',
    );
    await firstGeneration;

    final secondGeneration = notifier.generate(params);
    await _pumpUntil(
      () => adapter.requestCount >= 2,
      reason: 'generation after cancel never reached the HTTP layer',
    );
    expect(adapter.cancelled[1], isFalse);

    notifier.cancel();
    await _pumpUntil(() => adapter.cancelled[1]);
    await secondGeneration;
  });

  test('429 concurrency limit must auto-retry until the slot frees', () async {
    final mockApiService = MockNAIImageGenerationApiService();
    final freshImage = _validImageBytes(width: 512, height: 768);
    var streamCall = 0;

    when(
      () => mockApiService.generateImage(
        any(),
        onProgress: any(named: 'onProgress'),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenAnswer((_) async => (<Uint8List>[], <int, String>{}));
    when(
      () => mockApiService.generateImageStream(
        any(),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenAnswer((_) {
      streamCall += 1;
      if (streamCall == 1) {
        // 模拟孤儿任务仍占用 NAI 并发额度
        return Stream.value(
          ImageStreamChunk.error(
            'API_ERROR_429|A previous request is still being processed',
          ),
        );
      }
      return Stream.value(ImageStreamChunk.complete(freshImage));
    });
    when(() => mockApiService.cancelGeneration()).thenReturn(null);

    final container = ProviderContainer(
      overrides: [
        naiImageGenerationApiServiceProvider.overrideWithValue(mockApiService),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(notificationSettingsNotifierProvider.notifier)
        .setSoundEnabled(false);

    final notifier = container.read(imageGenerationNotifierProvider.notifier);
    final params = container.read(generationParamsNotifierProvider).copyWith(
          prompt: '1girl',
          nSamples: 1,
        );

    await notifier.generate(params);

    final state = container.read(imageGenerationNotifierProvider);
    expect(streamCall, 2);
    expect(state.status, GenerationStatus.completed);
    expect(state.currentImages, hasLength(1));
    expect(state.currentImages.single.bytes, orderedEquals(freshImage));
  });

  test('cancel during 429 wait must stop retrying', () async {
    final mockApiService = MockNAIImageGenerationApiService();
    var streamCall = 0;

    when(
      () => mockApiService.generateImage(
        any(),
        onProgress: any(named: 'onProgress'),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenAnswer((_) async => (<Uint8List>[], <int, String>{}));
    when(
      () => mockApiService.generateImageStream(
        any(),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenAnswer((_) {
      streamCall += 1;
      return Stream.value(
        ImageStreamChunk.error(
          'API_ERROR_429|A previous request is still being processed',
        ),
      );
    });
    when(() => mockApiService.cancelGeneration()).thenReturn(null);

    final container = ProviderContainer(
      overrides: [
        naiImageGenerationApiServiceProvider.overrideWithValue(mockApiService),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(notificationSettingsNotifierProvider.notifier)
        .setSoundEnabled(false);

    final notifier = container.read(imageGenerationNotifierProvider.notifier);
    final params = container.read(generationParamsNotifierProvider).copyWith(
          prompt: '1girl',
          nSamples: 1,
        );

    final generation = notifier.generate(params);
    await _pumpUntil(() => streamCall >= 1);

    // 此刻位于 429 等待期内，取消必须终止自动重试
    notifier.cancel();
    await generation;

    expect(
      container.read(imageGenerationNotifierProvider).status,
      GenerationStatus.cancelled,
    );
    final callsAfterCancel = streamCall;
    await Future<void>.delayed(const Duration(milliseconds: 3500));
    expect(streamCall, callsAfterCancel);
  });
}

Uint8List _validImageBytes({
  required int width,
  required int height,
}) {
  return Uint8List.fromList(
    img.encodePng(
      img.Image(width: width, height: height),
    ),
  );
}

Uint8List _solidImageBytes({
  required int width,
  required int height,
  required int red,
  required int green,
  required int blue,
}) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(red, green, blue, 255));
  return Uint8List.fromList(img.encodePng(image));
}

(int, int, int) _rgb(img.Image image, int x, int y) {
  final pixel = image.getPixel(x, y);
  return (pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt());
}
