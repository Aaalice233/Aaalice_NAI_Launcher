import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/magnetic_lasso/edge_cost_map.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/canvas/editor_canvas.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_types.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/painters/focused_context_overlay_painter.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/selection/magnetic_lasso_selection_tool.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/widgets/focused_selection_card.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/workspace/workspace_canvas_stack.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../image_editor_workspace_harness.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final l10n = lookupAppLocalizations(const Locale('en'));
  final card = find.byType(FocusedSelectionCard);

  for (final scale in [1.0, 3.0]) {
    testWidgets(
      '220-wide Focused card keeps all controls reachable at ${scale}x',
      (tester) async {
        final state = EditorState();
        addTearDown(state.dispose);
        var fills = 0;
        state.setSelectionMaskFillHandler(() async => fills++);
        await tester.pumpWidget(_host(state, scale));
        final selectionMode = _withinCard(
          find.widgetWithText(OutlinedButton, l10n.editor_focusSelection),
        );
        final brushMode = _withinCard(
          find.widgetWithText(OutlinedButton, l10n.editor_focusBrush),
        );
        final lassoMode = _withinCard(
          find.widgetWithText(OutlinedButton, l10n.editor_toolMagneticLasso),
        );
        final fill = _withinCard(
          find.widgetWithText(FilledButton, l10n.selection_fillIntoMask),
        );
        expect(tester.getSize(card).width, 220);
        expect(tester.getSize(card).height, lessThanOrEqualTo(260));
        expect(fill, findsNothing);
        expect(
          tester.getCenter(selectionMode).dy,
          tester.getCenter(brushMode).dy,
        );
        expect(
          tester.getTopLeft(lassoMode).dy,
          greaterThan(tester.getBottomLeft(selectionMode).dy),
        );
        for (final button in [selectionMode, brushMode, lassoMode]) {
          await _expectReachable(tester, button);
        }
        await tester.tap(lassoMode);
        await tester.pump();
        expect(state.currentTool?.id, 'magnetic_lasso_selection');

        state.setSelection(
          Path()..addRect(const Rect.fromLTWH(10, 20, 30, 40)),
        );
        await tester.pump();
        expect(tester.getSize(fill).width, tester.getSize(lassoMode).width);
        await _expectReachable(tester, fill);
        await tester.tap(fill);
        expect(fills, 1);
        state.setSelectionMaskFillHandler(null);
        state.clearSelection();
        state.setSelection(
          Path()..addRect(const Rect.fromLTWH(10, 20, 30, 40)),
        );
        await tester.pump();
        expect(fill, findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('magnetic lasso preview leaves the Focused box unchanged', (
    tester,
  ) async {
    final (key, session) = await pumpEditorWorkspace(
      tester,
      viewSize: const Size(1180, 760),
      mode: ImageEditorMode.inpaint,
    );
    final state = session.editorState;
    expect(state.canFillSelectionIntoMask, isTrue);
    const focus = Rect.fromLTWH(60, 70, 100, 120);
    session.focusedSelectionState.load(focus);
    await tester.tap(find.text('Focused Inpaint'));
    await tester.pumpAndSettle();
    expect(_focusBox(tester), focus);
    final canvas = find.byType(EditorCanvas);
    state.setToolById('rect_selection');
    await tester.pump();
    expect(
      tester.widget<EditorCanvas>(canvas).suppressSelectionOverlay,
      isTrue,
    );

    final tool = MagneticLassoSelectionTool(buildEdgeMap: EdgeCostMap.build);
    addTearDown(tool.dispose);
    state.setTool(tool);
    tool.onPointerDown(
      const PointerDownEvent(position: Offset(220, 220)),
      state,
    );
    tool.onPointerMove(
      const PointerMoveEvent(position: Offset(350, 310)),
      state,
    );
    expect(state.previewPath!.getBounds().center.dx, greaterThan(220));
    await tester.pump();
    expect(
      tester.widget<EditorCanvas>(canvas).suppressSelectionOverlay,
      isFalse,
    );
    // 触发真实工作区重建，确认正在画的普通套索路径不会被读成聚焦框。
    final slider = _withinCard(find.byType(Slider));
    tester.widget<Slider>(slider).onChanged!(96);
    await tester.pump();
    expect(key.currentState!.debugCurrentToolId, 'magnetic_lasso_selection');
    expect(_focusBox(tester), focus);
    expect(session.focusedSelectionState.committedRect, focus);
    state.setToolById('brush');
    await tester.pumpWidget(const SizedBox.shrink());
    expect(state.canFillSelectionIntoMask, isFalse);
  });

  testWidgets('Focused fill shows the same success toast when repeated', (
    tester,
  ) async {
    final (_, session) = await pumpEditorWorkspace(
      tester,
      viewSize: const Size(1180, 760),
      mode: ImageEditorMode.inpaint,
    );
    final state = session.editorState;
    await tester.tap(find.text('Focused Inpaint'));
    await tester.pumpAndSettle();
    final lassoMode = _withinCard(
      find.widgetWithText(OutlinedButton, l10n.editor_toolMagneticLasso),
    );
    await _expectReachable(tester, lassoMode);
    await tester.tap(lassoMode);
    await tester.pump();
    expect(state.currentTool?.id, 'magnetic_lasso_selection');

    final fill = _withinCard(
      find.widgetWithText(FilledButton, l10n.selection_fillIntoMask),
    );
    final toast = find.text(l10n.editor_selectionMaskFilled);
    for (var i = 0; i < 2; i++) {
      state.setSelection(Path()..addRect(const Rect.fromLTWH(16, 16, 8, 8)));
      await tester.pump();
      expect(fill, findsOneWidget);
      // 与按钮使用同一入口，等待引擎完成 Picture 光栅化。
      await tester.runAsync(state.fillSelectionIntoMask);
      await tester.pump();
      expect(toast, findsOneWidget);
      expect(fill, findsNothing);
      expect(state.selectionPath, isNull);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(toast, findsNothing);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('zoomed Focused outlines are clipped to the workspace canvas', (
    tester,
  ) async {
    final (_, session) = await pumpEditorWorkspace(
      tester,
      viewSize: const Size(1180, 760),
      mode: ImageEditorMode.inpaint,
    );
    final state = session.editorState;
    const focus = Rect.fromLTWH(80, 90, 160, 140);
    session.focusedSelectionState.load(focus);
    await tester.tap(find.text('Focused Inpaint'));
    await tester.pumpAndSettle();

    final workspace = find.byType(WorkspaceCanvasStack);
    final viewport = Offset.zero & tester.getSize(workspace);
    const scale = 4.0;
    final camera = state.canvasController
      ..setScale(scale)
      ..setOffset(Offset(viewport.right - 200, -60) - focus.topLeft * scale);
    await tester.pump();

    final painter =
        tester.widget<CustomPaint>(_focusedOverlay).painter!
            as FocusedContextOverlayPainter;
    for (final outline in [painter.focusAreaRect, painter.contextCrop]) {
      final screenRect = Rect.fromPoints(
        camera.canvasToScreen(outline.topLeft, frame: state.frame),
        camera.canvasToScreen(outline.bottomRight, frame: state.frame),
      );
      expect(screenRect.overlaps(viewport), isTrue);
      expect(screenRect.top, lessThan(viewport.top));
      expect(screenRect.right, greaterThan(viewport.right));
    }

    final clip = find.descendant(
      of: workspace,
      matching: find.ancestor(
        of: _focusedOverlay,
        matching: find.byType(ClipRect),
      ),
    );
    expect(clip, findsOneWidget);
    final clipWidget = tester.widget<ClipRect>(clip);
    expect(clipWidget.child, isA<Stack>());
    expect(clipWidget.clipper, isNull);
    expect(clipWidget.clipBehavior, Clip.hardEdge);
    expect(tester.getRect(clip), tester.getRect(workspace));
    expect(tester.getRect(_focusedOverlay), tester.getRect(clip));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Finder _withinCard(Finder matching) =>
    find.descendant(of: find.byType(FocusedSelectionCard), matching: matching);

final _focusedOverlay = find.byWidgetPredicate(
  (widget) =>
      widget is CustomPaint && widget.painter is FocusedContextOverlayPainter,
);

Rect _focusBox(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(_focusedOverlay);
  return (paint.painter! as FocusedContextOverlayPainter).focusAreaRect;
}

Future<void> _expectReachable(WidgetTester tester, Finder button) async {
  await Scrollable.ensureVisible(tester.element(button), alignment: 0.5);
  await tester.pumpAndSettle();
  expect(
    button.hitTestable(),
    findsOneWidget,
    reason: '${tester.getRect(button)}',
  );
  expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
}

Widget _host(EditorState state, double scale) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 260),
        child: FocusedSelectionCard(
          state: state,
          focusedInpaintEnabled: true,
          hasCommittedRect: false,
          minimumContextMegaPixels: 88,
          costEstimate: null,
          onToggleFocusedInpaint: () {},
          onClearSelection: () {},
          onMinimumContextChanged: (_) {},
        ),
      ),
    ),
  ),
);
