import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/frame/editor_frame_commands.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/frame/frame_tool_panel.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/frame_tool.dart';

class _FakeFrameCommands extends ChangeNotifier implements EditorFrameCommands {
  _FakeFrameCommands(this.state);

  final EditorState state;
  final commits = <(Rect, Rect)>[];
  int cropCalls = 0;
  int resetCalls = 0;

  @override
  Rect? sourceRect = const Rect.fromLTWH(0, 0, 256, 128);

  @override
  bool canMoveFrame = true;

  @override
  bool canResetFrame = true;

  @override
  bool canCropToFrame = true;

  @override
  bool isCroppingToFrame = false;

  @override
  bool supportsPasteBack = false;

  @override
  EditorRequestEstimate? requestEstimate;

  @override
  Rect resolveMove(Rect startFrame, Offset delta) {
    return startFrame.shift(delta);
  }

  @override
  void commitMove(Rect from, Rect to) {
    commits.add((from, to));
    state.setFrame(to);
  }

  @override
  void resetFrame() => resetCalls++;

  @override
  Future<void> cropToFrame() async => cropCalls++;

  void refresh() => notifyListeners();
}

EditorState _inpaintState() {
  final state = EditorState()
    ..allowsDetachedFrame = true
    ..setFrame(const Rect.fromLTWH(0, 0, 256, 128));
  addTearDown(state.dispose);
  return state;
}

void main() {
  group('FrameTool', () {
    test('is only available when frame commands are registered', () {
      final state = _inpaintState();
      final tool = FrameTool();
      expect(tool.isAvailableIn(state), isFalse);

      state.setFrameCommands(_FakeFrameCommands(state));
      expect(tool.isAvailableIn(state), isTrue);
    });

    test('drag inside the frame previews then commits one move', () {
      final state = _inpaintState();
      final commands = _FakeFrameCommands(state);
      state.setFrameCommands(commands);
      final tool = FrameTool();

      tool.onPointerDown(
        const PointerDownEvent(position: Offset(100, 50)),
        state,
      );
      tool.onPointerMove(
        const PointerMoveEvent(position: Offset(130, 60)),
        state,
      );
      const moved = Rect.fromLTWH(30, 10, 256, 128);
      expect(state.framePreviewNotifier.value, moved);
      expect(state.displayFrame, moved);
      expect(state.frame, const Rect.fromLTWH(0, 0, 256, 128));
      expect(commands.commits, isEmpty);

      tool.onPointerUp(const PointerUpEvent(position: Offset(130, 60)), state);

      expect(commands.commits, [(const Rect.fromLTWH(0, 0, 256, 128), moved)]);
      expect(state.framePreviewNotifier.value, isNull);
      expect(state.frame, moved);
    });

    test('pointer down outside the frame or while locked does nothing', () {
      final state = _inpaintState();
      final commands = _FakeFrameCommands(state);
      state.setFrameCommands(commands);
      final tool = FrameTool();

      tool.onPointerDown(
        const PointerDownEvent(position: Offset(300, 50)),
        state,
      );
      tool.onPointerMove(
        const PointerMoveEvent(position: Offset(320, 60)),
        state,
      );
      tool.onPointerUp(const PointerUpEvent(position: Offset(320, 60)), state);

      commands.canMoveFrame = false;
      tool.onPointerDown(
        const PointerDownEvent(position: Offset(10, 10)),
        state,
      );
      tool.onPointerMove(
        const PointerMoveEvent(position: Offset(40, 10)),
        state,
      );
      tool.onPointerUp(const PointerUpEvent(position: Offset(40, 10)), state);

      expect(commands.commits, isEmpty);
      expect(state.framePreviewNotifier.value, isNull);
    });

    test('cancel and deactivation discard the preview without committing', () {
      final state = _inpaintState();
      final commands = _FakeFrameCommands(state);
      state.setFrameCommands(commands);
      final tool = FrameTool();

      tool.onPointerDown(
        const PointerDownEvent(position: Offset(10, 10)),
        state,
      );
      tool.onPointerMove(
        const PointerMoveEvent(position: Offset(40, 10)),
        state,
      );
      tool.onPointerCancel(state);
      expect(state.framePreviewNotifier.value, isNull);

      tool.onPointerDown(
        const PointerDownEvent(position: Offset(10, 10)),
        state,
      );
      tool.onPointerMove(
        const PointerMoveEvent(position: Offset(40, 10)),
        state,
      );
      tool.onDeactivateFast(state);
      expect(state.framePreviewNotifier.value, isNull);

      tool.onPointerUp(const PointerUpEvent(position: Offset(40, 10)), state);
      expect(commands.commits, isEmpty);
    });
  });

  group('FrameToolPanel', () {
    Future<void> pumpPanel(
      WidgetTester tester,
      EditorState state, {
      double width = 280,
      double textScale = 1,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                height: 400,
                child: SingleChildScrollView(
                  child: FrameToolPanel(state: state),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('shows size and offset relative to the source', (tester) async {
      final state = _inpaintState();
      final commands = _FakeFrameCommands(state)
        ..sourceRect = const Rect.fromLTWH(0, 64, 256, 128);
      state.setFrameCommands(commands);
      state.setFrame(const Rect.fromLTWH(-64, 32, 320, 192));

      await pumpPanel(tester, state);

      expect(find.text('Size: 320 x 192'), findsOneWidget);
      expect(find.text('Offset from image: X -64, Y -32'), findsOneWidget);

      state.setFramePreview(const Rect.fromLTWH(0, 64, 320, 192));
      await tester.pump();
      expect(find.text('Offset from image: X 0, Y 0'), findsOneWidget);
    });

    testWidgets('shows what the request will cost', (tester) async {
      final state = _inpaintState();
      final commands = _FakeFrameCommands(state)
        ..requestEstimate = const EditorRequestEstimate(
          requestWidth: 832,
          requestHeight: 1216,
          cost: 0,
        );
      state.setFrameCommands(commands);

      await pumpPanel(tester, state);
      expect(find.text('Request: 832 x 1216 · Free'), findsOneWidget);

      commands
        ..requestEstimate = const EditorRequestEstimate(
          requestWidth: 1216,
          requestHeight: 1216,
          cost: 25,
        )
        ..refresh();
      await tester.pump();
      expect(find.text('Request: 1216 x 1216 · ~25 Anlas'), findsOneWidget);

      commands
        ..requestEstimate = null
        ..refresh();
      await tester.pump();
      expect(find.textContaining('Request:'), findsNothing);
    });

    testWidgets('explains paste-back only for sessions that support it', (
      tester,
    ) async {
      final state = _inpaintState();
      final commands = _FakeFrameCommands(state);
      state.setFrameCommands(commands);

      await pumpPanel(tester, state);
      expect(find.textContaining('pasted back'), findsNothing);

      commands
        ..supportsPasteBack = true
        ..refresh();
      await tester.pump();
      expect(find.textContaining('pasted back'), findsOneWidget);
    });

    testWidgets('actions follow command availability', (tester) async {
      final state = _inpaintState();
      final commands = _FakeFrameCommands(state);
      state.setFrameCommands(commands);

      await pumpPanel(tester, state);
      await tester.tap(find.text('Reset Frame'));
      await tester.tap(find.text('Crop to Frame'));
      await tester.pump();
      expect(commands.resetCalls, 1);
      expect(commands.cropCalls, 1);

      commands
        ..canResetFrame = false
        ..canCropToFrame = false
        ..refresh();
      await tester.pump();
      await tester.tap(find.text('Reset Frame'), warnIfMissed: false);
      await tester.tap(find.text('Crop to Frame'), warnIfMissed: false);
      expect(commands.resetCalls, 1);
      expect(commands.cropCalls, 1);
    });

    testWidgets('explains why moving is locked while the view is rotated', (
      tester,
    ) async {
      final state = _inpaintState();
      state.setFrameCommands(_FakeFrameCommands(state));

      await pumpPanel(tester, state);
      expect(find.textContaining('rotated or mirrored'), findsNothing);

      state.canvasController.rotateLeft();
      await tester.pump();
      expect(find.textContaining('rotated or mirrored'), findsOneWidget);
    });

    testWidgets('stays reachable at narrow widths and large text', (
      tester,
    ) async {
      final state = _inpaintState();
      state.setFrameCommands(
        _FakeFrameCommands(state)
          ..supportsPasteBack = true
          ..requestEstimate = const EditorRequestEstimate(
            requestWidth: 1216,
            requestHeight: 1216,
            cost: 25,
          ),
      );

      for (final width in const [280.0, 320.0, 600.0]) {
        for (final textScale in const [1.0, 3.0]) {
          await pumpPanel(tester, state, width: width, textScale: textScale);
          expect(
            tester.takeException(),
            isNull,
            reason: 'width=$width scale=$textScale',
          );
          for (final label in const ['Reset Frame', 'Crop to Frame']) {
            final finder = find.text(label);
            await tester.ensureVisible(finder);
            await tester.pump();
            expect(
              finder.hitTestable(),
              findsOneWidget,
              reason: '$label width=$width scale=$textScale',
            );
          }
        }
      }
    });
  });
}
