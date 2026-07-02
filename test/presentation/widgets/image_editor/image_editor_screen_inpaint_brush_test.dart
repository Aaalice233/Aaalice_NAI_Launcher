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
          find.textContaining('实际送出范围').evaluate().isNotEmpty;
    });

    expect(find.textContaining('1216×1216'), findsOneWidget);
    expect(find.textContaining('预计消耗 29 Anlas'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
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
