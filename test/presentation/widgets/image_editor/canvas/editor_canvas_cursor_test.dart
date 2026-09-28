import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/canvas/editor_canvas.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/canvas/layer_painter.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';

CursorPainter? _cursorPainter(WidgetTester tester) {
  return tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((widget) => widget.painter)
      .whereType<CursorPainter>()
      .firstOrNull;
}

Widget _wrapCanvas(EditorState state) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 400,
        child: EditorCanvas(state: state),
      ),
    ),
  );
}

void main() {
  testWidgets('悬停只驱动光标重绘，不重建画布子树', (tester) async {
    final state = EditorState()..setCanvasSize(const Size(200, 200));
    addTearDown(state.dispose);

    await tester.pumpWidget(_wrapCanvas(state));
    await tester.pumpAndSettle();

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: const Offset(10, 10));
    addTearDown(gesture.removePointer);
    await gesture.moveTo(const Offset(100, 100));
    await tester.pumpAndSettle();

    expect(state.cursorNotifier.value, const Offset(100, 100));
    final painterBefore = _cursorPainter(tester);
    expect(painterBefore, isNotNull);

    await gesture.moveTo(const Offset(150, 130));
    await tester.pump();

    expect(state.cursorNotifier.value, const Offset(150, 130));
    expect(
      identical(_cursorPainter(tester), painterBefore),
      isTrue,
      reason: '纯位置变化必须只走 cursorNotifier，不得重建画布子树',
    );
  });

  testWidgets('光标离开画布时才重建并卸载光标层', (tester) async {
    final state = EditorState()..setCanvasSize(const Size(200, 200));
    addTearDown(state.dispose);

    await tester.pumpWidget(_wrapCanvas(state));
    await tester.pumpAndSettle();

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: const Offset(10, 10));
    addTearDown(gesture.removePointer);
    await gesture.moveTo(const Offset(100, 100));
    await tester.pumpAndSettle();

    expect(_cursorPainter(tester), isNotNull);

    await gesture.moveTo(const Offset(600, 500));
    await tester.pumpAndSettle();

    expect(state.cursorNotifier.value, isNull);
    expect(_cursorPainter(tester), isNull);
  });

  testWidgets('画笔工具保留系统精确光标作为不滞后的锚点', (tester) async {
    final state = EditorState()..setCanvasSize(const Size(200, 200));
    addTearDown(state.dispose);
    state.setToolById('brush');

    await tester.pumpWidget(_wrapCanvas(state));
    await tester.pumpAndSettle();

    final region = tester.widget<MouseRegion>(
      find
          .descendant(
            of: find.byType(EditorCanvas),
            matching: find.byType(MouseRegion),
          )
          .first,
    );
    expect(region.cursor, SystemMouseCursors.precise);
  });
}
