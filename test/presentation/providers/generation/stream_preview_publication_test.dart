import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_generation_api_service.dart';
import 'package:nai_launcher/data/datasources/remote/nai_generation_transport.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/image/image_stream_chunk.dart';
import 'package:nai_launcher/data/services/auth_provider.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/generation/stream_preview_decode.dart';
import 'package:nai_launcher/presentation/providers/generation/stream_preview_publication.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/image_save_settings_provider.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/history_panel/history_image_card.dart';
import 'package:nai_launcher/presentation/widgets/common/image_card_stream_preview.dart';
import 'package:nai_launcher/presentation/widgets/common/selectable_image_card.dart';
import 'package:nai_launcher/presentation/widgets/common/transparency_background.dart';

import '../../../helpers/controlled_preview_images.dart';
import '../../../helpers/image_generation_test_environment.dart'
    show AuthenticatedAuthNotifier, MockNAIImageGenerationApiService;

class _Harness {
  _Harness() {
    when(
      () => api.generateImageStream(
        any(),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
      ),
    ).thenAnswer((_) => streams.removeAt(0).stream);
    when(() => api.cancelGeneration(any())).thenReturn(null);
    when(() => api.cancelCurrentGenerationRequest(any())).thenReturn(null);
    container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(AuthenticatedAuthNotifier.new),
        naiImageGenerationApiServiceProvider.overrideWithValue(api),
        streamPreviewImageResolverProvider.overrideWithValue(images.resolve),
        streamPreviewLifecycleReaderProvider.overrideWithValue(() => lifecycle),
      ],
    );
  }

  final api = MockNAIImageGenerationApiService();
  final images = ControlledPreviewImages();
  final streams = <StreamController<ImageStreamChunk>>[];
  late final ProviderContainer container;
  AppLifecycleState? lifecycle = AppLifecycleState.resumed;

  ImageGenerationNotifier get notifier =>
      container.read(imageGenerationNotifierProvider.notifier);
  ImageGenerationState get state =>
      container.read(imageGenerationNotifierProvider);

  Future<GenerationOutcome> start(StreamController<ImageStreamChunk> stream) {
    streams.add(stream);
    return notifier.generate(
      const ImageParams(prompt: 'preview', width: 512, height: 768),
    );
  }

  void dispose() {
    container.dispose();
    images.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    registerFallbackValue(const ImageParams());
    registerFallbackValue(NaiGenerationCancellationLease());
    Hive.init('tool/.tmp/stream-preview-publication');
    for (final name in [
      StorageKeys.settingsBox,
      StorageKeys.statisticsCacheBox,
    ]) {
      await Hive.openBox(name, bytes: Uint8List(0));
    }
  });
  setUp(() async {
    await Hive.box(StorageKeys.settingsBox).clear();
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  });
  tearDownAll(Hive.close);

  Future<_Harness> createHarness(WidgetTester tester) async {
    final harness = _Harness();
    await harness.container
        .read(imageSaveSettingsNotifierProvider.notifier)
        .setAutoSave(false);
    addTearDown(harness.dispose);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
    });
    return harness;
  }

  testWidgets('one chunk paints new progress and image in its only frame', (
    tester,
  ) async {
    final harness = await createHarness(tester);
    final stream = StreamController<ImageStreamChunk>();
    final generation = harness.start(stream);
    await tester.idle();
    await tester.pumpWidget(_app(harness.container));

    stream.add(_chunk(0.25));
    await tester.idle();
    expect(harness.state.streamPreview, isNull);
    final first = harness.images.complete(0);
    await tester.idle();
    expect(harness.state.streamPreview, same(harness.images.requests[0]));
    expect(
      harness.state.streamPreviewSlots.single.previewBytes,
      same(harness.images.requests[0]),
    );

    await tester.pump();
    expect(find.text('25%'), findsOneWidget);
    expect(_painter(tester).previewImage!.isCloneOf(first), isTrue);
    expect(tester.binding.hasScheduledFrame, isFalse);

    stream.add(_chunk(0.75));
    await tester.idle();
    expect(find.text('25%'), findsOneWidget);
    final second = harness.images.complete(1);
    await tester.idle();
    await tester.pump();
    expect(find.text('75%'), findsOneWidget);
    expect(_painter(tester).previewImage!.isCloneOf(second), isTrue);
    expect(tester.binding.hasScheduledFrame, isFalse);
    harness.notifier.cancel();
    await stream.close();
    await generation;
    await tester.pump(Duration.zero);
  });

  testWidgets(
    'slow decodes keep advancing progress and pixels on every completion',
    (tester) async {
      final harness = await createHarness(tester);
      final stream = StreamController<ImageStreamChunk>();
      final generation = harness.start(stream);
      await tester.idle();
      await tester.pumpWidget(_app(harness.container));
      stream
        ..add(_chunk(0.1))
        ..add(_chunk(0.2))
        ..add(_chunk(0.3));
      await tester.idle();
      expect(harness.images.requests, hasLength(2));
      for (var index = 0; index < 4; index++) {
        final image = harness.images.complete(index);
        await tester.idle();
        await tester.pump();
        expect(find.text('${(index + 1) * 10}%'), findsOneWidget);
        expect(_painter(tester).previewImage!.isCloneOf(image), isTrue);
        expect(
          harness.state.streamPreview,
          same(harness.images.requests[index]),
        );
        expect(tester.binding.hasScheduledFrame, isFalse);
        if (index == 0) {
          stream.add(_chunk(0.4));
          await tester.idle();
        }
      }
      harness.notifier.cancel();
      await stream.close();
      await generation;
      await tester.pump();
    },
  );

  testWidgets('focused patch waits for source and mask before its only frame', (
    tester,
  ) async {
    final harness = await createHarness(tester);
    final stream = StreamController<ImageStreamChunk>();
    final generation = harness.start(stream);
    await tester.idle();
    await tester.pumpWidget(_app(harness.container));
    final placement = FocusedStreamPreviewPlacement(
      sourceImage: Uint8List.fromList([2]),
      maskImage: Uint8List.fromList([3]),
      xPercent: 0.25,
      yPercent: 0.25,
      widthPercent: 0.5,
      heightPercent: 0.5,
    );
    stream.add(_chunk(0.5, placement: placement));
    await tester.idle();
    expect(harness.images.requests[1], same(placement.sourceImage));
    expect(harness.images.requests[2], same(placement.maskImage));
    final patch = harness.images.complete(0);
    final source = harness.images.complete(1);
    await tester.idle();
    expect(harness.state.streamPreview, isNull);
    final mask = harness.images.complete(2);
    await tester.idle();
    await tester.pump();
    final painter = _painter(tester);
    expect(painter.previewImage!.isCloneOf(patch), isTrue);
    expect(painter.sourceImage!.isCloneOf(source), isTrue);
    expect(painter.maskImage!.isCloneOf(mask), isTrue);
    expect(painter.placement, same(placement));
    expect(find.text('50%'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
    stream.add(ImageStreamChunk.complete(Uint8List.fromList([4])));
    await stream.close();
    await generation;
    await tester.pump(Duration.zero);
  });

  testWidgets('LRU eviction cannot evict the live preview before mounting', (
    tester,
  ) async {
    final harness = await createHarness(tester);
    final cache = PaintingBinding.instance.imageCache;
    final maximum = cache.maximumSizeBytes;
    cache.maximumSizeBytes = 1;
    addTearDown(() => cache.maximumSizeBytes = maximum);
    final stream = StreamController<ImageStreamChunk>();
    final generation = harness.start(stream);
    stream.add(_chunk(0.5));
    await tester.idle();
    final image = harness.images.complete(0);
    await tester.idle();
    final key = MemoryImage(harness.state.streamPreview!);
    expect(cache.statusForKey(key).keepAlive, isFalse);
    expect(cache.statusForKey(key).live, isTrue);
    cache.clear();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox.square(
          dimension: 160,
          child: ImageCardStreamPreview(previewBytes: key.bytes),
        ),
      ),
    );
    expect(_painter(tester).previewImage!.isCloneOf(image), isTrue);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox());
    expect(cache.statusForKey(key).live, isFalse);
    harness.notifier.cancel();
    await stream.close();
    await generation;
    await tester.pump(Duration.zero);
  });

  testWidgets('B finishing before A publishes only B and releases A', (
    tester,
  ) async {
    final harness = await createHarness(tester);
    final stream = StreamController<ImageStreamChunk>();
    final generation = harness.start(stream);
    stream
      ..add(_chunk(0.25))
      ..add(_chunk(0.75));
    await tester.idle();
    final newer = harness.images.complete(1);
    await tester.idle();
    final published = harness.state;
    harness.images.complete(0);
    await tester.idle();
    expect(harness.state, same(published));
    expect(harness.state.progress, 0.75);
    expect(harness.state.streamPreview, same(harness.images.requests[1]));
    expect(
      PaintingBinding.instance.imageCache
          .statusForKey(MemoryImage(harness.images.requests[0]))
          .live,
      isFalse,
    );
    await tester.pumpWidget(_app(harness.container));
    expect(_painter(tester).previewImage!.isCloneOf(newer), isTrue);
    harness.notifier.cancel();
    await stream.close();
    await generation;
    await tester.pump(Duration.zero);
  });

  testWidgets(
    'out of order slots keep the latest global image and both slots',
    (tester) async {
      final harness = await createHarness(tester);
      harness.container.read(imagesPerRequestProvider.notifier).set(2);
      final stream = StreamController<ImageStreamChunk>();
      final generation = harness.start(stream);
      stream
        ..add(_chunk(0.25))
        ..add(_chunk(0.75, sampleIndex: 1));
      await tester.idle();
      harness.images.complete(1);
      await tester.idle();
      harness.images.complete(0);
      await tester.idle();
      expect(harness.state.currentImage, 2);
      expect(harness.state.progress, 0.875);
      expect(harness.state.streamPreview, same(harness.images.requests[1]));
      expect(
        harness.state.streamPreviewSlots[0].previewBytes,
        same(harness.images.requests[0]),
      );
      expect(
        harness.state.streamPreviewSlots[1].previewBytes,
        same(harness.images.requests[1]),
      );
      harness.notifier.cancel();
      await stream.close();
      await generation;
      await tester.pump(Duration.zero);
    },
  );

  Future<_Harness> createProviderHarness() async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    await harness.container
        .read(imageSaveSettingsNotifierProvider.notifier)
        .setAutoSave(false);
    return harness;
  }

  test(
    'another slot finalizing prevents old decodes rolling back global progress',
    () async {
      final harness = await createProviderHarness();
      harness.container.read(imagesPerRequestProvider.notifier).set(2);
      final stream = StreamController<ImageStreamChunk>();
      final generation = harness.start(stream);
      stream
        ..add(_chunk(0.25))
        ..add(_chunk(0.75, sampleIndex: 1));
      await pumpEventQueue();
      stream.add(
        ImageStreamChunk.complete(Uint8List.fromList([9]), sampleIndex: 1),
      );
      await pumpEventQueue();
      expect(harness.state.progress, 1);
      harness.images.complete(0);
      await pumpEventQueue();
      expect(harness.state.progress, 1);
      expect(harness.state.currentImage, 2);
      expect(
        harness.state.streamPreviewSlots.first.previewBytes,
        same(harness.images.requests.first),
      );
      harness.images.complete(1);
      stream.add(ImageStreamChunk.complete(Uint8List.fromList([8])));
      await stream.close();
      await generation;
    },
  );

  for (final ending in ['final', 'cancel']) {
    test(
      'thirty chunks without frames remain bounded and release on $ending',
      () async {
        final harness = await createProviderHarness();
        final stream = StreamController<ImageStreamChunk>();
        final generation = harness.start(stream);
        for (var index = 0; index < 30; index++) {
          stream.add(_chunk((index + 1) / 100));
          await pumpEventQueue();
          harness.images.complete(index);
          await pumpEventQueue();
          expect(harness.images.listeners, 1);
        }
        if (ending == 'final') {
          stream.add(ImageStreamChunk.complete(Uint8List.fromList([9])));
          await pumpEventQueue();
        } else {
          harness.notifier.cancel();
        }
        expect(harness.images.listeners, 0);
        await stream.close();
        await generation;
        expect(harness.images.listeners, 0);
      },
    );
  }

  for (final lifecycle in [
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.detached,
  ]) {
    test('$lifecycle bypasses decoding until the next visible chunk', () async {
      final harness = await createProviderHarness();
      harness.lifecycle = lifecycle;
      final stream = StreamController<ImageStreamChunk>();
      final generation = harness.start(stream);
      stream.add(_chunk(0.25));
      await pumpEventQueue();
      expect(harness.images.requests, isEmpty);
      expect(harness.state.progress, 0.25);
      expect(
        harness.state.streamPreviewSlots.single.previewBytes,
        same(harness.state.streamPreview),
      );
      harness.lifecycle = AppLifecycleState.resumed;
      stream.add(_chunk(0.75));
      await pumpEventQueue();
      expect(harness.state.progress, 0.25);
      harness.images.complete(0);
      await pumpEventQueue();
      expect(harness.state.progress, 0.75);
      expect(harness.state.streamPreview, same(harness.images.requests.single));
      harness.notifier.cancel();
      await stream.close();
      await generation;
    });
  }

  for (final ending in ['final', 'cancel', 'failure', 'restart', 'dispose']) {
    test('pending decode cannot publish after $ending', () async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      await harness.container
          .read(imageSaveSettingsNotifierProvider.notifier)
          .setAutoSave(false);
      final stream = StreamController<ImageStreamChunk>();
      final generation = harness.start(stream);
      stream.add(_chunk(0.5));
      await pumpEventQueue();
      expect(harness.images.requests, hasLength(1));
      final finalBytes = Uint8List.fromList([7]);
      if (ending == 'final') {
        stream.add(ImageStreamChunk.complete(finalBytes));
        await pumpEventQueue();
        expect(harness.state.streamPreviewSlots.single.progress, 1);
      } else if (ending == 'failure') {
        stream.add(ImageStreamChunk.error('API_ERROR_500|failed'));
        await stream.close();
        await generation;
        expect(harness.state.status, GenerationStatus.error);
      } else {
        harness.notifier.cancel();
        expect(
          harness.state.history.single.bytes,
          same(harness.images.requests.single),
        );
      }
      if (ending == 'dispose') harness.container.dispose();
      final nextStream = StreamController<ImageStreamChunk>();
      Future<GenerationOutcome>? nextGeneration;
      if (ending == 'restart') {
        nextGeneration = harness.start(nextStream);
      }
      await pumpEventQueue();
      final before = ending == 'dispose' ? null : harness.state;
      expect(harness.images.listeners, 0);
      harness.images.complete(0);
      await pumpEventQueue();
      if (ending != 'dispose') expect(harness.state, same(before));
      expect(
        PaintingBinding.instance.imageCache
            .statusForKey(MemoryImage(harness.images.requests.single))
            .live,
        isFalse,
      );
      await stream.close();
      await generation;
      if (nextGeneration != null) {
        nextStream.add(ImageStreamChunk.complete(finalBytes));
        await nextStream.close();
        await nextGeneration;
      }
    });
  }

  testWidgets(
    'bad decode advances progress while retaining the previous image',
    (tester) async {
      final harness = await createHarness(tester);
      final stream = StreamController<ImageStreamChunk>();
      final generation = harness.start(stream);
      stream.add(_chunk(0.25));
      await tester.idle();
      final image = harness.images.complete(0);
      await tester.idle();
      await tester.pumpWidget(_app(harness.container));
      stream.add(_chunk(0.75));
      await tester.idle();
      harness.images.fail(1);
      await tester.idle();
      await tester.pump();
      expect(find.text('75%'), findsOneWidget);
      expect(harness.state.streamPreview, same(harness.images.requests[1]));
      expect(_painter(tester).previewImage!.isCloneOf(image), isTrue);
      expect(tester.binding.hasScheduledFrame, isFalse);
      harness.notifier.cancel();
      await stream.close();
      await generation;
      await tester.pump(Duration.zero);
    },
  );

  testWidgets(
    'completion hands the exact slot bytes to a new card first frame',
    (tester) async {
      final harness = await createHarness(tester);
      final stream = StreamController<ImageStreamChunk>();
      final generation = harness.start(stream);
      stream.add(_chunk(0.75));
      await tester.idle();
      final preview = harness.images.complete(0);
      await tester.idle();
      final bytes = harness.state.streamPreviewSlots.single.previewBytes!;
      final finalBytes = Uint8List.fromList([8]);
      harness.images.resolve(finalBytes);
      stream.add(ImageStreamChunk.complete(finalBytes));
      await stream.close();
      await generation;
      final completed = harness.state.currentImages.single;
      expect(
        harness.state.completionPreviews[completed.id]!.bytes,
        same(bytes),
      );
      await tester.pumpWidget(_app(harness.container));
      expect(find.byType(ImageCardStreamPreview), findsOneWidget);
      expect(_painter(tester).previewImage!.isCloneOf(preview), isTrue);
      expect(find.byType(TransparencyBackgroundLayer), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pump(Duration.zero);
    },
  );
}

ImageStreamChunk _chunk(
  double progress, {
  FocusedStreamPreviewPlacement? placement,
  int sampleIndex = 0,
}) => ImageStreamChunk.progress(
  progress: progress,
  sampleIndex: sampleIndex,
  previewImage: Uint8List.fromList([1]),
  focusedPreviewPlacement: placement,
);

Widget _app(ProviderContainer container) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(
    locale: const Locale('zh'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: Scaffold(
        body: Center(child: SizedBox.square(dimension: 160, child: _Card())),
      ),
    ),
  ),
);

class _Card extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGenerating = ref.watch(
      imageGenerationNotifierProvider.select((state) => state.isGenerating),
    );
    if (isGenerating) {
      return const HistoryStreamPreviewCard(
        generationIndex: 0,
        imageWidth: 512,
        imageHeight: 768,
      );
    }
    final (result, completionPreview) = ref.watch(
      imageGenerationNotifierProvider.select((state) {
        final result = state.currentImages.firstOrNull;
        return (result, state.completionPreviews[result?.id]);
      }),
    );
    return SelectableImageCard(
      key: ValueKey(result?.id ?? 'stream'),
      imageBytes: result?.bytes,
      completionPreview: completionPreview,
      imageWidth: 512,
      imageHeight: 768,
      enableSelection: false,
      hoverEffectsEnabled: false,
      shareWarmupEnabled: false,
    );
  }
}

ImageCardStreamPreviewPainter _painter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((widget) => widget.painter)
    .whereType<ImageCardStreamPreviewPainter>()
    .single;
