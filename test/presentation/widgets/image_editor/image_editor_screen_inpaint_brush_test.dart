import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/focused_inpaint_utils.dart';
import 'package:nai_launcher/core/utils/inpaint_outpaint_utils.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/canvas/editor_canvas.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('non-focused inpaint brush commits mask strokes on the image', (
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
          initialImage: _buildSolidPng(128, 96, const Color(0xFF224466)),
          mode: ImageEditorMode.inpaint,
          title: 'Inpaint brush test',
          initialShowLayerPanel: false,
        ),
      ),
    );
    await _pumpForAsyncEditorWork(tester);
    await _pumpUntil(tester, () {
      final state = tester.state(find.byType(ImageEditorScreen)) as dynamic;
      return state.debugActiveLayerName == '图层 1' &&
          state.debugCurrentToolId == 'brush' &&
          find.byType(EditorCanvas).evaluate().isNotEmpty;
    });

    final state = tester.state(find.byType(ImageEditorScreen)) as dynamic;
    expect(state.debugFocusedInpaintEnabled, isFalse);
    expect(state.debugActiveLayerStrokeCount, 0);
    expect(state.debugHasMaskContent, isFalse);

    final editorCanvas = find.byType(EditorCanvas);
    expect(editorCanvas, findsOneWidget);
    final canvasTopLeft = tester.getTopLeft(editorCanvas);
    final start =
        canvasTopLeft +
        (state.debugCanvasToScreen(const Offset(32, 32)) as Offset);
    final middle =
        canvasTopLeft +
        (state.debugCanvasToScreen(const Offset(56, 48)) as Offset);
    final end =
        canvasTopLeft +
        (state.debugCanvasToScreen(const Offset(80, 64)) as Offset);

    final gesture = await tester.startGesture(start);
    await tester.pump();
    await gesture.moveTo(middle);
    await tester.pump();
    await gesture.moveTo(end);
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(state.debugActiveLayerName, '图层 1');
    expect(state.debugActiveLayerStrokeCount, 1);
    expect(state.debugHasMaskContent, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('focused inpaint card warns when the request costs Anlas', (
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
          initialImage: _buildSolidPng(1600, 1600, const Color(0xFF224466)),
          existingFocusRect: const Rect.fromLTWH(100, 100, 1200, 1200),
          initialMinimumContextMegaPixels: 0,
          focusedInpaintCostConfig: const ImageEditorFocusedInpaintCostConfig(
            model: 'nai-diffusion-4-full',
            steps: 28,
            batchCount: 1,
            batchSize: 1,
            smea: false,
            smeaDyn: false,
            subscriptionTier: 3,
          ),
          mode: ImageEditorMode.inpaint,
          title: 'Focused inpaint cost warning test',
          initialShowLayerPanel: false,
        ),
      ),
    );
    await _pumpForAsyncEditorWork(tester);
    await _pumpUntil(tester, () {
      final state = tester.state(find.byType(ImageEditorScreen)) as dynamic;
      return state.debugFocusedInpaintEnabled &&
          find.textContaining('外层裁剪').evaluate().isNotEmpty;
    });

    expect(find.textContaining('外层裁剪 1232×1232'), findsOneWidget);
    expect(find.textContaining('实际发送 1216×1216'), findsOneWidget);
    expect(find.textContaining('预计 29 Anlas'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('Inpaint confirmation returns the normalized working source', (
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
                    initialImage: _buildSolidPng(
                      130,
                      95,
                      const Color(0xFF224466),
                    ),
                    mode: ImageEditorMode.inpaint,
                    title: 'Working source test',
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
    await _pumpForAsyncEditorWork(tester);
    await _pumpUntil(tester, () {
      final state = tester.state(find.byType(ImageEditorScreen)) as dynamic;
      return state.debugCanvasSize == const Size(192, 128);
    });

    final state = tester.state(find.byType(ImageEditorScreen)) as dynamic;
    await tester.runAsync(() async {
      await state.debugExportAndClose();
    });
    await _pumpForAsyncEditorWork(tester);

    expect(result, isNotNull);
    expect(result!.sourceWasNormalized, isTrue);
    expect(
      (result!.inpaintSourceWidth, result!.inpaintSourceHeight),
      (192, 128),
    );
    final decoded = img.decodeImage(result!.inpaintSourceImage!);
    expect((decoded!.width, decoded.height), (192, 128));
  });

  testWidgets('focused rectangle drag never exceeds the outer-area limit', (
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
          initialSize: Size(2600, 1800),
          mode: ImageEditorMode.inpaint,
          initialFocusedInpaintEnabled: true,
          initialMinimumContextMegaPixels: 16,
          title: 'Focus constraint test',
          initialShowLayerPanel: false,
        ),
      ),
    );
    await _pumpForAsyncEditorWork(tester);
    await _pumpUntil(tester, () {
      final state = tester.state(find.byType(ImageEditorScreen)) as dynamic;
      return state.debugCurrentToolId == 'rect_selection' &&
          find.byType(EditorCanvas).evaluate().isNotEmpty;
    });

    final state = tester.state(find.byType(ImageEditorScreen)) as dynamic;
    final editorCanvas = find.byType(EditorCanvas);
    final canvasTopLeft = tester.getTopLeft(editorCanvas);
    Offset screenPoint(Offset canvasPoint) =>
        canvasTopLeft + (state.debugCanvasToScreen(canvasPoint) as Offset);
    final start = screenPoint(const Offset(128, 1672));
    final end = screenPoint(const Offset(2472, 128));

    final gesture = await tester.startGesture(start);
    await gesture.moveTo(end);
    await tester.pump();
    final preview = state.debugPreviewBounds as Rect?;
    expect(preview, isNotNull);
    final previewGeometry = FocusedInpaintUtils.resolveGeometryForSelection(
      sourceWidth: 2600,
      sourceHeight: 1800,
      selectionRect: preview!,
      minContextMegaPixels: 16,
    )!;
    expect(
      previewGeometry.contextCrop.area,
      lessThanOrEqualTo(FocusedInpaintUtils.maxRequestAreaPixels),
    );

    await gesture.up();
    await tester.pump();
    final committed = state.debugFocusedRect as Rect?;
    expect(committed, isNotNull);
    final committedGeometry = FocusedInpaintUtils.resolveGeometryForSelection(
      sourceWidth: 2600,
      sourceHeight: 1800,
      selectionRect: committed!,
      minContextMegaPixels: 16,
    )!;
    expect(
      committedGeometry.contextCrop.area,
      lessThanOrEqualTo(FocusedInpaintUtils.maxRequestAreaPixels),
    );

    await tester.tap(find.text('Focused Area Selection'));
    await tester.pump();
    state.debugSetToolById('rect_selection');
    final normalGesture = await tester.startGesture(start);
    await normalGesture.moveTo(end);
    await normalGesture.up();
    await tester.pump();
    final normalSelection = state.debugSelectionBounds as Rect?;
    expect(normalSelection, isNotNull);
    expect(
      normalSelection!.width * normalSelection.height,
      greaterThan(3145728),
    );
  });

  testWidgets('increasing Minimum Context shrinks the committed focus rect', (
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
          initialSize: Size(2240, 1792),
          mode: ImageEditorMode.inpaint,
          existingFocusRect: Rect.fromLTWH(100, 100, 1900, 1500),
          initialMinimumContextMegaPixels: 16,
          title: 'Context constraint test',
          initialShowLayerPanel: false,
        ),
      ),
    );
    await _pumpForAsyncEditorWork(tester);
    final state = tester.state(find.byType(ImageEditorScreen)) as dynamic;
    final before = state.debugFocusedRect as Rect;
    final contextSlider = find.byWidgetPredicate(
      (widget) => widget is Slider && widget.max == 192,
    );
    final slider = tester.widget<Slider>(contextSlider);
    slider.onChanged!(192);
    await tester.pump();

    final after = state.debugFocusedRect as Rect;
    expect(after.width * after.height, lessThan(before.width * before.height));
    final geometry = FocusedInpaintUtils.resolveGeometryForSelection(
      sourceWidth: 2240,
      sourceHeight: 1792,
      selectionRect: after,
      minContextMegaPixels: 192,
    )!;
    expect(
      geometry.contextCrop.area,
      lessThanOrEqualTo(FocusedInpaintUtils.maxRequestAreaPixels),
    );
  });

  testWidgets('outpaint edge resize does not paint brush strokes', (
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
          initialImage: _buildSolidPng(128, 128, const Color(0xFF224466)),
          mode: ImageEditorMode.inpaint,
          title: 'Inpaint edge resize test',
          initialShowLayerPanel: false,
        ),
      ),
    );
    await _pumpForAsyncEditorWork(tester);
    await _pumpUntil(tester, () {
      final state = tester.state(find.byType(ImageEditorScreen)) as dynamic;
      return state.debugActiveLayerName == '图层 1' &&
          state.debugCurrentToolId == 'brush' &&
          find.byType(EditorCanvas).evaluate().isNotEmpty;
    });

    final state = tester.state(find.byType(ImageEditorScreen)) as dynamic;
    expect(state.debugFocusedInpaintEnabled, isFalse);
    expect(state.debugCanvasSize, const Size(128, 128));
    expect(state.debugActiveLayerStrokeCount, 0);

    final rightEdge = find.byKey(const Key('outpaint_edge_right'));
    expect(rightEdge, findsOneWidget);
    final edgeRect = tester.getRect(rightEdge);
    final start = edgeRect.center;
    final inwardBy64 =
        (state.debugCanvasToScreen(const Offset(64, 64)) as Offset) -
        (state.debugCanvasToScreen(const Offset(128, 64)) as Offset);

    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await tester.pump();
    await gesture.moveBy(inwardBy64);
    await tester.pump();

    expect(state.debugIsDrawing, isFalse);
    expect(state.debugCurrentStrokePointCount, 0);

    await gesture.up();
    await _pumpUntil(
      tester,
      () => state.debugCanvasSize == const Size(64, 128),
    );

    expect(state.debugCanvasSize, const Size(64, 128));
    expect(state.debugActiveLayerStrokeCount, 0);
    expect(state.debugHasMaskContent, isFalse);
    expect(state.debugHasOutpaintChanges, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('non-focused inpaint brush paints after virtual outpaint shift', (
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
          initialImage: _buildSolidPng(128, 128, const Color(0xFF224466)),
          mode: ImageEditorMode.inpaint,
          title: 'Inpaint test',
          initialShowLayerPanel: false,
        ),
      ),
    );
    await _pumpForAsyncEditorWork(tester);
    await _pumpUntil(tester, () {
      final state = tester.state(find.byType(ImageEditorScreen)) as dynamic;
      return state.debugActiveLayerName == '图层 1' &&
          state.debugCurrentToolId == 'brush' &&
          find.byType(EditorCanvas).evaluate().isNotEmpty;
    });

    final state = tester.state(find.byType(ImageEditorScreen)) as dynamic;
    expect(state.debugCanvasSize, const Size(128, 128));
    expect(state.debugFocusedInpaintEnabled, isFalse);
    expect(state.debugHasMaskContent, isFalse);

    await tester.runAsync(() async {
      await state.debugApplyOutpaintFrameDelta(
        const OutpaintFrameDelta(left: 64),
        horizontalSnapTarget: OutpaintHorizontalSnapTarget.left,
      );
    });
    await _pumpUntil(
      tester,
      () => state.debugCanvasSize == const Size(192, 128),
    );

    expect(state.debugOutpaintCommitPending, isFalse);
    expect(state.debugFocusedInpaintEnabled, isFalse);
    expect(state.debugHasOutpaintChanges, isTrue);
    expect(state.debugVirtualOutpaintMaskRects, isNotEmpty);

    final editorCanvas = find.byType(EditorCanvas);
    expect(editorCanvas, findsOneWidget);
    final canvasTopLeft = tester.getTopLeft(editorCanvas);
    final start =
        canvasTopLeft +
        (state.debugCanvasToScreen(const Offset(82, 40)) as Offset);
    final middle =
        canvasTopLeft +
        (state.debugCanvasToScreen(const Offset(104, 58)) as Offset);
    final end =
        canvasTopLeft +
        (state.debugCanvasToScreen(const Offset(126, 76)) as Offset);

    final gesture = await tester.startGesture(start);
    await tester.pump();
    await gesture.moveTo(middle);
    await tester.pump();
    await gesture.moveTo(end);
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(state.debugActiveLayerName, '图层 1');
    expect(state.debugActiveLayerStrokeCount, 1);
    expect(state.debugHasMaskContent, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('near-edge outpaint drag does not fall through to brush', (
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
          initialImage: _buildSolidPng(128, 128, const Color(0xFF224466)),
          mode: ImageEditorMode.inpaint,
          title: 'Inpaint near-edge resize test',
          initialShowLayerPanel: false,
        ),
      ),
    );
    await _pumpForAsyncEditorWork(tester);
    await _pumpUntil(tester, () {
      final state = tester.state(find.byType(ImageEditorScreen)) as dynamic;
      return state.debugActiveLayerName == '图层 1' &&
          state.debugCurrentToolId == 'brush' &&
          find.byType(EditorCanvas).evaluate().isNotEmpty;
    });

    final state = tester.state(find.byType(ImageEditorScreen)) as dynamic;
    final editorCanvas = find.byType(EditorCanvas);
    final canvasTopLeft = tester.getTopLeft(editorCanvas);
    final rightEdge =
        canvasTopLeft +
        (state.debugCanvasToScreen(const Offset(128, 64)) as Offset);
    final start = rightEdge - const Offset(16, 0);
    final inwardBy64 =
        (state.debugCanvasToScreen(const Offset(64, 64)) as Offset) -
        (state.debugCanvasToScreen(const Offset(128, 64)) as Offset);

    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await tester.pump();
    await gesture.moveBy(inwardBy64);
    await tester.pump();

    expect(state.debugIsDrawing, isFalse);
    expect(state.debugCurrentStrokePointCount, 0);

    await gesture.up();
    await _pumpUntil(
      tester,
      () => state.debugCanvasSize == const Size(64, 128),
    );

    expect(state.debugCanvasSize, const Size(64, 128));
    expect(state.debugActiveLayerStrokeCount, 0);
    expect(state.debugHasMaskContent, isFalse);
    expect(state.debugHasOutpaintChanges, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
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
