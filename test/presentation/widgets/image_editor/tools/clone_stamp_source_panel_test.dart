import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/compact_icon_button.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/canvas/clone_source_marker_painter.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/canvas/editor_canvas.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_workspace.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/clone_stamp_tool.dart';

import '../../../../helpers/text_layout_expectations.dart';
import '../image_editor_workspace_harness.dart';
import 'tool_panel_matrix.dart';

final _en = lookupAppLocalizations(const Locale('en'));

final _markerLayer = find.byWidgetPredicate(
  (widget) =>
      widget is CustomPaint && widget.painter is CloneSourceMarkerPainter,
);

void main() {
  group('设置面板', () {
    testWidgets('开关反映取源点状态并可来回切换', (tester) async {
      final (:tool, :state) = await _pumpPanel(tester);

      expect(
        _setSourceSemantics(tester),
        isSemantics(
          label: _en.editor_cloneStampSetSource,
          isButton: true,
          hasToggledState: true,
          isToggled: true,
          hasTapAction: true,
        ),
      );
      expect(find.text(_en.editor_cloneStampPickingHint), findsOneWidget);

      await tester.tap(_setSourceButton(_en));
      await tester.pump();
      expect(tool.isPickingSource, isFalse);
      expect(
        _setSourceSemantics(tester),
        isSemantics(hasToggledState: true, isToggled: false),
      );
      expect(find.text(_en.editor_cloneStampNoSourceHint), findsOneWidget);

      await tester.tap(_setSourceButton(_en));
      await tester.pump();
      expect(tool.isPickingSource, isTrue);
      expect(find.text(_en.editor_cloneStampPickingHint), findsOneWidget);
    });

    testWidgets('画布上提交源点后面板立即显示坐标', (tester) async {
      final (:tool, :state) = await _pumpPanel(tester);

      tool.onPointerDown(
        const PointerDownEvent(position: Offset(14.4, 16.6)),
        state,
      );
      tool.onPointerUp(
        const PointerUpEvent(position: Offset(14.4, 16.6)),
        state,
      );
      await tester.pump();

      expect(
        find.text(_en.editor_cloneStampSourceReadout(14, 17)),
        findsOneWidget,
      );
      expect(
        _setSourceSemantics(tester),
        isSemantics(hasToggledState: true, isToggled: false),
      );
    });

    testWidgets('开关提示说明 Alt+点击同样可设源点', (tester) async {
      await _pumpPanel(tester);

      expect(
        find.byTooltip(_en.editor_cloneStampSetSourceTooltip),
        findsOneWidget,
      );
    });
  });

  group('工作区触屏', () {
    testWidgets('单指点按画布即设源点，面板与准星同步', (tester) async {
      await pumpEditorWorkspace(
        tester,
        viewSize: const Size(1180, 760),
        toolId: 'clone_stamp',
      );
      final state = _workspaceEditorState(tester);
      final tool = state.currentTool! as CloneStampTool;
      final canvas = find.byType(EditorCanvas);
      final center = tester.getCenter(canvas);
      final expected = state.canvasController.screenToCanvas(
        center - tester.getTopLeft(canvas),
        frame: state.frame,
      );

      await tester.tapAt(center);
      await tester.pump();

      expect(tool.sourcePoint!.dx, moreOrLessEquals(expected.dx));
      expect(tool.sourcePoint!.dy, moreOrLessEquals(expected.dy));
      expect(tool.isPickingSource, isFalse);
      expect(
        find.text(
          _en.editor_cloneStampSourceReadout(
            expected.dx.round(),
            expected.dy.round(),
          ),
        ),
        findsOneWidget,
      );
      expect(_markerLayer, findsOneWidget);
      expect(tool.sourceMarker.value, tool.sourcePoint);
    });

    testWidgets('取源点状态下双指缩放不会设源点', (tester) async {
      await pumpEditorWorkspace(
        tester,
        viewSize: const Size(1180, 760),
        toolId: 'clone_stamp',
      );
      final tool = _workspaceEditorState(tester).currentTool! as CloneStampTool;
      final center = tester.getCenter(find.byType(EditorCanvas));

      final first = await tester.startGesture(center - const Offset(40, 0));
      final second = await tester.startGesture(center + const Offset(40, 0));
      await first.moveBy(const Offset(-20, 0));
      await second.moveBy(const Offset(20, 0));
      await tester.pump();
      await second.up();
      await first.up();
      await tester.pump();

      expect(tool.sourcePoint, isNull);
      expect(tool.isPickingSource, isTrue);
      expect(tool.sourceMarker.value, isNull);
    });

    testWidgets('切到其他工具再切回，源点清空并重新进入取源点', (tester) async {
      await pumpEditorWorkspace(
        tester,
        viewSize: const Size(1180, 760),
        toolId: 'clone_stamp',
      );
      final workspace = tester.state<ImageEditorWorkspaceState>(
        find.byType(ImageEditorWorkspace),
      );
      final tool = _workspaceEditorState(tester).currentTool! as CloneStampTool;
      await tester.tapAt(tester.getCenter(find.byType(EditorCanvas)));
      await tester.pump();
      expect(tool.sourcePoint, isNotNull);

      workspace.debugSetToolById('brush');
      await tester.pumpAndSettle();
      expect(_markerLayer, findsNothing);

      workspace.debugSetToolById('clone_stamp');
      await tester.pumpAndSettle();
      expect(tool.sourcePoint, isNull);
      expect(tool.isPickingSource, isTrue);
      expect(find.text(_en.editor_cloneStampPickingHint), findsOneWidget);
      expect(_markerLayer, findsOneWidget);
    });
  });

  testToolPanelMatrix(
    '仿制图章源点开关与状态完整可达',
    toolId: 'clone_stamp',
    verify: (tester, scenario) async {
      final l10n = scenario.l10n;
      final panel = toolPanel(l10n.editor_toolCloneStamp);
      final button = _setSourceButton(l10n);
      expect(button, findsOneWidget, reason: '$scenario');
      await expectReachable(tester, button, reason: '$scenario');

      final panelRect = tester.getRect(panel);
      final buttonRect = tester.getRect(button);
      expect(buttonRect.left, greaterThanOrEqualTo(panelRect.left));
      expect(
        buttonRect.right,
        lessThanOrEqualTo(panelRect.right),
        reason: '放大文字时标签换行，按钮不越出面板 $scenario',
      );
      final label = find.descendant(
        of: button,
        matching: find.text(l10n.editor_cloneStampSetSource),
      );
      expect(
        buttonRect.expandToInclude(tester.getRect(label)),
        buttonRect,
        reason: '$scenario',
      );
      if (scenario.labelWidthsRealistic && scenario.textScale == 1) {
        expectSingleLineUntruncated(tester, label, reason: '$scenario');
      }

      final status = find.text(l10n.editor_cloneStampPickingHint);
      await tester.ensureVisible(status);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(status).right,
        lessThanOrEqualTo(panelRect.right),
        reason: '$scenario',
      );
      expect(status.hitTestable(), findsOneWidget, reason: '$scenario');
    },
  );

  testWidgets('快捷键帮助只在编辑模式列出 Alt + Click 设源点', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 900);
    addTearDown(tester.view.reset);

    for (final includeCloneStamp in const [true, false]) {
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
                      includeCloneStamp: includeCloneStamp,
                    ),
                child: const Text('Shortcuts'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Shortcuts'));
      await tester.pumpAndSettle();

      final expected = includeCloneStamp ? findsOneWidget : findsNothing;
      expect(find.text('Alt + Click'), expected);
      expect(find.text(_en.editor_shortcutCloneStampSource), expected);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('快捷键帮助在 320 宽、3 倍文字下滚完全部行都不溢出', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 1000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(3)),
          child: child!,
        ),
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
    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.text('Alt + Click')).right,
      lessThanOrEqualTo(320),
      reason: '按键名在自身框内换行',
    );

    final position = tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byKey(const ValueKey('image-editor-shortcut-help-scroll')),
            matching: find.byType(Scrollable),
          ),
        )
        .position;
    expect(position.maxScrollExtent, greaterThan(0));
    while (position.pixels < position.maxScrollExtent) {
      position.jumpTo(
        (position.pixels + 200).clamp(0, position.maxScrollExtent),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '${position.pixels}');
    }
  });
}

Future<({CloneStampTool tool, EditorState state})> _pumpPanel(
  WidgetTester tester,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1180, 760);
  addTearDown(tester.view.reset);
  final tool = CloneStampTool();
  final state = EditorState()..setCanvasSize(const Size(64, 64));
  addTearDown(state.dispose);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 280,
            child: Builder(
              builder: (context) => tool.buildSettingsPanel(context, state),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (tool: tool, state: state);
}

Finder _setSourceButton(AppLocalizations l10n) =>
    find.widgetWithText(CompactIconButton, l10n.editor_cloneStampSetSource);

SemanticsNode _setSourceSemantics(WidgetTester tester) =>
    tester.getSemantics(find.byType(CompactIconButton));

EditorState _workspaceEditorState(WidgetTester tester) =>
    tester.widget<EditorCanvas>(find.byType(EditorCanvas)).state;
