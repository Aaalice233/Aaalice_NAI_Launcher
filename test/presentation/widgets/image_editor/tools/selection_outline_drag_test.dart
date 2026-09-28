import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/selection/ellipse_selection_tool.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/selection/lasso_selection_tool.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/selection/rect_selection_tool.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/tool_base.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _selection = Rect.fromLTWH(10, 10, 20, 20);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // EditorState 构造时会异步读取工具设置
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final tool in <EditorTool>[
    RectSelectionTool(),
    EllipseSelectionTool(),
    LassoSelectionTool(),
  ]) {
    group(tool.id, () {
      test('dragging inside the selection moves its outline', () {
        final state = _stateWithSelection();

        tool.onPointerDown(_down(const Offset(20, 20)), state);
        tool.onPointerMove(_move(const Offset(25, 28)), state);

        expect(state.selectionManager.isDragging, isTrue);
        expect(
          state.selectionManager.displayPath!.getBounds(),
          _selection.shift(const Offset(5, 8)),
        );
        expect(state.selectionPath!.getBounds(), _selection);

        tool.onPointerUp(_up(const Offset(25, 28)), state);

        expect(state.selectionManager.isDragging, isFalse);
        expect(
          state.selectionPath!.getBounds(),
          _selection.shift(const Offset(5, 8)),
        );

        expect(state.selectionManager.undoSelection(), isTrue);
        expect(state.selectionPath!.getBounds(), _selection);
      });

      test('pointer cancel keeps the outline where it was', () {
        final state = _stateWithSelection();

        tool.onPointerDown(_down(const Offset(20, 20)), state);
        tool.onPointerMove(_move(const Offset(40, 40)), state);
        tool.onPointerCancel(state);

        expect(state.selectionManager.isDragging, isFalse);
        expect(state.selectionPath!.getBounds(), _selection);
        // 只剩建立选区那一条历史，取消的拖动没有留下记录
        expect(state.selectionManager.undoSelection(), isTrue);
        expect(state.selectionPath, isNull);
      });

      test('a click outside the selection clears it through history', () {
        final state = _stateWithSelection();

        tool.onPointerDown(_down(const Offset(50, 50)), state);
        tool.onPointerUp(_up(const Offset(50, 50)), state);

        expect(state.selectionPath, isNull);
        expect(state.selectionManager.undoSelection(), isTrue);
        expect(state.selectionPath!.getBounds(), _selection);
      });
    });
  }
}

EditorState _stateWithSelection() {
  final state = EditorState();
  addTearDown(state.dispose);
  state.setFrame(const Rect.fromLTWH(0, 0, 100, 100));
  state.setSelection(Path()..addRect(_selection));
  return state;
}

PointerDownEvent _down(Offset position) => PointerDownEvent(position: position);

PointerMoveEvent _move(Offset position) => PointerMoveEvent(position: position);

PointerUpEvent _up(Offset position) => PointerUpEvent(position: position);
