import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/derivatives/derivative_editor_launcher.dart';
import 'package:nai_launcher/presentation/screens/mosaic/mosaic_editor_launcher.dart';
import 'package:nai_launcher/presentation/screens/mosaic/mosaic_editor_screen.dart';
import 'package:nai_launcher/presentation/screens/watermark/watermark_editor_launcher.dart';
import 'package:nai_launcher/presentation/screens/watermark/watermark_editor_screen.dart';
import 'package:path/path.dart' as p;

typedef _Variant = ({
  String name,
  Type screen,
  double dialogWidth,
  String derivativeSuffix,
  String sourceMissingTitle,
  String? sourceMissingHint,
  Future<String?> Function(BuildContext context, Uint8List bytes) open,
  Future<String?> Function(BuildContext context, String path) openForLocalPath,
});

final _variants = <_Variant>[
  (
    name: 'mosaic',
    screen: MosaicEditorScreen,
    dialogWidth: 1320,
    derivativeSuffix: '_redacted',
    sourceMissingTitle: 'Original image not found',
    sourceMissingHint:
        'This appears to be a redacted derivative, but its original image is '
        'unavailable. Choose the original manually to avoid stacking effects.',
    open: (context, bytes) => MosaicEditorLauncher.open(
      context: context,
      sourceBytes: bytes,
      sourceFileName: 'source.png',
    ),
    openForLocalPath: (context, path) =>
        MosaicEditorLauncher.openForLocalPath(context: context, path: path),
  ),
  (
    name: 'watermark',
    screen: WatermarkEditorScreen,
    dialogWidth: 960,
    derivativeSuffix: '_watermarked',
    sourceMissingTitle:
        'The original image is missing. Choose it again to recreate the '
        'watermark.',
    sourceMissingHint: null,
    open: (context, bytes) => WatermarkEditorLauncher.open(
      context: context,
      sourceBytes: bytes,
      sourceFileName: 'source.png',
    ),
    openForLocalPath: (context, path) =>
        WatermarkEditorLauncher.openForLocalPath(context: context, path: path),
  ),
];

void main() {
  late Directory directory;
  late LocalStorageService storage;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('derivative-launcher-');
    Hive.init(directory.path);
    await Hive.openBox<dynamic>(StorageKeys.settingsBox, bytes: Uint8List(0));
    storage = LocalStorageService();
  });

  setUp(() => Hive.box<dynamic>(StorageKeys.settingsBox).clear());

  tearDownAll(() async {
    await Hive.close().timeout(const Duration(seconds: 10));
    await directory.delete(recursive: true);
  });

  for (final variant in _variants) {
    testWidgets('${variant.name} editor uses the shared adaptive surfaces', (
      tester,
    ) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final scenario in <({double width, String surfaceKey})>[
        (width: 320, surfaceKey: 'adaptive-bottom-sheet'),
        (width: 700, surfaceKey: 'adaptive-centered-form'),
        (width: 1600, surfaceKey: 'adaptive-centered-form'),
      ]) {
        await tester.binding.setSurfaceSize(Size(scenario.width, 900));
        await tester.pumpWidget(
          _host(
            storage: storage,
            key: ValueKey(scenario.width),
            size: Size(scenario.width, 900),
            onPressed: (context) => variant.open(context, _pngBytes(480, 320)),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final surface = find.byKey(ValueKey(scenario.surfaceKey));
        expect(surface, findsOneWidget, reason: '${scenario.width}');
        expect(find.byType(variant.screen), findsOneWidget);
        expect(find.byType(Dialog), findsNothing);
        if (scenario.surfaceKey == 'adaptive-centered-form') {
          expect(
            tester.getSize(surface).width,
            lessThanOrEqualTo(variant.dialogWidth),
          );
          expect(tester.getSize(surface).width, lessThan(scenario.width));
        }
        expect(tester.takeException(), isNull);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 5),
        );
        expect(surface, findsNothing);
      }
    });

    testWidgets('${variant.name} editor stays inside a compact safe area', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(
        top: 24,
        bottom: 16,
        left: 8,
        right: 8,
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(
        _host(
          storage: storage,
          textScale: 2,
          onPressed: (context) => variant.open(context, _pngBytes(480, 320)),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final rect = tester.getRect(
        find.byKey(const ValueKey('adaptive-bottom-sheet')),
      );
      expect(find.byType(Dialog), findsNothing);
      expect(rect.left, greaterThanOrEqualTo(8));
      expect(rect.top, greaterThanOrEqualTo(24));
      expect(rect.right, lessThanOrEqualTo(352));
      expect(rect.bottom, lessThanOrEqualTo(420));
      expect(tester.takeException(), isNull);
    });

    testWidgets('${variant.name} derivative without a link asks for the '
        'original', (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var opened = false;
      String? result = 'pending';

      await tester.pumpWidget(
        _host(
          storage: storage,
          size: const Size(900, 760),
          onPressed: (context) async {
            opened = true;
            result = await variant.openForLocalPath(
              context,
              p.join(directory.path, 'orphan${variant.derivativeSuffix}.png'),
            );
          },
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(opened, isTrue);
      expect(find.text(variant.sourceMissingTitle), findsOneWidget);
      expect(find.text('Choose original image'), findsOneWidget);
      final hint = variant.sourceMissingHint;
      expect(
        find.text(hint ?? variant.sourceMissingTitle),
        findsOneWidget,
        reason: 'hint visibility',
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );

      expect(result, isNull);
      expect(find.byType(variant.screen), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  test('sample image releases its picture and raster image', () async {
    final counters = _RasterCounters()..install();
    addTearDown(counters.restore);

    final bytes = await DerivativeEditorLauncher.buildSampleImage(
      (canvas, size) => canvas.drawRect(ui.Offset.zero & size, ui.Paint()),
      size: const ui.Size(16, 12),
    );

    expect(bytes, isNotEmpty);
    expect(counters.picturesCreated, greaterThan(0));
    expect(counters.picturesAlive, 0);
    expect(counters.imagesCreated, greaterThan(0));
    expect(counters.imagesAlive, 0);
  });

  test('sample image releases its picture when rasterization fails', () async {
    final counters = _RasterCounters()..install();
    addTearDown(counters.restore);

    await expectLater(
      DerivativeEditorLauncher.buildSampleImage(
        (canvas, size) => canvas.drawPaint(ui.Paint()),
        size: ui.Size.zero,
      ),
      throwsA(isA<Exception>()),
    );

    expect(counters.picturesCreated, greaterThan(0));
    expect(counters.picturesAlive, 0);
    expect(counters.imagesAlive, 0);
  });
}

class _RasterCounters {
  int picturesCreated = 0;
  int picturesAlive = 0;
  int imagesCreated = 0;
  int imagesAlive = 0;

  ui.PictureEventCallback? _previousPictureCreate;
  ui.PictureEventCallback? _previousPictureDispose;
  ui.ImageEventCallback? _previousImageCreate;
  ui.ImageEventCallback? _previousImageDispose;

  void install() {
    _previousPictureCreate = ui.Picture.onCreate;
    _previousPictureDispose = ui.Picture.onDispose;
    _previousImageCreate = ui.Image.onCreate;
    _previousImageDispose = ui.Image.onDispose;
    ui.Picture.onCreate = (_) {
      picturesCreated++;
      picturesAlive++;
    };
    ui.Picture.onDispose = (_) => picturesAlive--;
    ui.Image.onCreate = (_) {
      imagesCreated++;
      imagesAlive++;
    };
    ui.Image.onDispose = (_) => imagesAlive--;
  }

  void restore() {
    ui.Picture.onCreate = _previousPictureCreate;
    ui.Picture.onDispose = _previousPictureDispose;
    ui.Image.onCreate = _previousImageCreate;
    ui.Image.onDispose = _previousImageDispose;
  }
}

Widget _host({
  required LocalStorageService storage,
  required Future<void> Function(BuildContext context) onPressed,
  Key? key,
  Size? size,
  double textScale = 1,
}) {
  return ProviderScope(
    overrides: [localStorageServiceProvider.overrideWithValue(storage)],
    child: MaterialApp(
      key: key,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        final data = MediaQuery.of(context);
        return MediaQuery(
          data: data.copyWith(
            size: size ?? data.size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        );
      },
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () => onPressed(context),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

Uint8List _pngBytes(int width, int height) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(35, 48, 70, 255));
  return Uint8List.fromList(img.encodePng(image));
}
