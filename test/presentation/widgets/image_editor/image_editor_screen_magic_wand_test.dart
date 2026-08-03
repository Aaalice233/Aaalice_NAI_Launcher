import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/contiguous_region_selector.dart';
import 'package:nai_launcher/core/utils/inpaint_mask_utils.dart';
import 'package:nai_launcher/data/services/efficient_vit_sam_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/canvas/editor_canvas.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Magic Wand erases a contiguous region to transparency', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ImageEditorResult? result;

    await _openEditor(
      tester,
      mode: ImageEditorMode.edit,
      image: _buildTwoColorPng(),
      onResult: (value) => result = value,
    );

    final state = tester.state(find.byType(ImageEditorScreen)) as dynamic;
    state.debugSetToolById('magic_wand');
    expect(state.debugCurrentToolId, 'magic_wand');

    await tester.runAsync(() async {
      await state.debugApplyMagicWand(const Offset(16, 16), tolerance: 0);
    });
    await tester.pump();

    expect(state.debugUndo(), isTrue);
    await tester.runAsync(() async {
      await state.debugApplyMagicWand(const Offset(16, 16), tolerance: 0);
      await state.debugExportAndClose();
    });
    await _pumpUntil(tester, () => result != null);

    expect(result!.hasImageChanges, isTrue);
    final output = img.decodeImage(result!.modifiedImage!);
    expect(output, isNotNull);
    expect(output!.getPixel(16, 16).a.toInt(), 0);
    expect(output.getPixel(96, 16).a.toInt(), 255);
  });

  testWidgets('Magic Wand adds a contiguous region to the inpaint mask', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ImageEditorResult? result;

    await _openEditor(
      tester,
      mode: ImageEditorMode.inpaint,
      image: _buildTwoColorPng(),
      onResult: (value) => result = value,
    );

    final state = tester.state(find.byType(ImageEditorScreen)) as dynamic;
    state.debugSetToolById('magic_wand');
    expect(state.debugCurrentToolId, 'magic_wand');

    await tester.runAsync(() async {
      await state.debugApplyMagicWand(const Offset(16, 16), tolerance: 0);
    });
    await tester.pump();

    expect(state.debugHasMaskContent, isTrue);
    expect(state.debugUndo(), isTrue);
    expect(state.debugHasMaskContent, isFalse);

    await tester.runAsync(() async {
      await state.debugApplyMagicWand(const Offset(16, 16), tolerance: 0);
      await state.debugExportAndClose();
    });
    await _pumpUntil(tester, () => result != null);

    expect(result!.hasMaskChanges, isTrue);
    final mask = InpaintMaskUtils.decodeBinaryMask(result!.maskImage!);
    expect(mask, isNotNull);
    expect(mask!.mask[16 * mask.width + 16], 1);
    expect(mask.mask[16 * mask.width + 96], 0);
  });

  testWidgets('Smart Magic Wand uses EfficientViT selection for editing', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ImageEditorResult? result;
    var selectorCalls = 0;
    final progressStages = <EfficientVitSamProgressStage>[];

    await _openEditor(
      tester,
      mode: ImageEditorMode.edit,
      image: _buildTwoColorPng(),
      smartSelector:
          ({
            required rgba,
            required width,
            required height,
            required startX,
            required startY,
            required invert,
            onProgress,
          }) async {
            selectorCalls++;
            onProgress?.call(
              const EfficientVitSamProgress(
                EfficientVitSamProgressStage.encodingImage,
              ),
            );
            progressStages.add(EfficientVitSamProgressStage.encodingImage);
            final mask = Uint8List(width * height);
            for (var y = 0; y < height; y++) {
              for (var x = 0; x < width ~/ 2; x++) {
                mask[y * width + x] = invert ? 0 : 1;
              }
            }
            if (invert) {
              for (var index = 0; index < mask.length; index++) {
                mask[index] = mask[index] == 0 ? 1 : 0;
              }
            }
            return ContiguousRegionSelection(
              mask: mask,
              width: width,
              height: height,
              selectedPixelCount: mask.where((value) => value == 1).length,
            );
          },
      onResult: (value) => result = value,
    );

    final state = tester.state(find.byType(ImageEditorScreen)) as dynamic;
    await tester.runAsync(() async {
      await state.debugApplyMagicWand(
        const Offset(16, 16),
        mode: MagicWandSelectionMode.smartObject,
      );
      await state.debugExportAndClose();
    });
    await _pumpUntil(tester, () => result != null);

    expect(selectorCalls, 1);
    expect(progressStages, <EfficientVitSamProgressStage>[
      EfficientVitSamProgressStage.encodingImage,
    ]);
    final output = img.decodeImage(result!.modifiedImage!);
    expect(output, isNotNull);
    expect(output!.getPixel(16, 16).a.toInt(), 0);
    expect(output.getPixel(96, 16).a.toInt(), 255);
  });
}

Future<void> _openEditor(
  WidgetTester tester, {
  required ImageEditorMode mode,
  required Uint8List image,
  required ValueChanged<ImageEditorResult?> onResult,
  EfficientVitSamSelector? smartSelector,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            onResult(
              await Navigator.of(context).push<ImageEditorResult>(
                MaterialPageRoute(
                  builder: (_) => ImageEditorScreen(
                    initialImage: image,
                    mode: mode,
                    title: 'Magic Wand test',
                    initialShowLayerPanel: false,
                    debugDisableDropRegion: true,
                    debugEfficientVitSamSelector: smartSelector,
                  ),
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
    if (find.byType(ImageEditorScreen).evaluate().isEmpty) {
      return false;
    }
    final state = tester.state(find.byType(ImageEditorScreen)) as dynamic;
    return state.debugCanvasSize == const Size(128, 128) &&
        (state.debugLayerNames as List<String>).length >= 2 &&
        find.byType(EditorCanvas).evaluate().isNotEmpty;
  });
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 20; i++) {
    if (condition()) {
      return;
    }
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(condition(), isTrue);
}

Uint8List _buildTwoColorPng() {
  final image = img.Image(width: 128, height: 128, numChannels: 4);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      if (x < 64) {
        image.setPixelRgba(x, y, 220, 40, 40, 255);
      } else {
        image.setPixelRgba(x, y, 40, 80, 220, 255);
      }
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}
