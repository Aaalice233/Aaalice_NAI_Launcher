import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/canvas/editor_canvas.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/canvas/transform_overlay_painter.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/move_tool.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../layers/layer_pixel_test_helpers.dart';

const _layerRect = Rect.fromLTWH(50, 50, 100, 100);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the transform box is drawn only for the move tool', (
    tester,
  ) async {
    final (state, _) = await _pumpCanvas(tester);
    expect(_overlay(tester), findsOneWidget);

    state.setToolById('brush');
    await tester.pumpAndSettle();
    expect(_overlay(tester), findsNothing);
  });

  testWidgets('hovering a corner shows a resize cursor', (tester) async {
    final (state, _) = await _pumpCanvas(tester);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: const Offset(5, 5));
    addTearDown(gesture.removePointer);

    await gesture.moveTo(_screen(state, _layerRect.bottomRight));
    await tester.pumpAndSettle();
    expect(_cursor(tester), SystemMouseCursors.resizeUpLeftDownRight);

    await gesture.moveTo(_screen(state, _layerRect.center));
    await tester.pumpAndSettle();
    expect(_cursor(tester), SystemMouseCursors.move);
  });

  testWidgets('a corner drag scales the layer; Enter applies, Esc cancels', (
    tester,
  ) async {
    final (state, layer) = await _pumpCanvas(tester);
    final transformer = state.layerTransformer;

    await _drag(
      tester,
      _screen(state, _layerRect.bottomRight),
      _screen(state, const Offset(250, 250)),
    );
    expect(transformer.isActive, isTrue);
    expect(layer.contentBounds, const Rect.fromLTWH(50, 50, 200, 200));

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(transformer.isActive, isFalse);
    expect(layer.contentBounds, const Rect.fromLTWH(50, 50, 200, 200));
    expect(state.historyManager.undoStackSize, 1);

    await _drag(
      tester,
      _screen(state, const Offset(250, 250)),
      _screen(state, const Offset(150, 150)),
    );
    expect(layer.contentBounds, const Rect.fromLTWH(50, 50, 100, 100));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(transformer.isActive, isFalse);
    expect(layer.contentBounds, const Rect.fromLTWH(50, 50, 200, 200));
    expect(state.historyManager.undoStackSize, 1);
  });

  testWidgets('Ctrl+T switches to the move tool and opens a transform', (
    tester,
  ) async {
    final (state, _) = await _pumpCanvas(tester);
    state.setToolById('brush');
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(state.currentTool, isA<MoveTool>());
    expect(state.layerTransformer.isActive, isTrue);
  });

  testWidgets('switching tools keeps the applied result', (tester) async {
    final (state, layer) = await _pumpCanvas(tester);
    await _drag(
      tester,
      _screen(state, _layerRect.bottomRight),
      _screen(state, const Offset(200, 200)),
    );
    expect(state.layerTransformer.isActive, isTrue);

    state.setToolById('brush');
    await tester.pumpAndSettle();
    expect(state.layerTransformer.isActive, isFalse);
    expect(layer.contentBounds.size, const Size(150, 150));
  });

  testWidgets('two fingers zoom the view until a transform is open', (
    tester,
  ) async {
    final (state, layer) = await _pumpCanvas(tester);
    final scaleBefore = state.canvasController.scale;

    await _pinch(tester, const Offset(190, 200), const Offset(210, 200), 60);
    expect(state.canvasController.scale, greaterThan(scaleBefore));
    expect(layer.contentBounds, _layerRect);

    final scaleDuringTransform = state.canvasController.scale;
    expect(state.layerTransformer.begin(), isTrue);
    await _pinch(tester, const Offset(190, 200), const Offset(210, 200), 60);
    expect(state.canvasController.scale, scaleDuringTransform);
    expect(layer.contentBounds.width, greaterThan(_layerRect.width));
    expect(state.layerTransformer.isActive, isTrue);
  });
}

Future<(EditorState, Layer)> _pumpCanvas(WidgetTester tester) async {
  final state = EditorState()..setCanvasSize(const Size(400, 400));
  addTearDown(state.dispose);
  final layer = state.layerManager.addLayer(name: 'layer');
  final image = await tester.runAsync(
    () => solidImage(100, 100, const Color(0xFFFF0000)),
  );
  state.layerManager.replaceLayerBaseImageSync(
    layer.id,
    image!,
    null,
    offset: _layerRect.topLeft,
  );
  state.setToolById(MoveTool.toolId);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 400,
          child: EditorCanvas(state: state),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (state, layer);
}

Finder _overlay(WidgetTester tester) => find.byWidgetPredicate(
  (widget) =>
      widget is CustomPaint && widget.painter is TransformOverlayPainter,
);

MouseCursor _cursor(WidgetTester tester) {
  return tester
      .widget<MouseRegion>(
        find
            .descendant(
              of: find.byType(EditorCanvas),
              matching: find.byType(MouseRegion),
            )
            .first,
      )
      .cursor;
}

Offset _screen(EditorState state, Offset document) =>
    state.canvasController.canvasToScreen(document, frame: state.frame);

Future<void> _drag(WidgetTester tester, Offset from, Offset to) async {
  final gesture = await tester.startGesture(
    from,
    kind: PointerDeviceKind.mouse,
  );
  await gesture.moveTo(Offset.lerp(from, to, 0.5)!);
  await gesture.moveTo(to);
  await gesture.up();
  await tester.pump();
}

Future<void> _pinch(
  WidgetTester tester,
  Offset first,
  Offset second,
  double spread,
) async {
  final a = await tester.startGesture(first, pointer: 1);
  final b = await tester.startGesture(second, pointer: 2);
  await tester.pump();
  for (var step = 1; step <= 4; step++) {
    final offset = Offset(spread * step / 4, 0);
    await a.moveTo(first - offset);
    await b.moveTo(second + offset);
    await tester.pump();
  }
  await a.up();
  await b.up();
  await tester.pump();
}
