import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_generation_api_service.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/image/image_stream_chunk.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/generation/stream_preview_snapshot.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/notification_settings_provider.dart';

class MockNAIImageGenerationApiService extends Mock
    implements NAIImageGenerationApiService {}

class _AuthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.authenticated);
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
    hiveTempDir = await Directory.systemTemp.createTemp('nai_launcher_hive_');
    Hive.init(hiveTempDir.path);
    await Hive.openBox(StorageKeys.settingsBox);
    await Hive.openBox(StorageKeys.historyBox);
    await Hive.openBox(StorageKeys.statisticsCacheBox);
  });

  setUp(() async {
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

  group('StreamPreviewSnapshotStore', () {
    test('同一请求的多帧共用一次复制出的源图与蒙版', () {
      final store = StreamPreviewSnapshotStore();
      final source = _solidImageBytes(width: 8, height: 8, value: 30);
      final mask = _solidImageBytes(width: 8, height: 8, value: 90);
      final placement = _placement(source: source, mask: mask);

      store.remember(
        runId: 1,
        imageNumber: 1,
        bytes: _solidImageBytes(width: 4, height: 4, value: 1),
        params: const ImageParams(),
        placement: placement,
      );
      final snapshot = store.retainedSnapshot;
      final firstPlacement = store.preview(1, 1)!.focusedPreviewPlacement!;

      for (var frame = 2; frame <= 5; frame++) {
        store.remember(
          runId: 1,
          imageNumber: 1,
          bytes: _solidImageBytes(width: 4, height: 4, value: frame),
          params: const ImageParams(),
          placement: _placement(source: source, mask: mask),
        );
      }
      final lastPlacement = store.preview(1, 1)!.focusedPreviewPlacement!;

      expect(store.retainedSnapshot, same(snapshot));
      expect(lastPlacement, same(firstPlacement));
      expect(lastPlacement.sourceImage, isNot(same(source)));
      expect(lastPlacement.sourceImage, orderedEquals(source));
      expect(lastPlacement.maskImage, isNot(same(mask)));
      expect(lastPlacement.maskImage, orderedEquals(mask));
    });

    test('同一请求的多张图共用同一份快照', () {
      final store = StreamPreviewSnapshotStore();
      final source = _solidImageBytes(width: 8, height: 8, value: 30);
      final bytes = _solidImageBytes(width: 4, height: 4, value: 1);

      store.remember(
        runId: 1,
        imageNumber: 1,
        bytes: bytes,
        params: const ImageParams(),
        placement: _placement(source: source),
      );
      store.remember(
        runId: 1,
        imageNumber: 2,
        bytes: bytes,
        params: const ImageParams(),
        placement: _placement(source: source),
      );

      expect(
        store.preview(1, 2)!.focusedPreviewPlacement!.sourceImage,
        same(store.preview(1, 1)!.focusedPreviewPlacement!.sourceImage),
      );
    });

    test('源缓冲换成新对象时重建快照', () {
      final store = StreamPreviewSnapshotStore();
      final first = _solidImageBytes(width: 8, height: 8, value: 30);
      final second = Uint8List.fromList(first);
      final bytes = _solidImageBytes(width: 4, height: 4, value: 1);

      store.remember(
        runId: 1,
        imageNumber: 1,
        bytes: bytes,
        params: const ImageParams(),
        placement: _placement(source: first),
      );
      final firstSnapshot = store.retainedSnapshot;
      store.remember(
        runId: 1,
        imageNumber: 1,
        bytes: bytes,
        params: const ImageParams(),
        placement: _placement(source: second),
      );

      expect(store.retainedSnapshot, isNot(same(firstSnapshot)));
    });

    test('不同 run 不共用快照', () {
      final store = StreamPreviewSnapshotStore();
      final source = _solidImageBytes(width: 8, height: 8, value: 30);
      final placement = _placement(source: source);
      final bytes = _solidImageBytes(width: 4, height: 4, value: 1);

      store.remember(
        runId: 1,
        imageNumber: 1,
        bytes: bytes,
        params: const ImageParams(),
        placement: placement,
      );
      store.remember(
        runId: 2,
        imageNumber: 1,
        bytes: bytes,
        params: const ImageParams(),
        placement: placement,
      );

      final firstRun = store.preview(1, 1)!.focusedPreviewPlacement!;
      final secondRun = store.preview(2, 1)!.focusedPreviewPlacement!;
      expect(secondRun.sourceImage, isNot(same(firstRun.sourceImage)));
      expect(secondRun.sourceImage, orderedEquals(firstRun.sourceImage));
    });

    test('帧全部释放后快照随之释放', () {
      final store = StreamPreviewSnapshotStore();
      final source = _solidImageBytes(width: 8, height: 8, value: 30);
      final bytes = _solidImageBytes(width: 4, height: 4, value: 1);

      store.remember(
        runId: 1,
        imageNumber: 1,
        bytes: bytes,
        params: const ImageParams(),
        placement: _placement(source: source),
      );
      store.remember(
        runId: 1,
        imageNumber: 2,
        bytes: bytes,
        params: const ImageParams(),
        placement: _placement(source: source),
      );
      final released = store
          .preview(1, 1)!
          .focusedPreviewPlacement!
          .sourceImage;

      store.release(1, 1);
      expect(store.isEmpty, isFalse);
      expect(store.retainedSnapshot, isNotNull);

      store.release(1, 2);
      expect(store.isEmpty, isTrue);
      expect(store.retainedSnapshot, isNull);
      expect(store.preview(1, 1), isNull);

      store.remember(
        runId: 1,
        imageNumber: 1,
        bytes: bytes,
        params: const ImageParams(),
        placement: _placement(source: source),
      );
      expect(
        store.preview(1, 1)!.focusedPreviewPlacement!.sourceImage,
        isNot(same(released)),
      );
    });

    test('clear 释放全部帧与快照', () {
      final store = StreamPreviewSnapshotStore();
      store.remember(
        runId: 1,
        imageNumber: 1,
        bytes: _solidImageBytes(width: 4, height: 4, value: 1),
        params: const ImageParams(),
        placement: _placement(
          source: _solidImageBytes(width: 8, height: 8, value: 30),
        ),
      );

      store.clear();

      expect(store.isEmpty, isTrue);
      expect(store.retainedSnapshot, isNull);
    });

    test('空预览帧不被保留', () {
      final store = StreamPreviewSnapshotStore();
      store.remember(
        runId: 1,
        imageNumber: 1,
        bytes: Uint8List(0),
        params: const ImageParams(),
        placement: _placement(
          source: _solidImageBytes(width: 8, height: 8, value: 30),
        ),
      );

      expect(store.preview(1, 1), isNull);
      expect(store.retainedSnapshot, isNull);
    });
  });

  test('取消生成的历史快照不受预览后原始源缓冲改动影响', () async {
    final mockApiService = MockNAIImageGenerationApiService();
    final stream = StreamController<ImageStreamChunk>();
    var streamCall = 0;
    final source = _rgbImageBytes(
      width: 256,
      height: 256,
      red: 10,
      green: 20,
      blue: 30,
    );
    final preview = _rgbImageBytes(
      width: 128,
      height: 128,
      red: 200,
      green: 210,
      blue: 220,
    );
    final compositeMask = img.Image(width: 128, height: 128, numChannels: 4);
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
    final mask = Uint8List.fromList(img.encodePng(compositeMask));
    final placement = FocusedStreamPreviewPlacement(
      sourceImage: source,
      maskImage: mask,
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
    ).thenAnswer((_) {
      streamCall += 1;
      return stream.stream;
    });
    when(() => mockApiService.cancelGeneration(any())).thenReturn(null);

    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(_AuthenticatedAuthNotifier.new),
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
    final params = container
        .read(generationParamsNotifierProvider)
        .copyWith(
          prompt: 'snapshot reuse',
          action: ImageGenerationAction.infill,
          model: 'nai-diffusion-4-5-full-inpainting',
          width: 256,
          height: 256,
          sourceImage: source,
          maskImage: Uint8List.fromList(img.encodePng(rawMask)),
        );

    final generation = notifier.generate(params);
    await _pumpUntil(
      () => streamCall == 1,
      reason: 'stream request was not started',
    );
    stream.add(
      ImageStreamChunk.progress(
        progress: 0.5,
        currentStep: 14,
        totalSteps: 28,
        previewImage: preview,
        focusedPreviewPlacement: placement,
      ),
    );
    await _pumpUntil(
      () => container.read(imageGenerationNotifierProvider).hasStreamPreview,
      reason: 'stream preview was not published before cancellation',
    );

    source.fillRange(0, source.length, 0);
    mask.fillRange(0, mask.length, 0);

    notifier.cancel();
    await stream.close();
    await generation;

    final state = container.read(imageGenerationNotifierProvider);
    expect(state.status, GenerationStatus.cancelled);
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
}

FocusedStreamPreviewPlacement _placement({
  required Uint8List source,
  Uint8List? mask,
}) {
  return FocusedStreamPreviewPlacement(
    sourceImage: source,
    maskImage: mask,
    xPercent: 0.25,
    yPercent: 0.25,
    widthPercent: 0.5,
    heightPercent: 0.5,
  );
}

Uint8List _solidImageBytes({
  required int width,
  required int height,
  required int value,
}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(value, value, value));
  return Uint8List.fromList(img.encodePng(image));
}

Uint8List _rgbImageBytes({
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
