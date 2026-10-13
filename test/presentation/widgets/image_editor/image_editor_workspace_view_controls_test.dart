import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/canvas/editor_canvas.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/canvas_controller.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_view_action.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_workspace.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/widgets/toolbar/desktop_toolbar.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/widgets/toolbar/editor_view_menu.dart';

import 'image_editor_workspace_harness.dart';

const _pointerPolicy = InteractionPolicy(
  modality: InteractionModality.pointer,
  touchAvailable: false,
  precisePointerAvailable: true,
);

const _touchPolicy = InteractionPolicy(
  modality: InteractionModality.touch,
  touchAvailable: true,
  precisePointerAvailable: false,
);

const _rotationStep = math.pi / 12;

const _desktopButtonActions = {EditorViewAction.fitToWindow};

/// 桌面工具栏底部收进「视图方向」折叠按钮的动作
const _desktopFlyoutActions = [
  EditorViewAction.rotateLeft,
  EditorViewAction.rotateRight,
  EditorViewAction.mirror,
  EditorViewAction.resetView,
];

void main() {
  final scenarios = <({Size size, double textScale, InteractionPolicy policy})>[
    for (final size in const [
      Size(320, 720),
      Size(600, 760),
      Size(840, 760),
      Size(1180, 760),
      Size(1600, 900),
      Size(780, 360),
    ])
      for (final textScale in const [1.0, 3.0])
        (size: size, textScale: textScale, policy: _pointerPolicy),
    // 桌面布局的最矮窗口配触屏尺寸
    (size: const Size(1180, 480), textScale: 1.0, policy: _touchPolicy),
    (size: const Size(1180, 760), textScale: 1.0, policy: _touchPolicy),
    (size: const Size(320, 720), textScale: 1.0, policy: _touchPolicy),
  ];

  for (final scenario in scenarios) {
    final touch = scenario.policy.touchAvailable;
    testWidgets('view controls are reachable and change the view '
        '${scenario.size} x${scenario.textScale}${touch ? ' touch' : ''}', (
      tester,
    ) async {
      await pumpEditorWorkspace(
        tester,
        viewSize: scenario.size,
        textScale: scenario.textScale,
        policy: scenario.policy,
      );
      expect(tester.takeException(), isNull);

      final driver = _ViewControlDriver(tester, touch: touch);
      await driver.expectAllEntriesReachable(
        scenario.policy.minimumControlExtent,
      );
      await driver.expectActionsChangeView();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('compact overflow menu groups canvas and view actions', (
    tester,
  ) async {
    await pumpEditorWorkspace(tester, viewSize: const Size(320, 720));
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();

    final canvasHeader = tester.getRect(_sectionHeader('Canvas'));
    final compression = tester.getRect(find.text('Choose output resolution'));
    final viewHeader = tester.getRect(_sectionHeader('View'));
    final firstView = tester.getRect(_menuItem(EditorViewAction.values.first));

    expect(canvasHeader.bottom, lessThanOrEqualTo(compression.top));
    expect(compression.bottom, lessThanOrEqualTo(viewHeader.top));
    expect(viewHeader.bottom, lessThanOrEqualTo(firstView.top));
    expect(
      viewHeader.top - compression.bottom,
      greaterThan(0),
      reason: '组标题与上一组之间要有留白，不能看起来属于上一组',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop view buttons stay pinned when the toolbar has room', (
    tester,
  ) async {
    for (final scenario
        in const <({Size size, InteractionPolicy policy, bool pinned})>[
          (size: Size(840, 760), policy: _pointerPolicy, pinned: true),
          (size: Size(1600, 900), policy: _pointerPolicy, pinned: true),
          (size: Size(1180, 760), policy: _touchPolicy, pinned: true),
          (size: Size(1180, 500), policy: _pointerPolicy, pinned: true),
          (size: Size(1180, 480), policy: _touchPolicy, pinned: true),
        ]) {
      await pumpEditorWorkspace(
        tester,
        viewSize: scenario.size,
        policy: scenario.policy,
      );
      final reason = '${scenario.size} touch=${scenario.policy.touchAvailable}';
      expect(find.byType(DesktopToolbar), findsOneWidget, reason: reason);

      for (final (name, control) in [
        for (final action in _desktopButtonActions)
          (action.name, _desktopButton(action)),
        ('orientation', _orientationSlot),
      ]) {
        final scrolled = find.ancestor(
          of: control,
          matching: find.byType(SingleChildScrollView),
        );
        expect(
          scrolled,
          scenario.pinned ? findsNothing : findsOneWidget,
          reason: '$name $reason',
        );
        if (scenario.pinned) {
          expect(
            control.hitTestable(),
            findsOneWidget,
            reason: '固定时无需滚动即可点到 $name $reason',
          );
        }
      }
      expect(tester.takeException(), isNull, reason: reason);
    }
  });

  testWidgets('wider mobile layouts keep only the view group in the menu', (
    tester,
  ) async {
    await pumpEditorWorkspace(tester, viewSize: const Size(600, 760));
    expect(find.byTooltip('Choose output resolution'), findsOneWidget);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();

    expect(_sectionHeader('Canvas'), findsNothing);
    expect(_sectionHeader('View'), findsOneWidget);
    expect(_menuItem(EditorViewAction.resetView), findsOneWidget);
  });

  testWidgets('keyboard shortcuts keep their view actions', (tester) async {
    await pumpEditorWorkspace(tester, viewSize: const Size(1180, 760));
    final state = _editorState(tester);
    final controller = state.canvasController;

    Future<void> press(LogicalKeyboardKey key) async {
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
    }

    await press(LogicalKeyboardKey.digit4);
    expect(controller.rotation, closeTo(-_rotationStep, 1e-9));
    await press(LogicalKeyboardKey.digit6);
    await press(LogicalKeyboardKey.digit6);
    expect(controller.rotation, closeTo(_rotationStep, 1e-9));
    await press(LogicalKeyboardKey.digit5);
    expect(controller.rotation, 0);
    await press(LogicalKeyboardKey.keyF);
    expect(controller.isMirroredHorizontally, isTrue);

    await press(LogicalKeyboardKey.digit3);
    expect(controller.scale, closeTo(_expectedFitWidth(state), 1e-9));
    await press(LogicalKeyboardKey.digit1);
    expect(controller.scale, 1);
    await press(LogicalKeyboardKey.digit2);
    expect(controller.scale, closeTo(_expectedFitHeight(state), 1e-9));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(controller.scale, 1);

    await press(LogicalKeyboardKey.digit4);
    await press(LogicalKeyboardKey.keyR);
    expect(controller.rotation, 0);
    expect(controller.isMirroredHorizontally, isFalse);
    expect(controller.scale, closeTo(_expectedFitToWindow(state), 1e-9));
  });

  testWidgets('shortcut help lists every view shortcut and the fill tool', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () =>
                  ImageEditorWorkspaceState.debugShowShortcutHelpForContext(
                    context,
                  ),
              child: const Text('Shortcuts'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Shortcuts'));
    await tester.pumpAndSettle();

    final scrollable = find.descendant(
      of: find.byKey(const ValueKey('image-editor-shortcut-help-scroll')),
      matching: find.byType(Scrollable),
    );
    for (final (key, description) in const [
      ('G', 'Fill'),
      ('1', '100% Zoom'),
      ('2', 'Fit Height'),
      ('3', 'Fit Width'),
      ('4', 'Rotate Left 15°'),
      ('5', 'Reset Rotation'),
      ('6', 'Rotate Right 15°'),
      ('F', 'Flip Horizontal'),
      ('R', 'Reset View'),
      ('Ctrl+0', '100% Zoom'),
    ]) {
      await tester.scrollUntilVisible(
        find.text(description).first,
        120,
        scrollable: scrollable,
      );
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text(description),
            matching: find.byType(Row),
          ),
          matching: find.text(key),
        ),
        findsOneWidget,
        reason: '$key → $description',
      );
    }
  });
}

EditorState _editorState(WidgetTester tester) =>
    tester.widget<EditorCanvas>(find.byType(EditorCanvas)).state;

Finder _sectionHeader(String title) => find.byWidgetPredicate(
  (widget) => widget is EditorMenuSectionHeader && widget.title == title,
);

Finder _menuItem(EditorViewAction action) =>
    find.byKey(ValueKey('editor-view-menu-${action.name}'));

Finder _desktopButton(EditorViewAction action) =>
    find.byKey(ValueKey('editor-view-button-${action.name}'));

final _orientationSlot = find.byKey(
  const ValueKey('editor-view-slot-orientation'),
);

Finder _flyoutItem(EditorViewAction action) =>
    find.byKey(ValueKey('editor-view-flyout-${action.name}'));

double _fitScale(double available, double extent) {
  expect(available, greaterThan(0), reason: '视口要能容纳适应后的画布');
  return (available / extent)
      .clamp(CanvasController.minScale, CanvasController.maxScale)
      .toDouble();
}

// 适应操作两侧各留 40 像素
const _fitPadding = 40.0 * 2;

double _expectedFitWidth(EditorState state) => _fitScale(
  state.canvasController.viewportSize.width - _fitPadding,
  state.frame.width,
);

double _expectedFitHeight(EditorState state) => _fitScale(
  state.canvasController.viewportSize.height - _fitPadding,
  state.frame.height,
);

double _expectedFitToWindow(EditorState state) =>
    math.min(_expectedFitWidth(state), _expectedFitHeight(state));

/// 按当前布局选择入口：桌面工具栏按钮与视图方向二级菜单优先，其余经缩放菜单或溢出菜单
class _ViewControlDriver {
  _ViewControlDriver(this.tester, {required this.touch})
    : desktop = find.byType(DesktopToolbar).evaluate().isNotEmpty;

  final WidgetTester tester;
  final bool desktop;

  /// 触屏长按展开二级菜单，鼠标用右键
  final bool touch;

  Finder get _menuButton => desktop
      ? find.byKey(const ValueKey('editor-view-zoom-menu'))
      : find.byTooltip('More');

  CanvasController get _controller => _editorState(tester).canvasController;

  Future<void> _reveal(Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    expect(finder.hitTestable(), findsOneWidget);
  }

  Future<void> _openMenu() async {
    await _reveal(_menuButton);
    await tester.tap(_menuButton);
    await tester.pumpAndSettle();
  }

  Future<void> _closeMenu() async {
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
  }

  Future<void> _openOrientationFlyout() async {
    await _reveal(_orientationSlot);
    if (touch) {
      await tester.longPress(_orientationSlot);
    } else {
      await tester.tap(
        _orientationSlot,
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
    }
    await tester.pumpAndSettle();
  }

  /// 二级菜单不是模态的，点工具栏底部留白收起，避免点到编辑器顶栏的按钮
  Future<void> _closeOrientationFlyout() async {
    await tester.tapAt(
      tester.getBottomLeft(find.byType(DesktopToolbar)) + const Offset(2, -2),
    );
    await tester.pumpAndSettle();
    expect(_flyoutItem(_desktopFlyoutActions.first), findsNothing);
  }

  Future<void> expectAllEntriesReachable(double minimumExtent) async {
    if (desktop) {
      for (final (name, control) in [
        for (final action in _desktopButtonActions)
          (action.name, _desktopButton(action)),
        ('orientation', _orientationSlot),
      ]) {
        await _reveal(control);
        final size = tester.getSize(control);
        expect(size.width, greaterThanOrEqualTo(minimumExtent), reason: name);
        expect(size.height, greaterThanOrEqualTo(minimumExtent), reason: name);
      }

      await _openOrientationFlyout();
      for (final action in _desktopFlyoutActions) {
        final item = _flyoutItem(action);
        expect(item.hitTestable(), findsOneWidget, reason: '$action');
        expect(
          tester.getSize(item).height,
          greaterThanOrEqualTo(minimumExtent),
          reason: '$action',
        );
      }
      await _closeOrientationFlyout();
    }

    await _openMenu();
    expect(_sectionHeader('View'), findsOneWidget);
    for (final action in EditorViewAction.values) {
      final item = _menuItem(action);
      await _reveal(item);
      expect(
        tester.getSize(item).height,
        greaterThanOrEqualTo(kMinInteractiveDimension),
        reason: '$action',
      );
    }
    expect(tester.takeException(), isNull);
    await _closeMenu();
  }

  Future<void> perform(EditorViewAction action) async {
    if (desktop && _desktopButtonActions.contains(action)) {
      final button = _desktopButton(action);
      await _reveal(button);
      await tester.tap(button);
    } else if (desktop && _desktopFlyoutActions.contains(action)) {
      await _openOrientationFlyout();
      await tester.tap(_flyoutItem(action));
    } else {
      await _openMenu();
      final item = _menuItem(action);
      await _reveal(item);
      await tester.tap(item);
    }
    await tester.pumpAndSettle();
  }

  Future<void> expectActionsChangeView() async {
    final state = _editorState(tester);
    final controller = _controller;

    final initialScale = controller.scale;
    await perform(EditorViewAction.zoomIn);
    expect(controller.scale, closeTo(initialScale * 1.25, 1e-9));
    await perform(EditorViewAction.zoomOut);
    expect(controller.scale, closeTo(initialScale, 1e-9));

    await perform(EditorViewAction.rotateRight);
    expect(controller.rotation, closeTo(_rotationStep, 1e-9));
    await perform(EditorViewAction.rotateRight);
    await perform(EditorViewAction.rotateLeft);
    expect(controller.rotation, closeTo(_rotationStep, 1e-9));

    await perform(EditorViewAction.mirror);
    expect(controller.isMirroredHorizontally, isTrue);
    await _expectMirrorShownAsSelected();

    await perform(EditorViewAction.resetRotation);
    expect(controller.rotation, 0);
    expect(controller.isMirroredHorizontally, isTrue);

    await perform(EditorViewAction.fitWidth);
    expect(controller.scale, closeTo(_expectedFitWidth(state), 1e-9));
    expect(controller.scale, isNot(1), reason: '确认下一步的 100% 确实改变了缩放');
    await perform(EditorViewAction.actualSize);
    expect(controller.scale, 1);
    await perform(EditorViewAction.fitHeight);
    expect(controller.scale, closeTo(_expectedFitHeight(state), 1e-9));
    await perform(EditorViewAction.actualSize);
    await perform(EditorViewAction.fitToWindow);
    expect(controller.scale, closeTo(_expectedFitToWindow(state), 1e-9));

    await perform(EditorViewAction.rotateLeft);
    await perform(EditorViewAction.actualSize);
    await perform(EditorViewAction.resetView);
    expect(controller.rotation, 0);
    expect(controller.isMirroredHorizontally, isFalse);
    expect(controller.scale, closeTo(_expectedFitToWindow(state), 1e-9));
  }

  Future<void> _expectMirrorShownAsSelected() async {
    if (desktop) {
      final button = _desktopButton(EditorViewAction.mirror);
      final material = tester.widget<Material>(
        find.descendant(of: button, matching: find.byType(Material)).first,
      );
      expect(
        material.color,
        Theme.of(tester.element(button)).colorScheme.primaryContainer,
      );
    }

    await _openMenu();
    final item = _menuItem(EditorViewAction.mirror);
    await _reveal(item);
    final tile = tester.widget<ListTile>(
      find.descendant(of: item, matching: find.byType(ListTile)),
    );
    expect(tile.selected, isTrue);
    expect(
      find.descendant(of: item, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
    await _closeMenu();
  }
}
