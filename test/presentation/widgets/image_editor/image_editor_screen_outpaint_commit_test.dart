import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/inpaint_outpaint_utils.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/canvas/editor_canvas.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('desktop Save and Close is disabled during outpaint commit', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ImageEditorScreen(
          initialSize: Size(128, 96),
          mode: ImageEditorMode.inpaint,
          title: 'Inpaint test',
          initialOutpaintCommitPending: true,
          initialShowLayerPanel: false,
        ),
      ),
    );
    await tester.pump();

    final saveButton = find.ancestor(
      of: find.text('完成'),
      matching: find.byType(FilledButton),
    );
    expect(saveButton, findsOneWidget);
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);

    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'outpaint drag commit updates virtual state without pending commit',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ImageEditorScreen(
            initialImage: _buildSolidPng(128, 128, const Color(0xFFAA3322)),
            mode: ImageEditorMode.inpaint,
            title: 'Inpaint test',
            initialShowLayerPanel: false,
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
      expect(state.debugCanvasSize, const Size(128, 128));
      expect(state.debugOutpaintCommitPending, isFalse);
      expect(state.debugHasOutpaintChanges, isFalse);
      expect(state.debugVirtualOutpaintMaskRects, isEmpty);

      final rightEdge = find.byKey(const Key('outpaint_edge_right'));
      expect(rightEdge, findsOneWidget);
      final edgeRect = tester.getRect(rightEdge);
      final outwardBy64 =
          (state.debugCanvasToScreen(const Offset(192, 64)) as Offset) -
          (state.debugCanvasToScreen(const Offset(128, 64)) as Offset);

      final gesture = await tester.startGesture(
        edgeRect.center,
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryButton,
      );
      await tester.pump();
      await gesture.moveBy(outwardBy64);
      await tester.pump();
      await gesture.up();
      await _pumpUntil(
        tester,
        () => state.debugCanvasSize == const Size(192, 128),
      );

      expect(state.debugOutpaintCommitPending, isFalse);
      expect(state.debugCanvasSize, const Size(192, 128));
      expect(state.debugOutpaintSourceWidth, 192);
      expect(state.debugOutpaintSourceHeight, 128);
      expect(state.debugHasOutpaintChanges, isTrue);
      expect(
        state.debugVirtualOutpaintMaskRects,
        contains(const Rect.fromLTRB(127, 0, 192, 128)),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('Save and Close materializes virtual outpaint source and mask', (
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
          builder: (context) {
            return TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<ImageEditorResult>(
                  MaterialPageRoute(
                    builder: (context) => ImageEditorScreen(
                      initialImage: _buildSolidPng(
                        128,
                        128,
                        const Color(0xFFAA3322),
                      ),
                      mode: ImageEditorMode.inpaint,
                      title: 'Inpaint test',
                      initialShowLayerPanel: false,
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
    expect(state.debugCanvasSize, const Size(128, 128));
    expect(state.debugHasMaskContent, isFalse);
    expect(state.debugVirtualOutpaintMaskRects, isEmpty);

    await tester.runAsync(() async {
      await state.debugApplyOutpaintFrameDelta(
        const OutpaintFrameDelta(right: 33),
      );
    });
    await _pumpUntil(
      tester,
      () => state.debugCanvasSize == const Size(192, 128),
    );

    expect(state.debugHasMaskContent, isFalse);
    expect(state.debugHasOutpaintChanges, isTrue);
    expect(
      state.debugVirtualOutpaintMaskRects,
      contains(const Rect.fromLTRB(127, 0, 192, 128)),
    );

    await tester.runAsync(() async {
      await state.debugExportAndClose();
    });
    await _pumpForAsyncEditorWork(tester);

    expect(result, isNotNull);
    expect(result!.hasOutpaintChanges, isTrue);
    expect(result!.outpaintSourceImage, isNotNull);
    expect(result!.outpaintSourceWidth, 192);
    expect(result!.outpaintSourceHeight, 128);
    expect(result!.maskImage, isNotNull);

    final sourceImage = img.decodeImage(result!.outpaintSourceImage!);
    expect(sourceImage, isNotNull);
    expect(sourceImage!.width, 192);
    expect(sourceImage.height, 128);

    final maskImage = img.decodeImage(result!.maskImage!);
    expect(maskImage, isNotNull);
    expect(maskImage!.width, 192);
    expect(maskImage.height, 128);

    final outpaintPixel = maskImage.getPixel(160, 64);
    expect(outpaintPixel.r, greaterThan(240));
    expect(outpaintPixel.g, greaterThan(240));
    expect(outpaintPixel.b, greaterThan(240));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'Save and Close returns crop-only virtual outpaint source without mask',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      ImageEditorResult? result;

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
                          128,
                          128,
                          const Color(0xFFAA3322),
                        ),
                        mode: ImageEditorMode.inpaint,
                        title: 'Inpaint test',
                        initialShowLayerPanel: false,
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
      expect(state.debugCanvasSize, const Size(128, 128));
      expect(state.debugHasMaskContent, isFalse);
      expect(state.debugVirtualOutpaintMaskRects, isEmpty);

      await tester.runAsync(() async {
        await state.debugApplyOutpaintFrameDelta(
          const OutpaintFrameDelta(right: -33),
        );
      });
      await _pumpUntil(
        tester,
        () => state.debugCanvasSize == const Size(64, 128),
      );

      expect(state.debugHasMaskContent, isFalse);
      expect(state.debugHasOutpaintChanges, isTrue);
      expect(state.debugOutpaintSourceWidth, 64);
      expect(state.debugOutpaintSourceHeight, 128);
      expect(state.debugVirtualOutpaintMaskRects, isEmpty);

      await tester.runAsync(() async {
        await state.debugExportAndClose();
      });
      await _pumpForAsyncEditorWork(tester);

      expect(result, isNotNull);
      expect(result!.hasOutpaintChanges, isTrue);
      expect(result!.hasMaskChanges, isFalse);
      expect(result!.maskImage, isNull);
      expect(result!.outpaintSourceImage, isNotNull);
      expect(result!.outpaintSourceWidth, 64);
      expect(result!.outpaintSourceHeight, 128);

      final sourceImage = img.decodeImage(result!.outpaintSourceImage!);
      expect(sourceImage, isNotNull);
      expect(sourceImage!.width, 64);
      expect(sourceImage.height, 128);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'outpaint source replacement failure rolls back screen transaction',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ImageEditorScreen(
            initialImage: _buildSolidPng(128, 96, const Color(0xFFAA3322)),
            mode: ImageEditorMode.inpaint,
            title: 'Inpaint test',
            initialShowLayerPanel: false,
            debugFailOutpaintSourceReplacement: true,
          ),
        ),
      );
      await _pumpForAsyncEditorWork(tester);
      await _pumpUntil(tester, () {
        final state = tester.state(find.byType(ImageEditorScreen)) as dynamic;
        return List<String>.from(state.debugLayerNames).contains('底图');
      });

      final state = tester.state(find.byType(ImageEditorScreen)) as dynamic;
      final previousLayerNames = List<String>.from(state.debugLayerNames);

      expect(state.debugCanvasSize, const Size(128, 128));
      expect(state.debugFocusedInpaintEnabled, isFalse);
      expect(state.debugHasOutpaintChanges, isFalse);
      expect(state.debugOutpaintSourceWidth, isNull);
      expect(state.debugOutpaintSourceHeight, isNull);

      await tester.runAsync(() async {
        await state.debugApplyOutpaintFrameDeltaMaterialized(
          const OutpaintFrameDelta(right: 32),
        );
      });
      await _pumpForAsyncEditorWork(tester);

      expect(state.debugCanvasSize, const Size(128, 128));
      expect(state.debugFocusedInpaintEnabled, isFalse);
      expect(state.debugHasOutpaintChanges, isFalse);
      expect(state.debugOutpaintSourceWidth, isNull);
      expect(state.debugOutpaintSourceHeight, isNull);
      expect(state.debugLayerNames, previousLayerNames);
      expect(state.debugLayerNames.where((name) => name == '蒙版'), isEmpty);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'outpaint source replacement failure does not disable focused inpaint',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ImageEditorScreen(
            initialImage: _buildSolidPng(128, 96, const Color(0xFFAA3322)),
            existingFocusRect: const Rect.fromLTWH(16, 16, 48, 48),
            mode: ImageEditorMode.inpaint,
            title: 'Inpaint test',
            initialShowLayerPanel: false,
            debugFailOutpaintSourceReplacement: true,
          ),
        ),
      );
      await _pumpForAsyncEditorWork(tester);
      await _pumpUntil(tester, () {
        final state = tester.state(find.byType(ImageEditorScreen)) as dynamic;
        return List<String>.from(state.debugLayerNames).contains('底图');
      });

      final state = tester.state(find.byType(ImageEditorScreen)) as dynamic;
      final previousLayerNames = List<String>.from(state.debugLayerNames);

      expect(state.debugCanvasSize, const Size(128, 128));
      expect(state.debugFocusedInpaintEnabled, isTrue);

      await tester.runAsync(() async {
        await state.debugApplyOutpaintFrameDeltaMaterialized(
          const OutpaintFrameDelta(right: 32),
        );
      });
      await _pumpForAsyncEditorWork(tester);

      expect(state.debugCanvasSize, const Size(128, 128));
      expect(state.debugFocusedInpaintEnabled, isTrue);
      expect(state.debugHasOutpaintChanges, isFalse);
      expect(state.debugOutpaintSourceWidth, isNull);
      expect(state.debugOutpaintSourceHeight, isNull);
      expect(state.debugLayerNames, previousLayerNames);
      expect(state.debugLayerNames.where((name) => name == '蒙版'), isEmpty);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'later outpaint failure restores focused state, tool, selection and layers',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ImageEditorScreen(
            initialImage: _buildSolidPng(128, 96, const Color(0xFFAA3322)),
            initialFocusedInpaintEnabled: true,
            mode: ImageEditorMode.inpaint,
            title: 'Inpaint test',
            initialShowLayerPanel: false,
            debugFailOutpaintAfterFocusedDisable: true,
          ),
        ),
      );
      await _pumpForAsyncEditorWork(tester);
      await _pumpUntil(tester, () {
        final state = tester.state(find.byType(ImageEditorScreen)) as dynamic;
        return List<String>.from(state.debugLayerNames).contains('底图');
      });

      final state = tester.state(find.byType(ImageEditorScreen)) as dynamic;
      state.debugSetToolById('brush');
      state.debugSetSelectionRect(const Rect.fromLTWH(12, 14, 30, 32));
      state.debugSetPreviewRect(const Rect.fromLTWH(20, 22, 36, 38));
      state.debugSetToolById('rect_selection');
      await tester.pump();

      final previousLayerNames = List<String>.from(state.debugLayerNames);
      final previousActiveLayerId = state.debugActiveLayerId as String?;
      final previousActiveLayerName = state.debugActiveLayerName as String?;

      expect(state.debugCanvasSize, const Size(128, 128));
      expect(state.debugFocusedInpaintEnabled, isTrue);
      expect(state.debugCurrentToolId, 'rect_selection');
      expect(state.debugSelectionBounds, const Rect.fromLTWH(12, 14, 30, 32));
      expect(state.debugPreviewBounds, const Rect.fromLTWH(20, 22, 36, 38));

      await tester.runAsync(() async {
        await state.debugApplyOutpaintFrameDeltaMaterialized(
          const OutpaintFrameDelta(right: 32),
        );
      });
      await _pumpForAsyncEditorWork(tester);

      expect(state.debugCanvasSize, const Size(128, 128));
      expect(state.debugFocusedInpaintEnabled, isTrue);
      expect(state.debugCurrentToolId, 'rect_selection');
      expect(state.debugSelectionBounds, const Rect.fromLTWH(12, 14, 30, 32));
      expect(state.debugPreviewBounds, const Rect.fromLTWH(20, 22, 36, 38));
      expect(state.debugHasOutpaintChanges, isFalse);
      expect(state.debugOutpaintSourceWidth, isNull);
      expect(state.debugOutpaintSourceHeight, isNull);
      expect(state.debugLayerNames, previousLayerNames);
      expect(state.debugLayerNames.where((name) => name == '蒙版'), isEmpty);
      expect(state.debugActiveLayerId, previousActiveLayerId);
      expect(state.debugActiveLayerName, previousActiveLayerName);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
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
