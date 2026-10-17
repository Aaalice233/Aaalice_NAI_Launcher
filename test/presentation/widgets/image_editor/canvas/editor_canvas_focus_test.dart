import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/canvas/editor_canvas.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/canvas_controller.dart';

import '../image_editor_workspace_harness.dart';

CanvasController _canvasController(WidgetTester tester) => tester
    .widget<EditorCanvas>(find.byType(EditorCanvas))
    .state
    .canvasController;

Future<void> _pressRotateLeft(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
  await tester.pumpAndSettle();
}

final _desktop = TargetPlatformVariant.only(TargetPlatform.windows);

void main() {
  testWidgets('工具设置输入框失焦后画布快捷键仍然可用', (tester) async {
    await pumpEditorWorkspace(tester, viewSize: const Size(1180, 760));
    final field = find.byType(EditableText).first;
    await tester.tap(field, kind: PointerDeviceKind.mouse);
    await tester.pump();
    final fieldFocus = tester.widget<EditableText>(field).focusNode;
    expect(fieldFocus.hasPrimaryFocus, isTrue);

    // 与桌面端点输入框外部的处理一致
    fieldFocus.unfocus();
    await tester.pump();
    await _pressRotateLeft(tester);

    expect(_canvasController(tester).rotation, isNot(0));
  }, variant: _desktop);

  testWidgets('点击画布把焦点从其他控件收回到画布', (tester) async {
    await pumpEditorWorkspace(tester, viewSize: const Size(1180, 760));
    final buttonFocus = Focus.of(
      tester.element(
        find
            .descendant(
              of: find.byType(IconButton).first,
              matching: find.byType(Icon),
            )
            .first,
      ),
    );
    buttonFocus.requestFocus();
    await tester.pump();
    expect(buttonFocus.hasPrimaryFocus, isTrue);

    await tester.tapAt(
      tester.getCenter(find.byType(EditorCanvas)),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    await _pressRotateLeft(tester);

    expect(_canvasController(tester).rotation, isNot(0));
  }, variant: _desktop);
}
