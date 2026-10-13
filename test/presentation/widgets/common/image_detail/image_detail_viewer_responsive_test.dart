import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/horizontal_resize_handle.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/components/detail_metadata_panel.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/components/detail_thumbnail_bar.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/image_detail_data.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/image_detail_viewer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ui.Image readyImage;

  setUpAll(() => readyImage = _paintReadyImage());
  tearDownAll(() => readyImage.dispose());

  setUp(() => SharedPreferences.setMockInitialValues({}));
  // 用例不得依赖前序用例预热的全局 imageCache
  tearDown(
    () => imageCache
      ..clear()
      ..clearLiveImages(),
  );

  testWidgets(
    'single image adapts from compact to wide metadata presentation',
    (tester) async {
      final image = _TestImageData.ready('single', readyImage);

      for (final width in [360.0, 700.0, 900.0, 1200.0, 1600.0]) {
        await tester.binding.setSurfaceSize(Size(width, 700));
        await _pumpViewer(tester, images: [image]);
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('1 / 1'), findsOneWidget, reason: 'width=$width');
        expect(find.byType(DetailThumbnailBar), findsNothing);
        expect(
          find.byType(DetailMetadataPanel),
          width >= 1100 ? findsOneWidget : findsNothing,
          reason: 'width=$width',
        );
        expect(tester.takeException(), isNull, reason: 'width=$width');
      }

      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets(
    'wide metadata panel can be resized without squeezing the image',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpViewer(
        tester,
        images: [
          GeneratedImageDetailData(
            imageBytes: _validPngBytes,
            metadata: const NaiImageMetadata(
              source: 'NovelAI Diffusion V4.5 Full',
              prompt: '1girl, detailed background',
              seed: 123456789,
              steps: 28,
              width: 1024,
              height: 1024,
            ),
          ),
        ],
      );
      await tester.pump(const Duration(milliseconds: 200));

      final panel = find.byType(DetailMetadataPanel);
      final handle = find.byKey(
        const ValueKey('image-detail-metadata-resize-handle'),
      );
      final initialPanelWidth = tester.getSize(panel).width;

      expect(handle, findsOneWidget);
      expect(tester.getSize(handle).width, ResizeHandle.defaultWidth);
      expect(initialPanelWidth, 420);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: tester.getCenter(handle));
      await mouse.down(tester.getCenter(handle));
      await mouse.moveBy(const Offset(-80, 0));
      await mouse.up();
      await tester.pump();

      expect(tester.getSize(panel).width, closeTo(500, 0.01));
      expect(tester.getTopLeft(panel).dx, greaterThanOrEqualTo(480 + 8));

      await mouse.down(tester.getCenter(handle));
      await mouse.moveBy(const Offset(240, 0));
      await mouse.up();
      await tester.pump();

      expect(tester.getSize(panel).width, 320);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('three-times text scale keeps metadata action reachable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpViewer(
      tester,
      images: [_TestImageData.ready('scaled', readyImage)],
      textScaler: const TextScaler.linear(3),
    );
    await tester.pump();

    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact metadata action opens the adaptive panel', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpViewer(
      tester,
      images: [_TestImageData.ready('panel', readyImage)],
      textScaler: const TextScaler.linear(3),
    );
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(DetailMetadataPanel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('multiple images page with arrows, thumbnails, and keyboard', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(840, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final images = [
      _TestImageData.ready('first', readyImage),
      _TestImageData.ready('second', readyImage),
      _TestImageData.ready('third', readyImage),
    ];

    await _pumpViewer(tester, images: images);
    await tester.pump();

    expect(find.byType(DetailThumbnailBar), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(DetailThumbnailBar),
        matching: find.byKey(const ValueKey('third')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('paging settles once the pending page image finishes decoding', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(840, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pending = _PendingImageProvider();
    final images = [
      _TestImageData.pending('first', pending),
      _TestImageData.pending('second', pending),
    ];

    await _pumpViewer(tester, images: images);
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isTrue);

    pending.complete(readyImage);
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed image replaces loading state with explicit error', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpViewer(
      tester,
      images: [
        _TestImageData.encoded('broken', Uint8List.fromList([1, 2, 3])),
      ],
      showMetadataPanel: false,
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.broken_image), findsOneWidget);
    expect(find.text('Failed to load image'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('top-bar operations dispatch for the current page', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(840, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final saved = <String>[];
    final images = [
      _TestImageData.ready('one', readyImage),
      _TestImageData.ready('two', readyImage),
    ];

    await _pumpViewer(
      tester,
      images: images,
      callbacks: ImageDetailCallbacks(
        onSave: (image) async {
          saved.add(image.identifier);
        },
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.save_alt));
    await tester.pump();

    expect(saved, ['two']);
  });

  testWidgets('close action returns to the previous route', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final image = _TestImageData.ready('route', readyImage);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shortcutConfigNotifierProvider.overrideWith(
            _FakeShortcutConfigNotifier.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => ImageDetailViewer.showSingle(
                  context,
                  image: image,
                  showMetadataPanel: false,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(ImageDetailViewer), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(ImageDetailViewer), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}

Future<void> _pumpViewer(
  WidgetTester tester, {
  required List<ImageDetailData> images,
  ImageDetailCallbacks? callbacks,
  bool showMetadataPanel = true,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        shortcutConfigNotifierProvider.overrideWith(
          _FakeShortcutConfigNotifier.new,
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: ImageDetailViewer(
          images: images,
          callbacks: callbacks,
          showMetadataPanel: showMetadataPanel,
        ),
      ),
    ),
  );
}

final Uint8List _validPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

class _FakeShortcutConfigNotifier extends ShortcutConfigNotifier {
  @override
  Future<ShortcutConfig> build() async => ShortcutConfig.createDefault();
}

ui.Image _paintReadyImage() {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 1, 1),
    Paint()..color = const Color(0xFF808080),
  );
  final picture = recorder.endRecording();
  try {
    return picture.toImageSync(1, 1);
  } finally {
    picture.dispose();
  }
}

// fake zone 内 pump 不让出真实事件循环，引擎解码回调送不进来，图片必须同步就绪
class _ReadyImageProvider extends ImageProvider<_ReadyImageProvider> {
  _ReadyImageProvider(this.image);

  final ui.Image image;

  @override
  Future<_ReadyImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_ReadyImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _ReadyImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(
      SynchronousFuture<ImageInfo>(ImageInfo(image: image.clone())),
    );
  }
}

class _PendingImageProvider extends ImageProvider<_PendingImageProvider> {
  final List<_ManualImageStreamCompleter> _loads = [];
  ui.Image? _decoded;

  void complete(ui.Image image) {
    assert(_decoded == null, 'pending image completed twice');
    _decoded = image;
    for (final load in _loads) {
      load.deliver(ImageInfo(image: image.clone()));
    }
  }

  @override
  Future<_PendingImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_PendingImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _PendingImageProvider key,
    ImageDecoderCallback decode,
  ) {
    final load = _ManualImageStreamCompleter();
    final decoded = _decoded;
    if (decoded == null) {
      _loads.add(load);
    } else {
      load.deliver(ImageInfo(image: decoded.clone()));
    }
    return load;
  }
}

class _ManualImageStreamCompleter extends ImageStreamCompleter {
  void deliver(ImageInfo info) => setImage(info);
}

class _TestImageData implements ImageDetailData {
  _TestImageData._(this.identifier, this.bytes, this._provider);

  _TestImageData.ready(String identifier, ui.Image image)
    : this._(identifier, _validPngBytes, _ReadyImageProvider(image));

  _TestImageData.pending(String identifier, _PendingImageProvider provider)
    : this._(identifier, _validPngBytes, provider);

  _TestImageData.encoded(String identifier, Uint8List bytes)
    : this._(identifier, bytes, MemoryImage(bytes));

  final Uint8List bytes;
  final ImageProvider<Object> _provider;

  @override
  final String identifier;

  @override
  FileInfo? get fileInfo => null;

  @override
  ImageProvider<Object> getImageProvider() => _provider;

  @override
  Future<Uint8List> getImageBytes() async => bytes;

  @override
  bool get isFavorite => false;

  @override
  NaiImageMetadata? get metadata => null;

  @override
  bool get preserveOriginalBytesOnSave => true;

  @override
  bool get showCopyButton => false;

  @override
  bool get showSaveAsButton => false;

  @override
  bool get showFavoriteButton => false;

  @override
  bool get showSaveButton => true;
}
