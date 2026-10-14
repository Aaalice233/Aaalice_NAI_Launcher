import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/gestures.dart'
    show kDoubleTapMinTime, kSecondaryMouseButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/canvas/editor_canvas.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_workspace.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/model3d_layer_data.dart';
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

Finder _layerName(String name) =>
    find.descendant(of: find.byType(LayerPanel), matching: find.text(name));

EditableText _renameEditable(WidgetTester tester) =>
    tester.widget<EditableText>(_renameField());

Future<void> _pumpWorkspace(WidgetTester tester) =>
    pumpEditorWorkspace(tester, viewSize: const Size(1180, 760));

Future<void> _doubleTapLayerName(WidgetTester tester, String name) async {
  await tester.tap(_layerName(name), kind: PointerDeviceKind.mouse);
  await tester.pump(kDoubleTapMinTime);
  await tester.tap(_layerName(name), kind: PointerDeviceKind.mouse);
  await tester.pump();
  await tester.pump();
  expect(_renameField(), findsOneWidget);
  expect(_renameEditable(tester).focusNode.hasPrimaryFocus, isTrue);
}

Future<void> _renameViaContextMenu(WidgetTester tester, String name) async {
  await tester.tap(
    _layerName(name),
    buttons: kSecondaryMouseButton,
    kind: PointerDeviceKind.mouse,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Rename'), kind: PointerDeviceKind.mouse);
  await tester.pumpAndSettle();
  expect(_renameField(), findsOneWidget);
  expect(_renameEditable(tester).focusNode.hasPrimaryFocus, isTrue);
}

/// 再次进入编辑时输入框显示当前名称，随后用 Esc 关闭以停掉光标闪烁计时器
Future<void> _expectReopensWithName(WidgetTester tester, String name) async {
  await _doubleTapLayerName(tester, name);
  expect(_renameEditable(tester).controller.text, name);
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pumpAndSettle();
  expect(_renameField(), findsNothing);
}

/// 退出编辑后画布重新收到焦点：视图快捷键与工具快捷键都应生效
Future<void> _expectCanvasShortcutsWork(WidgetTester tester) async {
  final controller = _editorState(tester).canvasController;
  final rotationBefore = controller.rotation;
  await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
  await tester.pumpAndSettle();
  expect(controller.rotation, isNot(rotationBefore));

  await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
  await tester.pump();
  expect(_currentToolId(tester), 'rect_selection');
}

void main() {
  final windows = TargetPlatformVariant.only(TargetPlatform.windows);

  testWidgets('双击图层名后重命名框拿到焦点，按键不再切换画布工具', (tester) async {
    await _pumpWorkspace(tester);
    final layer = _editorState(tester).layerManager.layers.first;
    final toolBefore = _currentToolId(tester);

    await _doubleTapLayerName(tester, layer.name);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.pump();
    expect(_currentToolId(tester), toolBefore);

    tester.testTextInput.enterText('Renamed');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(_renameField(), findsNothing);
    expect(_editorState(tester).layerManager.layers.first.name, 'Renamed');
  }, variant: windows);

  testWidgets('回车只提交一次，去掉首尾空白且不写撤销历史', (tester) async {
    await _pumpWorkspace(tester);
    final state = _editorState(tester);
    final layer = state.layerManager.layers.first;
    await _doubleTapLayerName(tester, layer.name);

    final uiUpdatesBefore = state.layerManager.uiUpdateNotifier.value;
    final undoBefore = state.historyManager.undoStackSize;
    tester.testTextInput.enterText('  Renamed  ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(_renameField(), findsNothing);
    expect(layer.name, 'Renamed');
    expect(state.layerManager.uiUpdateNotifier.value - uiUpdatesBefore, 1);
    expect(state.historyManager.undoStackSize, undoBefore);
    await _expectCanvasShortcutsWork(tester);
  }, variant: windows);

  testWidgets('空白名称按回车不提交，原名保留并退出编辑', (tester) async {
    await _pumpWorkspace(tester);
    final state = _editorState(tester);
    final layer = state.layerManager.layers.first;
    final original = layer.name;
    await _doubleTapLayerName(tester, original);

    final uiUpdatesBefore = state.layerManager.uiUpdateNotifier.value;
    tester.testTextInput.enterText('   ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(_renameField(), findsNothing);
    expect(layer.name, original);
    expect(state.layerManager.uiUpdateNotifier.value, uiUpdatesBefore);
    await _expectReopensWithName(tester, original);
  }, variant: windows);

  testWidgets('Esc 恢复原名并退出，按键被输入框消费，画布快捷键随后可用', (tester) async {
    await _pumpWorkspace(tester);
    final state = _editorState(tester);
    final layer = state.layerManager.layers.first;
    final original = layer.name;
    await _doubleTapLayerName(tester, original);

    // 路由作用域位于面板与页面级 Esc 绑定之间，冒泡的 Esc 必先经过它
    final routeScope = FocusScope.of(tester.element(find.byType(LayerPanel)));
    final previousHandler = routeScope.onKeyEvent;
    final bubbledEscapes = <KeyEvent>[];
    routeScope.onKeyEvent = (node, event) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        bubbledEscapes.add(event);
      }
      return KeyEventResult.ignored;
    };
    addTearDown(() => routeScope.onKeyEvent = previousHandler);

    tester.testTextInput.enterText('Draft');
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(bubbledEscapes, isEmpty, reason: 'Esc 应被重命名框消费');
    expect(_renameField(), findsNothing);
    expect(layer.name, original);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    routeScope.onKeyEvent = previousHandler;

    await _expectCanvasShortcutsWork(tester);
    await _expectReopensWithName(tester, original);
  }, variant: windows);

  testWidgets('鼠标点击输入框外部恢复原名并退出编辑', (tester) async {
    await _pumpWorkspace(tester);
    final state = _editorState(tester);
    final layer = state.layerManager.layers.first;
    final original = layer.name;
    await _doubleTapLayerName(tester, original);

    final uiUpdatesBefore = state.layerManager.uiUpdateNotifier.value;
    tester.testTextInput.enterText('Draft');
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(LayerPanel),
        matching: find.text('Layers'),
      ),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();

    expect(_renameField(), findsNothing);
    expect(layer.name, original);
    expect(state.layerManager.uiUpdateNotifier.value, uiUpdatesBefore);
    await _expectCanvasShortcutsWork(tester);
    await _expectReopensWithName(tester, original);
  }, variant: windows);

  testWidgets('3D 图层经右键菜单重命名，提交与 Esc 取消行为一致', (tester) async {
    await _pumpWorkspace(tester);
    final state = _editorState(tester);
    final layer3d = state.layerManager.addLayer(name: 'Pose Layer');
    layer3d.model3d = const Model3dLayerData(
      modelRef: 'builtin:mannequin',
      sceneState: {'version': 1},
    );
    await tester.pumpAndSettle();

    await _renameViaContextMenu(tester, 'Pose Layer');
    tester.testTextInput.enterText('Draft');
    await tester.pump();
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.escape), isTrue);
    await tester.pumpAndSettle();
    expect(_renameField(), findsNothing);
    expect(layer3d.name, 'Pose Layer');

    await _renameViaContextMenu(tester, 'Pose Layer');
    expect(_renameEditable(tester).controller.text, 'Pose Layer');
    final uiUpdatesBefore = state.layerManager.uiUpdateNotifier.value;
    tester.testTextInput.enterText(' Pose B ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(_renameField(), findsNothing);
    expect(layer3d.name, 'Pose B');
    expect(state.layerManager.uiUpdateNotifier.value - uiUpdatesBefore, 1);
  }, variant: windows);
}
