import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/gestures.dart' show kDoubleTapMinTime;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/canvas/editor_canvas.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_workspace.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/widgets/panels/layer_panel.dart';

import '../../image_editor_workspace_harness.dart';

EditorState _editorState(WidgetTester tester) =>
    tester.widget<EditorCanvas>(find.byType(EditorCanvas)).state;

String? _currentToolId(WidgetTester tester) => tester
    .state<ImageEditorWorkspaceState>(find.byType(ImageEditorWorkspace))
    .debugCurrentToolId;

Finder _renameField() => find.descendant(
  of: find.byType(LayerPanel),
  matching: find.byType(EditableText),
);

void main() {
  testWidgets('双击图层名后重命名框拿到焦点，按键不再切换画布工具', (tester) async {
    await pumpEditorWorkspace(tester, viewSize: const Size(1180, 760));
    final layer = _editorState(tester).layerManager.layers.first;
    final toolBefore = _currentToolId(tester);
    final name = find.descendant(
      of: find.byType(LayerPanel),
      matching: find.text(layer.name),
    );

    await tester.tap(name, kind: PointerDeviceKind.mouse);
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(name, kind: PointerDeviceKind.mouse);
    await tester.pump();
    await tester.pump();

    expect(_renameField(), findsOneWidget);
    expect(
      tester.widget<EditableText>(_renameField()).focusNode.hasPrimaryFocus,
      isTrue,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.pump();
    expect(_currentToolId(tester), toolBefore);

    tester.testTextInput.enterText('Renamed');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(_renameField(), findsNothing);
    expect(_editorState(tester).layerManager.layers.first.name, 'Renamed');
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
