import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/magnetic_lasso/edge_cost_map.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/canvas/editor_canvas.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/input_handler.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/selection/magnetic_lasso_selection_tool.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'hover snaps to rendered edges; Enter closes a normal selection',
    () async {
      final built = Completer<void>();
      var builds = 0;
      final (state, tool) = _createTool((rgba, width, height) {
        final map = EdgeCostMap.build(rgba, width, height);
        if (builds++ == 0) built.complete();
        return map;
      });
      final recorder = ui.PictureRecorder();
      Canvas(recorder)
        ..drawColor(Colors.white, BlendMode.src)
        ..drawRect(
          const Rect.fromLTRB(26, 26, 94, 94),
          Paint()..color = Colors.black,
        );
      final picture = recorder.endRecording();
      final image = picture.toImageSync(120, 120);
      picture.dispose();
      final layer = state.layerManager.activeLayer!;
      state.layerManager.replaceLayerBaseImageSync(layer.id, image, null);

      tool.updateOptions(state, frequency: 75);
      _click(state, tool, const Offset(26, 26));
      await built.future;
      await Future<void>.value();
      final before = tool.anchorCount;
      tool.onPointerHover(
        const PointerHoverEvent(position: Offset(90, 22)),
        state,
      );
      expect(tool.anchorCount, before + 1);
      // 屏幕指针在边缘外 4px，路径和锚点被吸到边缘。
      expect(state.previewPath!.getBounds().top, greaterThan(22));
      _click(state, tool, const Offset(93, 26));
      _click(state, tool, const Offset(93, 93));
      _click(state, tool, const Offset(26, 93));
      final handler = _handler(state);
      expect(_press(handler, LogicalKeyboardKey.enter), KeyEventResult.handled);
      final bounds = state.selectionPath!.getBounds();
      expect(bounds.left, closeTo(26, 3));
      expect(bounds.top, closeTo(26, 3));
      expect(bounds.right, closeTo(94, 3));
      expect(bounds.bottom, closeTo(94, 3));
      expect(state.selectionPath!.contains(const Offset(60, 60)), isTrue);
      expect(state.previewPath, isNull);
      // 原图与取景框未变，开始新路径时可以立即吸附。
      _click(state, tool, const Offset(20, 26));
      tool.onPointerHover(
        const PointerHoverEvent(position: Offset(90, 22)),
        state,
      );
      expect(tool.anchorCount, 2);
      expect(builds, 1);
    },
  );

  test('Delete and Backspace edit anchors without erasing selected pixels', () {
    final (state, tool) = _createTool(EdgeCostMap.build);
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(Colors.black, BlendMode.src);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(120, 120);
    picture.dispose();
    final layer = state.layerManager.activeLayer!;
    state.layerManager.replaceLayerBaseImageSync(layer.id, image, null);
    state.setSelection(Path()..addRect(const Rect.fromLTWH(0, 0, 12, 12)));
    final previous = state.selectionPath;
    final beforeHistory = state.historyManager.undoStackSize;
    final handler = _handler(state);
    _click(state, tool, const Offset(20, 20));
    _click(state, tool, const Offset(80, 20));
    expect(tool.anchorCount, 2);
    expect(_press(handler, LogicalKeyboardKey.delete), KeyEventResult.handled);
    expect(tool.anchorCount, 1);
    expect(
      _press(handler, LogicalKeyboardKey.backspace),
      KeyEventResult.handled,
    );
    expect(tool.anchorCount, 0);
    expect(state.selectionPath, same(previous));
    expect(state.historyManager.undoStackSize, beforeHistory);
    expect(layer.baseImage, same(image));
    _click(state, tool, const Offset(20, 20));
    expect(_press(handler, LogicalKeyboardKey.escape), KeyEventResult.handled);
    expect(tool.anchorCount, 0);
    expect(state.previewPath, isNull);
    expect(tool.onEscape(state), isFalse);
  });

  test('only a nearby second mouse press inside 350 ms closes the path', () {
    final (state, tool) = _createTool(EdgeCostMap.build);
    final handler = _handler(state);
    void click(Offset point, int millis) {
      final position = state.canvasController.canvasToScreen(
        point,
        frame: state.frame,
      );
      handler.handlePointerDown(
        PointerDownEvent(
          position: position,
          kind: PointerDeviceKind.mouse,
          buttons: kPrimaryMouseButton,
          timeStamp: Duration(milliseconds: millis),
        ),
      );
      handler.handlePointerUp(
        PointerUpEvent(position: position, kind: PointerDeviceKind.mouse),
      );
    }

    click(const Offset(20, 20), 100);
    click(const Offset(80, 20), 250);
    click(const Offset(80, 80), 400);
    click(const Offset(78, 80), 800);
    expect(tool.anchorCount, 4);
    expect(state.selectionPath, isNull);
    click(const Offset(78, 80), 1000);
    expect(tool.anchorCount, 0);
    expect(state.selectionPath?.contains(const Offset(65, 45)), isTrue);
  });

  testWidgets('touch drag and pinch keep anchors; panel closes the path', (
    tester,
  ) async {
    final (state, tool) = _createTool(EdgeCostMap.build);
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.pumpWidget(_host(state, tool));
    Offset at(double x, double y) =>
        tester.getTopLeft(find.byType(EditorCanvas)) +
        state.canvasController.canvasToScreen(Offset(x, y), frame: state.frame);
    final finger = await tester.startGesture(at(25, 25));
    await finger.moveTo(at(75, 25));
    await finger.up();
    expect(tool.anchorCount, 2);

    final first = await tester.startGesture(at(75, 25));
    await first.moveTo(at(75, 75));
    final second = await tester.startGesture(at(45, 75));
    await second.up();
    await first.up();
    expect(tool.anchorCount, 2);
    final close = find.widgetWithText(
      FilledButton,
      l10n.editor_magneticLassoClose,
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(close).onPressed, isNull);

    final next = await tester.startGesture(at(75, 25));
    await next.moveTo(at(75, 75));
    await next.up();
    expect(tool.anchorCount, 3);
    await tester.pump();
    await tester.ensureVisible(close);
    await tester.tap(close);
    expect(state.selectionPath?.contains(const Offset(65, 40)), isTrue);
    expect(state.previewPath, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('L cycles through the two available lasso tools', (tester) async {
    final state = EditorState();
    addTearDown(state.dispose);
    await tester.pumpWidget(MaterialApp(home: EditorCanvas(state: state)));
    for (final id in [
      'lasso_selection',
      'magnetic_lasso_selection',
      'lasso_selection',
    ]) {
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.pump();
      expect(state.currentTool!.id, id);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

(EditorState, MagneticLassoSelectionTool) _createTool(
  MagneticLassoEdgeBuilder build,
) {
  final state = EditorState()..initNewCanvas(const Size(120, 120));
  final tool = MagneticLassoSelectionTool(buildEdgeMap: build);
  state.setTool(tool);
  addTearDown(state.dispose);
  addTearDown(tool.dispose);
  return (state, tool);
}

InputHandler _handler(EditorState state) {
  final focus = FocusNode();
  addTearDown(focus.dispose);
  return InputHandler(state: state, focusNode: focus, onStateChanged: () {});
}

KeyEventResult _press(InputHandler handler, LogicalKeyboardKey key) =>
    handler.handleKeyEvent(
      handler.focusNode,
      KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyA,
        logicalKey: key,
        timeStamp: Duration.zero,
      ),
    );

void _click(EditorState state, MagneticLassoSelectionTool tool, Offset at) {
  tool.onPointerDown(
    PointerDownEvent(position: at, kind: PointerDeviceKind.mouse),
    state,
  );
  tool.onPointerUp(
    PointerUpEvent(position: at, kind: PointerDeviceKind.mouse),
    state,
  );
}

Widget _host(EditorState state, MagneticLassoSelectionTool tool) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Row(
      children: [
        Expanded(child: EditorCanvas(state: state)),
        SizedBox(
          width: 275,
          child: SingleChildScrollView(
            child: Builder(
              builder: (context) => tool.buildSettingsPanel(context, state),
            ),
          ),
        ),
      ],
    ),
  ),
);
