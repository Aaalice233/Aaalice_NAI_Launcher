import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/canvas/editor_canvas.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('external image import creates an active image layer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ImageEditorScreen(
          initialImage: _buildSolidPng(32, 32, const Color(0xFF224466)),
          mode: ImageEditorMode.edit,
          title: 'Edit drop test',
          initialShowLayerPanel: false,
          debugDisableDropRegion: true,
        ),
      ),
    );
    await _pumpForAsyncEditorWork(tester);
    await _pumpUntil(tester, () {
      final state = tester.state(find.byType(ImageEditorScreen)) as dynamic;
      return List<String>.from(state.debugLayerNames).contains('底图') &&
          find.byType(EditorCanvas).evaluate().isNotEmpty;
    });

    final state = tester.state(find.byType(ImageEditorScreen)) as dynamic;
    final previousLayerNames = List<String>.from(state.debugLayerNames);
    final droppedImage = _buildSolidPng(12, 10, const Color(0xFF44AA66));

    await tester.runAsync(() async {
      await state.debugImportDroppedImageLayer('overlay.png', droppedImage);
    });
    await _pumpForAsyncEditorWork(tester);

    final layerNames = List<String>.from(state.debugLayerNames);
    expect(layerNames, hasLength(previousLayerNames.length + 1));
    expect(layerNames, contains('overlay.png'));
    expect(state.debugActiveLayerName, 'overlay.png');
    expect(state.debugActiveLayerHasBaseImage, isTrue);
    expect(
      layerNames.indexOf('overlay.png'),
      lessThan(layerNames.indexOf('底图')),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'external image import cover-crops mismatched image into canvas',
    (tester) async {
      ImageEditorResult? result;
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<ImageEditorResult>(
                    MaterialPageRoute(
                      builder: (context) => ImageEditorScreen(
                        initialImage: _buildSolidPng(
                          64,
                          64,
                          const Color(0xFF224466),
                        ),
                        mode: ImageEditorMode.edit,
                        title: 'Edit drop fit test',
                        initialShowLayerPanel: false,
                        debugDisableDropRegion: true,
                      ),
                    ),
                  );
                },
                child: const Text('Open editor'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open editor'));
      await _pumpForAsyncEditorWork(tester);
      await _pumpUntil(tester, () {
        final state = tester.state(find.byType(ImageEditorScreen)) as dynamic;
        return List<String>.from(state.debugLayerNames).contains('底图') &&
            find.byType(EditorCanvas).evaluate().isNotEmpty;
      });

      final state = tester.state(find.byType(ImageEditorScreen)) as dynamic;
      await tester.runAsync(() async {
        await state.debugImportDroppedImageLayer(
          'wide-bands.png',
          _buildHorizontalBandsPng(
            160,
            40,
            const Color(0xFFCC3311),
            const Color(0xFF22AA55),
            const Color(0xFF3355CC),
          ),
        );
        await state.debugExportAndClose();
      });
      await _pumpForAsyncEditorWork(tester);

      expect(result, isNotNull);
      final exported = img.decodeImage(result!.modifiedImage!);
      expect(exported, isNotNull);
      expect(exported!.width, 64);
      expect(exported.height, 64);
      expect(_hexAt(exported, 32, 2), 0xFF22AA55);
      expect(_hexAt(exported, 32, 32), 0xFF22AA55);
      expect(_hexAt(exported, 32, 62), 0xFF22AA55);
    },
  );
}

Future<void> _pumpForAsyncEditorWork(WidgetTester tester) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 10; i++) {
    if (condition()) {
      return;
    }
    await _pumpForAsyncEditorWork(tester);
  }
  expect(condition(), isTrue);
}

Uint8List _buildSolidPng(int width, int height, Color color) {
  final image = img.Image(width: width, height: height);
  img.fill(
    image,
    color: img.ColorRgba8(
      (color.r * 255).round().clamp(0, 255),
      (color.g * 255).round().clamp(0, 255),
      (color.b * 255).round().clamp(0, 255),
      (color.a * 255).round().clamp(0, 255),
    ),
  );
  return Uint8List.fromList(img.encodePng(image));
}

Uint8List _buildHorizontalBandsPng(
  int width,
  int height,
  Color left,
  Color center,
  Color right,
) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final color = x < width / 3
          ? left
          : x < width * 2 / 3
          ? center
          : right;
      image.setPixelRgba(
        x,
        y,
        (color.r * 255).round().clamp(0, 255),
        (color.g * 255).round().clamp(0, 255),
        (color.b * 255).round().clamp(0, 255),
        (color.a * 255).round().clamp(0, 255),
      );
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

int _hexAt(img.Image image, int x, int y) {
  final pixel = image.getPixel(x, y);
  return (pixel.a.toInt() << 24) |
      (pixel.r.toInt() << 16) |
      (pixel.g.toInt() << 8) |
      pixel.b.toInt();
}
