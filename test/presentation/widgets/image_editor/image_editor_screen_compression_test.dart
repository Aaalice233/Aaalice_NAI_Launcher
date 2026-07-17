import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'compression changes Focus request summary without resizing the work canvas',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ImageEditorScreen(
            initialSize: Size(2560, 1280),
            mode: ImageEditorMode.inpaint,
            existingFocusRect: Rect.fromLTWH(480, 240, 1600, 800),
            initialFocusedInpaintEnabled: true,
            initialMinimumContextMegaPixels: 88,
            focusedInpaintCostConfig: ImageEditorFocusedInpaintCostConfig(
              model: 'nai-diffusion-4-full',
              steps: 28,
              batchCount: 1,
              batchSize: 1,
              smea: false,
              smeaDyn: false,
              subscriptionTier: 3,
            ),
            title: 'Compression geometry test',
            initialShowLayerPanel: false,
          ),
        ),
      );
      await _pumpUntil(tester, () {
        final state = tester.state(find.byType(ImageEditorScreen)) as dynamic;
        return state.debugCompressionTargetCount > 1 &&
            find.textContaining('实际发送').evaluate().isNotEmpty;
      });

      final state = tester.state(find.byType(ImageEditorScreen)) as dynamic;
      final beforeSummary = _focusedSummaryText(tester);
      expect(state.debugCanvasSize, const Size(2560, 1280));
      expect(state.debugCompressionTargetSize, const Size(2560, 1280));

      state.debugSetCompressionTargetIndex(0);
      await tester.pump();

      expect(state.debugCanvasSize, const Size(2560, 1280));
      expect(state.debugCompressionTargetSize, const Size(1344, 640));
      expect(state.debugCompressionApplied, isTrue);
      expect(_focusedSummaryText(tester), isNot(beforeSummary));
    },
  );

  testWidgets('mask drawn before compression follows the inpaint source size', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ImageEditorResult? result;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<ImageEditorResult>(
                MaterialPageRoute(
                  builder: (_) => ImageEditorScreen(
                    initialImage: _buildSolidPng(1408, 704),
                    existingMask: _buildHalfMask(1408, 704),
                    mode: ImageEditorMode.inpaint,
                    title: 'Compressed inpaint export test',
                    initialShowLayerPanel: false,
                  ),
                ),
              );
            },
            child: const Text('Open editor'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open editor'));
    await _pumpUntil(tester, () {
      final editor = find.byType(ImageEditorScreen);
      if (editor.evaluate().isEmpty) return false;
      final state = tester.state(editor) as dynamic;
      return state.debugCanvasSize == const Size(1408, 704) &&
          state.debugHasMaskContent &&
          state.debugCompressionTargetCount == 2;
    });

    final state = tester.state(find.byType(ImageEditorScreen)) as dynamic;
    state.debugSetCompressionTargetIndex(0);
    await tester.pump();
    await tester.runAsync(() async {
      await state.debugExportAndClose();
    });
    await _pumpForAsyncEditorWork(tester);

    expect(result, isNotNull);
    expect(result!.compressionApplied, isTrue);
    expect((result!.outputWidth, result!.outputHeight), (1344, 640));
    expect(
      (result!.inpaintSourceWidth, result!.inpaintSourceHeight),
      (1344, 640),
    );
    final source = img.decodeImage(result!.inpaintSourceImage!);
    final mask = img.decodeImage(result!.maskImage!);
    expect((source!.width, source.height), (1344, 640));
    expect((mask!.width, mask.height), (1344, 640));
    expect(mask.getPixel(671, 320).r, 0);
    expect(mask.getPixel(672, 320).r, 255);
  });

  testWidgets('Edit mode exports the selected target in one final image', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ImageEditorResult? result;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<ImageEditorResult>(
                MaterialPageRoute(
                  builder: (_) => ImageEditorScreen(
                    initialImage: _buildSolidPng(1408, 704),
                    mode: ImageEditorMode.edit,
                    title: 'Compressed edit export test',
                    initialShowLayerPanel: false,
                    debugDisableDropRegion: true,
                  ),
                ),
              );
            },
            child: const Text('Open editor'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open editor'));
    await _pumpUntil(tester, () {
      final editor = find.byType(ImageEditorScreen);
      if (editor.evaluate().isEmpty) return false;
      final state = tester.state(editor) as dynamic;
      return state.debugCanvasSize == const Size(1408, 704) &&
          state.debugCompressionTargetCount == 2;
    });

    final state = tester.state(find.byType(ImageEditorScreen)) as dynamic;
    state.debugSetCompressionTargetIndex(0);
    await tester.pump();
    await tester.runAsync(() async {
      await state.debugExportAndClose();
    });
    await _pumpForAsyncEditorWork(tester);

    expect(result, isNotNull);
    expect(result!.hasImageChanges, isTrue);
    expect(result!.compressionApplied, isTrue);
    expect((result!.outputWidth, result!.outputHeight), (1344, 640));
    final decoded = img.decodeImage(result!.modifiedImage!);
    expect((decoded!.width, decoded.height), (1344, 640));
  });
}

String _focusedSummaryText(WidgetTester tester) {
  final text = tester.widget<Text>(
    find.byWidgetPredicate(
      (widget) => widget is Text && widget.data?.contains('实际发送') == true,
    ),
  );
  return text.data!;
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 20; i++) {
    if (condition()) return;
    await _pumpForAsyncEditorWork(tester);
  }
  expect(condition(), isTrue);
}

Future<void> _pumpForAsyncEditorWork(WidgetTester tester) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pump(const Duration(milliseconds: 50));
}

Uint8List _buildSolidPng(int width, int height) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(34, 68, 102, 255));
  return Uint8List.fromList(img.encodePng(image, level: 1));
}

Uint8List _buildHalfMask(int width, int height) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(0, 0, 0, 255));
  img.fillRect(
    image,
    x1: width ~/ 2,
    y1: 0,
    x2: width - 1,
    y2: height - 1,
    color: img.ColorRgba8(255, 255, 255, 255),
  );
  return Uint8List.fromList(img.encodePng(image, level: 1));
}
