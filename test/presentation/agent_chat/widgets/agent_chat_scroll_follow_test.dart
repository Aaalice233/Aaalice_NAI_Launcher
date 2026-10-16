import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_notifier.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_history.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_panel_controller.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_turn.dart';

void main() {
  testWidgets('streaming follows while the viewport remains at the bottom', (
    tester,
  ) async {
    final controller = AgentChatPanelController();
    addTearDown(controller.dispose);
    var state = _streamingState('a');
    var heights = _transcriptHeights();

    await _pumpTranscript(tester, controller, state, heights);
    await tester.pump();
    expect(controller.scrollController.offset, 0);
    expect(controller.showJumpToLatest, isFalse);

    controller.jumpToPreservingFollow(30);
    expect(controller.scrollController.offset, 30);

    state = _streamingState('a', token: 'next token');
    heights = [...heights]..[0] += 80;
    await _pumpTranscript(tester, controller, state, heights);
    await tester.pump();

    expect(controller.scrollController.offset, 0);
    expect(controller.showJumpToLatest, isFalse);
  });

  testWidgets(
    'user scroll pauses streaming and asynchronous layout growth does not steal the viewport',
    (tester) async {
      final controller = AgentChatPanelController();
      addTearDown(controller.dispose);
      var state = _streamingState('a');
      var heights = _transcriptHeights();

      await _pumpTranscript(tester, controller, state, heights);
      await tester.pump();
      await tester.drag(
        find.byKey(const ValueKey('transcript')),
        const Offset(0, 420),
      );
      await tester.pumpAndSettle();
      final userOffset = controller.scrollController.offset;
      expect(userOffset, greaterThan(0));
      expect(controller.showJumpToLatest, isTrue);

      state = _streamingState('a', token: 'more streamed content');
      heights = [...heights]..[0] += 120;
      await _pumpTranscript(tester, controller, state, heights);
      await tester.pump();
      expect(controller.scrollController.offset, closeTo(userOffset, 0.01));
      expect(controller.showJumpToLatest, isTrue);

      heights = [...heights]..[1] += 160;
      await _pumpTranscript(tester, controller, state, heights);
      await tester.pump();
      expect(controller.scrollController.offset, closeTo(userOffset, 0.01));
      expect(controller.showJumpToLatest, isTrue);

      state = state.copyWith(
        status: AgentChatRunStatus.idle,
        messages: [UserMessage.text('finalized response')],
        clearStreamingMessage: true,
      );
      heights = [...heights]..[0] += 60;
      await _pumpTranscript(tester, controller, state, heights);
      await tester.pump();
      expect(controller.scrollController.offset, closeTo(userOffset, 0.01));
      expect(controller.showJumpToLatest, isTrue);
    },
  );

  testWidgets(
    'detaching and reattaching the transcript restores the owned paused viewport',
    (tester) async {
      final controller = AgentChatPanelController();
      addTearDown(controller.dispose);
      final state = _streamingState('a');
      final heights = _transcriptHeights();

      await _pumpTranscript(tester, controller, state, heights);
      await tester.pump();
      await tester.drag(
        find.byKey(const ValueKey('transcript')),
        const Offset(0, 420),
      );
      await tester.pumpAndSettle();
      final pausedOffset = controller.scrollController.offset;
      expect(pausedOffset, greaterThan(0));
      expect(controller.showJumpToLatest, isTrue);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(controller.scrollController.hasClients, isFalse);

      await _pumpTranscript(tester, controller, state, heights);
      await tester.pump();
      await tester.pump();

      expect(controller.showJumpToLatest, isTrue);
      expect(controller.scrollController.offset, closeTo(pausedOffset, 0.01));
    },
  );

  testWidgets(
    'recreated panel controller restores the paused viewport from shared ownership',
    (tester) async {
      final viewportStore = AgentChatViewportStore();
      final state = _streamingState('a');
      final heights = _transcriptHeights();
      final firstController = AgentChatPanelController(
        viewportStore: viewportStore,
      );

      await _pumpTranscript(tester, firstController, state, heights);
      await tester.pump();
      await tester.drag(
        find.byKey(const ValueKey('transcript')),
        const Offset(0, 420),
      );
      await tester.pumpAndSettle();
      final pausedOffset = firstController.scrollController.offset;
      expect(pausedOffset, greaterThan(0));
      expect(firstController.showJumpToLatest, isTrue);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      firstController.dispose();

      final recreatedController = AgentChatPanelController(
        viewportStore: viewportStore,
        initialSessionId: 'a',
      );
      expect(recreatedController.followingLatest, isFalse);
      expect(
        recreatedController.scrollController.initialScrollOffset,
        pausedOffset,
      );
      await _pumpTranscript(tester, recreatedController, state, heights);
      await tester.pump();
      await tester.pump();

      expect(recreatedController.showJumpToLatest, isTrue);
      expect(
        recreatedController.scrollController.offset,
        closeTo(pausedOffset, 0.01),
      );

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      recreatedController.dispose();
    },
  );

  testWidgets(
    'zero-height viewport does not resume follow or discard the paused offset',
    (tester) async {
      final controller = AgentChatPanelController();
      addTearDown(controller.dispose);
      var state = _streamingState('a');
      final heights = _transcriptHeights();

      await _pumpTranscript(tester, controller, state, heights);
      await tester.pump();
      await tester.drag(
        find.byKey(const ValueKey('transcript')),
        const Offset(0, 420),
      );
      await tester.pumpAndSettle();
      final pausedOffset = controller.scrollController.offset;
      expect(pausedOffset, greaterThan(0));
      expect(controller.showJumpToLatest, isTrue);

      await _pumpTranscript(
        tester,
        controller,
        state,
        heights,
        viewportHeight: 0,
      );
      await tester.pump();
      await _pumpTranscript(tester, controller, state, heights);
      await tester.pump();

      state = _streamingState('a', token: 'after viewport restore');
      await _pumpTranscript(tester, controller, state, heights);
      await tester.pump();

      expect(controller.showJumpToLatest, isTrue);
      expect(controller.scrollController.offset, closeTo(pausedOffset, 0.01));
    },
  );

  testWidgets(
    'consecutive valid and zero-size resizes preserve paused follow ownership',
    (tester) async {
      final controller = AgentChatPanelController();
      addTearDown(controller.dispose);
      final state = _streamingState('a');
      final heights = _transcriptHeights();

      await _pumpTranscript(tester, controller, state, heights);
      await tester.pump();
      await tester.drag(
        find.byKey(const ValueKey('transcript')),
        const Offset(0, 420),
      );
      await tester.pumpAndSettle();
      final pausedOffset = controller.scrollController.offset;

      for (final height in [180.0, 480.0, 0.0, 240.0, 360.0]) {
        await _pumpTranscript(
          tester,
          controller,
          state,
          heights,
          viewportHeight: height,
        );
        await tester.pump();
        await tester.pump();
        expect(controller.showJumpToLatest, isTrue);
        if (height > 0) {
          expect(
            controller.scrollController.offset,
            closeTo(pausedOffset, 0.01),
          );
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'retained historical turns do not re-enter or shift after leaving the cache',
    (tester) async {
      final controller = AgentChatPanelController();
      addTearDown(controller.dispose);
      final buildCounts = <int, int>{};
      final turns = List.generate(
        6,
        (index) => AgentChatTurnModel(
          ordinal: index,
          userMessage: UserMessage.text('turn $index'),
          userMessageIndex: index,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: AgentChatThreadViewport(
                sessionId: 'a',
                turns: turns,
                controller: controller,
                horizontalPadding: 0,
                maxWidth: 600,
                compactLayout: true,
                hasEarlier: false,
                historyLoading: false,
                prependAnchorEntryId: null,
                onLoadEarlier: null,
                live: const SizedBox.shrink(),
                turnBuilder: (context, turn, current) => _LifecycleProbe(
                  key: ValueKey('probe-${turn.ordinal}'),
                  ordinal: turn.ordinal,
                  buildCounts: buildCounts,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('probe-5')), findsOneWidget);
      expect(buildCounts[5], 1);

      controller.jumpToPreservingFollow(
        controller.scrollController.position.maxScrollExtent,
      );
      await tester.pump();
      controller.jumpToPreservingFollow(0);
      await tester.pump();

      final latest = find.byKey(const ValueKey('probe-5'));
      expect(latest, findsOneWidget);
      expect(
        buildCounts[5],
        1,
        reason: 'virtualization must not recreate a turn on re-entry',
      );
      final settledTop = tester.getTopLeft(latest).dy;
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.getTopLeft(latest).dy, closeTo(settledTop, 0.01));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.getTopLeft(latest).dy, closeTo(settledTop, 0.01));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rapid offscreen keep-alive layout changes never read dirty render sizes',
    (tester) async {
      final controller = AgentChatPanelController();
      addTearDown(controller.dispose);
      final turns = List.generate(
        6,
        (index) => AgentChatTurnModel(
          ordinal: index,
          userMessage: UserMessage.text('turn $index'),
          userMessageIndex: index,
        ),
      );

      Future<void> pump(double height, double width, double itemHeight) =>
          tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  height: height,
                  width: width,
                  child: AgentChatThreadViewport(
                    sessionId: 'a',
                    turns: turns,
                    controller: controller,
                    horizontalPadding: 0,
                    maxWidth: width,
                    compactLayout: true,
                    hasEarlier: false,
                    historyLoading: false,
                    prependAnchorEntryId: null,
                    onLoadEarlier: null,
                    live: const SizedBox.shrink(),
                    turnBuilder: (context, turn, current) => SizedBox(
                      height: itemHeight,
                      child: Text('turn ${turn.ordinal}'),
                    ),
                  ),
                ),
              ),
            ),
          );

      await pump(300, 600, 500);
      await tester.pump();
      for (final configuration in <(double, double, double)>[
        (220, 420, 640),
        (480, 760, 360),
        (180, 360, 720),
        (320, 600, 500),
      ]) {
        controller.jumpToPreservingFollow(
          controller.scrollController.position.maxScrollExtent,
        );
        await pump(configuration.$1, configuration.$2, configuration.$3);
        controller.jumpToPreservingFollow(0);
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'hover and pointer-driven rebuilds never add post-frame scroll feedback',
    (tester) async {
      final controller = AgentChatPanelController();
      addTearDown(controller.dispose);
      final turns = List.generate(
        6,
        (index) => AgentChatTurnModel(
          ordinal: index,
          userMessage: UserMessage.text('turn $index'),
          userMessageIndex: index,
        ),
      );
      var rebuildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Listener(
                onPointerMove: (_) => setState(() => rebuildCount++),
                onPointerHover: (_) => setState(() => rebuildCount++),
                child: SizedBox(
                  height: 300,
                  child: AgentChatThreadViewport(
                    sessionId: 'a',
                    turns: turns,
                    controller: controller,
                    horizontalPadding: 0,
                    maxWidth: 600,
                    compactLayout: true,
                    hasEarlier: false,
                    historyLoading: false,
                    prependAnchorEntryId: null,
                    onLoadEarlier: null,
                    live: const SizedBox.shrink(),
                    turnBuilder: (context, turn, current) => SizedBox(
                      height: 400,
                      child: Text('turn ${turn.ordinal}'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      controller.pauseFollowingLatest();
      controller.jumpToPreservingFollow(260);

      final transcript = find.byType(CustomScrollView);
      final transcriptCenter = tester.getCenter(transcript);
      final beforeHover = controller.scrollController.offset;
      await tester.sendEventToBinding(
        PointerHoverEvent(
          kind: PointerDeviceKind.mouse,
          position: transcriptCenter,
        ),
      );
      await tester.pump();
      expect(rebuildCount, greaterThan(0));
      expect(controller.scrollController.offset, closeTo(beforeHover, 0.01));

      final gesture = await tester.startGesture(transcriptCenter);
      var previousOffset = controller.scrollController.offset;
      for (var frame = 0; frame < 6; frame++) {
        await gesture.moveBy(const Offset(0, 24));
        await tester.pump(const Duration(milliseconds: 16));
        final currentOffset = controller.scrollController.offset;
        expect(currentOffset, greaterThanOrEqualTo(previousOffset));
        previousOffset = currentOffset;
      }
      await gesture.up();
      await tester.pump();
      expect(rebuildCount, greaterThan(0));

      final settledOffset = controller.scrollController.offset;
      await tester.pump(const Duration(milliseconds: 16));
      expect(controller.scrollController.offset, closeTo(settledOffset, 0.01));
      await tester.pump(const Duration(milliseconds: 200));
      expect(controller.scrollController.offset, closeTo(settledOffset, 0.01));
    },
  );

  testWidgets(
    'streaming growth preserves the visible turn anchor while follow is paused',
    (tester) async {
      final controller = AgentChatPanelController();
      addTearDown(controller.dispose);
      final turns = List.generate(
        6,
        (index) => AgentChatTurnModel(
          ordinal: index,
          userMessage: UserMessage.text('turn $index'),
          userMessageIndex: index,
        ),
      );

      Future<void> pumpViewport(double liveHeight) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 300,
                child: AgentChatThreadViewport(
                  sessionId: 'a',
                  turns: turns,
                  controller: controller,
                  horizontalPadding: 0,
                  maxWidth: 600,
                  compactLayout: true,
                  hasEarlier: false,
                  historyLoading: false,
                  prependAnchorEntryId: null,
                  onLoadEarlier: null,
                  live: SizedBox(height: liveHeight),
                  turnBuilder: (context, turn, current) => SizedBox(
                    height: 100,
                    child: Text('turn ${turn.ordinal}'),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      await pumpViewport(80);
      await tester.pump();
      final transcript = find.byType(CustomScrollView);
      await tester.drag(transcript, const Offset(0, 240));
      await tester.pumpAndSettle();
      expect(controller.showJumpToLatest, isTrue);

      final anchor = find.byKey(const ValueKey('agent-turn-3'));
      expect(anchor, findsOneWidget);
      final anchorTop = tester.getTopLeft(anchor).dy;

      await pumpViewport(200);
      await tester.pump();

      expect(tester.getTopLeft(anchor).dy, closeTo(anchorTop, 0.01));
      expect(controller.showJumpToLatest, isTrue);
    },
  );

  testWidgets(
    'wheel scrolling while streaming keeps the user offset instead of fighting it',
    (tester) async {
      final controller = AgentChatPanelController();
      addTearDown(controller.dispose);
      final turns = _turns(6);

      Future<void> pumpViewport(double liveHeight) => _pumpThreadViewport(
        tester,
        controller,
        turns: turns,
        live: SizedBox(height: liveHeight),
        turnHeight: (_) => 100,
      );

      await pumpViewport(80);
      await tester.pump();
      final transcript = find.byType(CustomScrollView);
      await tester.drag(transcript, const Offset(0, 240));
      await tester.pumpAndSettle();
      final pausedOffset = controller.scrollController.offset;
      expect(controller.showJumpToLatest, isTrue);

      final anchor = find.byKey(const ValueKey('agent-turn-3'));
      final anchorTop = tester.getTopLeft(anchor).dy;

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      pointer.hover(tester.getCenter(transcript));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -60)));
      final wheelOffset = controller.scrollController.offset;
      expect(wheelOffset, greaterThan(pausedOffset));

      await pumpViewport(200);
      await tester.pump();

      expect(
        controller.scrollController.offset,
        closeTo(wheelOffset + 120, 0.01),
        reason: 'growth is added on top of the wheel offset, never undoing it',
      );
      expect(
        tester.getTopLeft(anchor).dy,
        closeTo(anchorTop + 60, 0.01),
        reason: 'the wheel distance must stay visible',
      );

      final settledTop = tester.getTopLeft(anchor).dy;
      await pumpViewport(320);
      await tester.pump();
      expect(tester.getTopLeft(anchor).dy, closeTo(settledTop, 0.01));
      expect(controller.showJumpToLatest, isTrue);
    },
  );

  testWidgets(
    'a wheel scroll that hits the oldest edge does not suspend drift correction',
    (tester) async {
      final controller = AgentChatPanelController();
      addTearDown(controller.dispose);
      final turns = _turns(6);

      Future<void> pumpViewport(double liveHeight) => _pumpThreadViewport(
        tester,
        controller,
        turns: turns,
        live: SizedBox(height: liveHeight),
        turnHeight: (_) => 100,
      );

      await pumpViewport(80);
      await tester.pump();
      controller.pauseFollowingLatest();
      controller.jumpToPreservingFollow(
        controller.scrollController.position.maxScrollExtent,
      );
      await tester.pump();
      final edgeOffset = controller.scrollController.offset;

      final transcript = find.byType(CustomScrollView);
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      pointer.hover(tester.getCenter(transcript));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -60)));
      expect(controller.scrollController.offset, closeTo(edgeOffset, 0.01));

      final anchor = find.byKey(const ValueKey('agent-turn-0'));
      final painted = _paintedBottomEdge(tester, anchor);
      await pumpViewport(200);
      expect(_paintedBottomEdge(tester, anchor), closeTo(painted, 0.01));
      expect(controller.showJumpToLatest, isTrue);
    },
  );

  testWidgets(
    'bursty streaming keeps the paused transcript painted at the same place',
    (tester) async {
      final controller = AgentChatPanelController();
      addTearDown(controller.dispose);
      final turns = _turns(6);
      var liveHeight = 4000.0;

      Future<void> pumpFrame() => _pumpThreadViewport(
        tester,
        controller,
        turns: turns,
        live: SizedBox(height: liveHeight),
        turnHeight: (_) => 120,
      );

      await pumpFrame();
      controller.pauseFollowingLatest();
      controller.jumpToPreservingFollow(4300);
      await tester.pump();

      final anchor = find.byKey(const ValueKey('agent-turn-3'));
      final painted = _paintedBottomEdge(tester, anchor);
      var expectedOffset = controller.scrollController.offset;
      for (final burst in const [0.0, 120.0, 0.0, 160.0, 0.0, 40.0]) {
        liveHeight += burst;
        await pumpFrame();
        expectedOffset += burst;
        expect(
          _paintedBottomEdge(tester, anchor),
          closeTo(painted, 0.01),
          reason: 'the frame that streamed $burst px painted the anchor off',
        );
        expect(
          controller.scrollController.offset,
          closeTo(expectedOffset, 0.01),
        );
      }
      expect(controller.showJumpToLatest, isTrue);
    },
  );

  testWidgets(
    'the growing current turn keeps a paused historical turn painted in place',
    (tester) async {
      final controller = AgentChatPanelController();
      addTearDown(controller.dispose);
      final turns = _turns(4);
      var currentHeight = 600.0;

      Future<void> pumpFrame() => _pumpThreadViewport(
        tester,
        controller,
        turns: turns,
        live: const SizedBox.shrink(),
        turnHeight: (turn) => turn.ordinal == 3 ? currentHeight : 200,
      );

      await pumpFrame();
      controller.pauseFollowingLatest();
      controller.jumpToPreservingFollow(700);
      await tester.pump();

      final anchor = find.byKey(const ValueKey('agent-turn-2'));
      final painted = _paintedBottomEdge(tester, anchor);
      for (final burst in const [80.0, 0.0, 240.0, 16.0]) {
        currentHeight += burst;
        await pumpFrame();
        expect(
          _paintedBottomEdge(tester, anchor),
          closeTo(painted, 0.01),
          reason: 'the frame that streamed $burst px painted the anchor off',
        );
      }
      expect(controller.showJumpToLatest, isTrue);
    },
  );

  testWidgets(
    'a single streaming turn stays put while the reader is paused inside it',
    (tester) async {
      final controller = AgentChatPanelController();
      addTearDown(controller.dispose);
      var turnHeight = 900.0;
      final turns = _turns(1);

      Future<void> pumpFrame() => _pumpThreadViewport(
        tester,
        controller,
        turns: turns,
        live: const SizedBox.shrink(),
        turnHeight: (_) => turnHeight,
      );

      await pumpFrame();
      controller.pauseFollowingLatest();
      controller.jumpToPreservingFollow(300);
      await tester.pump();

      final turn = find.byKey(const ValueKey('agent-turn-0'));
      final painted = _paintedTopEdge(tester, turn);
      var expectedOffset = controller.scrollController.offset;
      for (final burst in const [0.0, 120.0, 0.0, 160.0, 0.0, 40.0]) {
        turnHeight += burst;
        await pumpFrame();
        expectedOffset += burst;
        expect(
          _paintedTopEdge(tester, turn),
          closeTo(painted, 0.01),
          reason: 'the frame that streamed $burst px painted the turn off',
        );
        expect(
          controller.scrollController.offset,
          closeTo(expectedOffset, 0.01),
        );
      }
      expect(controller.showJumpToLatest, isTrue);
    },
  );

  testWidgets(
    'shrinking content near the live edge clamps the correction without bouncing',
    (tester) async {
      final controller = AgentChatPanelController();
      addTearDown(controller.dispose);
      final turns = _turns(4);
      var currentHeight = 600.0;

      Future<void> pumpFrame() => _pumpThreadViewport(
        tester,
        controller,
        turns: turns,
        live: const SizedBox.shrink(),
        turnHeight: (turn) => turn.ordinal == 3 ? currentHeight : 200,
      );

      await pumpFrame();
      controller.pauseFollowingLatest();
      controller.jumpToPreservingFollow(60);
      await tester.pump();

      currentHeight = 300;
      await pumpFrame();
      final position = controller.scrollController.position;
      expect(position.pixels, greaterThanOrEqualTo(position.minScrollExtent));
      expect(position.isScrollingNotifier.value, isFalse);
      final settled = position.pixels;
      await tester.pump(const Duration(milliseconds: 300));
      expect(position.pixels, closeTo(settled, 0.01));
      expect(controller.showJumpToLatest, isTrue);
    },
  );

  testWidgets(
    'growth the list corrects itself on re-entering the cache is not corrected twice',
    (tester) async {
      final controller = AgentChatPanelController();
      addTearDown(controller.dispose);
      final turns = _turns(6);
      var currentHeight = 600.0;

      Future<void> pumpFrame() => _pumpThreadViewport(
        tester,
        controller,
        turns: turns,
        live: const SizedBox.shrink(),
        turnHeight: (turn) => turn.ordinal == 5 ? currentHeight : 400,
      );

      await pumpFrame();
      controller.pauseFollowingLatest();
      controller.jumpToPreservingFollow(1600);
      await tester.pump();

      final anchor = find.byKey(const ValueKey('agent-turn-2'));
      final paintedBeforeWheel = _paintedBottomEdge(tester, anchor);
      currentHeight = 900;
      await pumpFrame();
      expect(
        _paintedBottomEdge(tester, anchor),
        closeTo(paintedBeforeWheel, 0.01),
      );

      final transcript = find.byType(CustomScrollView);
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      pointer.hover(tester.getCenter(transcript));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 200)));
      await tester.pump();

      expect(
        controller.scrollController.offset,
        closeTo(1600 - 200 + 300, 0.01),
      );
      expect(
        _paintedBottomEdge(tester, anchor),
        closeTo(paintedBeforeWheel + 200, 0.01),
        reason: 'only the wheel distance may move the anchor',
      );
      expect(controller.showJumpToLatest, isTrue);
    },
  );

  testWidgets(
    'revealing earlier turns keeps the oldest visible turn in place',
    (tester) async {
      final controller = AgentChatPanelController();
      addTearDown(controller.dispose);
      final turns = _turns(10);
      var currentHeight = 600.0;

      Future<void> pumpFrame() => _pumpThreadViewport(
        tester,
        controller,
        turns: turns,
        live: const SizedBox.shrink(),
        turnHeight: (turn) => turn.ordinal == 9 ? currentHeight : 400,
      );

      await pumpFrame();
      await tester.pump();
      controller.pauseFollowingLatest();
      controller.jumpToPreservingFollow(
        controller.scrollController.position.maxScrollExtent,
      );
      await tester.pump();

      currentHeight = 900;
      await pumpFrame();
      final anchor = find.byKey(const ValueKey('agent-turn-4'));
      final painted = _paintedBottomEdge(tester, anchor);

      await tester.tap(
        find.byKey(const ValueKey('agent-chat-earlier-messages')),
      );
      await tester.pump();
      expect(_paintedBottomEdge(tester, anchor), closeTo(painted, 0.01));
      await tester.pump();
      expect(_paintedBottomEdge(tester, anchor), closeTo(painted, 0.01));
      expect(
        find.byKey(const ValueKey('agent-turn-0'), skipOffstage: false),
        findsOneWidget,
      );
      expect(controller.showJumpToLatest, isTrue);
    },
  );

  testWidgets(
    'a pointer held still on the transcript does not suspend drift correction',
    (tester) async {
      final controller = AgentChatPanelController();
      addTearDown(controller.dispose);
      final turns = _turns(4);
      var currentHeight = 600.0;

      Future<void> pumpFrame() => _pumpThreadViewport(
        tester,
        controller,
        turns: turns,
        live: const SizedBox.shrink(),
        turnHeight: (turn) => turn.ordinal == 3 ? currentHeight : 200,
      );

      await pumpFrame();
      controller.pauseFollowingLatest();
      controller.jumpToPreservingFollow(700);
      await tester.pump();

      final anchor = find.byKey(const ValueKey('agent-turn-2'));
      final painted = _paintedBottomEdge(tester, anchor);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(CustomScrollView)),
      );
      await tester.pump();

      currentHeight += 240;
      await pumpFrame();
      expect(_paintedBottomEdge(tester, anchor), closeTo(painted, 0.01));

      await gesture.up();
      await tester.pump();
      expect(_paintedBottomEdge(tester, anchor), closeTo(painted, 0.01));
      expect(controller.showJumpToLatest, isTrue);
    },
  );

  testWidgets(
    'streaming during a drag keeps the content under the pointer',
    (tester) async {
      final controller = AgentChatPanelController();
      addTearDown(controller.dispose);
      final turns = _turns(4);
      var currentHeight = 600.0;

      Future<void> pumpFrame() => _pumpThreadViewport(
        tester,
        controller,
        turns: turns,
        live: const SizedBox.shrink(),
        turnHeight: (turn) => turn.ordinal == 3 ? currentHeight : 200,
      );

      await pumpFrame();
      controller.pauseFollowingLatest();
      controller.jumpToPreservingFollow(700);
      await tester.pump();

      final anchor = find.byKey(const ValueKey('agent-turn-2'));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(CustomScrollView)),
      );
      await gesture.moveBy(const Offset(0, 30));
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      final painted = _paintedBottomEdge(tester, anchor);

      currentHeight += 240;
      await pumpFrame();
      expect(_paintedBottomEdge(tester, anchor), closeTo(painted, 0.01));

      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      expect(_paintedBottomEdge(tester, anchor), closeTo(painted - 20, 0.01));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.showJumpToLatest, isTrue);
    },
  );

  testWidgets(
    'turns outside the cache are measured again once a resize settles',
    (tester) async {
      final controller = AgentChatPanelController();
      addTearDown(controller.dispose);
      final turns = _turns(6);
      var width = 600.0;

      Future<void> pumpViewport() => _pumpThreadViewport(
        tester,
        controller,
        turns: turns,
        live: const SizedBox(height: 4000),
        turnHeight: (_) => 60000 / width,
        width: width,
      );

      await pumpViewport();
      await tester.pumpAndSettle();
      final position = controller.scrollController.position;
      expect(position.maxScrollExtent, closeTo(4000 + 600 + 24 - 300, 0.01));

      for (final step in const [500.0, 420.0, 300.0]) {
        width = step;
        await pumpViewport();
      }
      await tester.pumpAndSettle();
      expect(position.maxScrollExtent, closeTo(4000 + 1200 + 24 - 300, 0.01));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the scroll extent stays fixed while scrolling static content', (
    tester,
  ) async {
    final controller = AgentChatPanelController();
    addTearDown(controller.dispose);

    await _pumpThreadViewport(
      tester,
      controller,
      turns: _turns(6),
      live: const SizedBox(height: 4000),
      turnHeight: (_) => 120,
    );
    await tester.pump();

    final position = controller.scrollController.position;
    final extent = position.maxScrollExtent;
    expect(extent, closeTo(4000 + 6 * 120 + 24 - 300, 0.01));
    for (final offset in const [0.0, 600.0, 2000.0, 3000.0, 4200.0]) {
      controller.jumpToPreservingFollow(offset);
      await tester.pump();
      expect(
        position.maxScrollExtent,
        closeTo(extent, 0.01),
        reason: 'the scroll extent changed at offset $offset',
      );
    }
  });

  testWidgets('returning to the bottom or sending resumes streaming follow', (
    tester,
  ) async {
    final controller = AgentChatPanelController();
    addTearDown(controller.dispose);
    var state = _streamingState('a');
    final heights = _transcriptHeights();

    await _pumpTranscript(tester, controller, state, heights);
    await tester.pump();
    await tester.drag(
      find.byKey(const ValueKey('transcript')),
      const Offset(0, 420),
    );
    await tester.pumpAndSettle();
    expect(controller.showJumpToLatest, isTrue);

    controller.scrollController.jumpTo(0);
    await tester.pump();
    expect(
      controller.showJumpToLatest,
      isTrue,
      reason: 'layout and viewport changes must not impersonate user intent',
    );

    final transcriptContext = tester.element(
      find.byKey(const ValueKey('transcript')),
    );
    controller.handleScrollNotification(
      UserScrollNotification(
        metrics: _metrics(120),
        context: transcriptContext,
        direction: ScrollDirection.forward,
      ),
    );
    controller.handleScrollNotification(
      ScrollUpdateNotification(
        metrics: _metrics(0),
        context: transcriptContext,
        scrollDelta: -120,
      ),
    );
    expect(controller.showJumpToLatest, isFalse);

    await tester.drag(
      find.byKey(const ValueKey('transcript')),
      const Offset(0, 420),
    );
    await tester.pumpAndSettle();
    expect(controller.showJumpToLatest, isTrue);

    controller.followLatest();
    await tester.pumpAndSettle();
    expect(controller.scrollController.offset, 0);
    expect(controller.showJumpToLatest, isFalse);

    state = _streamingState('a', token: 'after send');
    await _pumpTranscript(tester, controller, state, [...heights]..[0] += 100);
    await tester.pump();
    expect(controller.scrollController.offset, 0);
  });

  testWidgets(
    'session offsets and follow intent remain local to each viewport',
    (tester) async {
      final first = AgentChatPanelController();
      final second = AgentChatPanelController();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      final heights = _transcriptHeights();

      await _pumpTranscript(tester, first, _streamingState('a'), heights);
      await tester.pump();
      await tester.drag(
        find.byKey(const ValueKey('transcript')),
        const Offset(0, 260),
      );
      await tester.pumpAndSettle();
      final savedOffset = first.scrollController.offset;
      expect(savedOffset, greaterThan(0));
      expect(first.showJumpToLatest, isTrue);

      await _pumpTranscript(tester, first, _streamingState('b'), heights);
      await tester.pump();
      expect(first.scrollController.offset, 0);
      expect(first.showJumpToLatest, isFalse);

      await _pumpTranscript(tester, first, _streamingState('a'), heights);
      await tester.pump();
      first.restoreSessionOffset('a');
      expect(first.scrollController.offset, closeTo(savedOffset, 0.01));
      expect(first.showJumpToLatest, isTrue);

      await _pumpTranscript(tester, second, _streamingState('a'), heights);
      await tester.pump();
      second.restoreSessionOffset('a');
      expect(second.scrollController.offset, 0);
      expect(second.showJumpToLatest, isFalse);
    },
  );

  testWidgets('mouse wheel scrolling pauses streaming follow immediately', (
    tester,
  ) async {
    final controller = AgentChatPanelController();
    addTearDown(controller.dispose);
    await _pumpTranscript(
      tester,
      controller,
      _streamingState('a'),
      _transcriptHeights(),
    );
    await tester.pump();
    final transcript = find.byKey(const ValueKey('transcript'));

    await tester.sendEventToBinding(
      PointerScrollEvent(
        kind: PointerDeviceKind.mouse,
        position: tester.getCenter(transcript),
        scrollDelta: const Offset(0, -240),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.scrollController.offset, greaterThan(0));
    expect(controller.showJumpToLatest, isTrue);
  });

  testWidgets(
    'driven user scrolls pause while controller-owned jumps preserve intent',
    (tester) async {
      final controller = AgentChatPanelController();
      addTearDown(controller.dispose);
      await _pumpTranscript(
        tester,
        controller,
        _streamingState('a'),
        _transcriptHeights(),
      );
      await tester.pump();

      controller.jumpToPreservingFollow(120);
      expect(controller.scrollController.offset, 120);
      expect(controller.showJumpToLatest, isFalse);

      controller.followLatest();
      controller.beginPotentialUserScroll();
      final drivenScroll = controller.scrollController.animateTo(
        180,
        duration: const Duration(milliseconds: 80),
        curve: Curves.linear,
      );
      await tester.pumpAndSettle();
      await drivenScroll;

      expect(controller.scrollController.offset, 180);
      expect(
        controller.showJumpToLatest,
        isTrue,
        reason: 'keyboard and scrollbar actions use driven scroll activities',
      );
    },
  );

  testWidgets(
    'user scroll notifications pause follow without misclassifying programmatic updates',
    (tester) async {
      final controller = AgentChatPanelController();
      addTearDown(controller.dispose);
      await _pumpTranscript(
        tester,
        controller,
        _streamingState('a'),
        _transcriptHeights(),
      );
      await tester.pump();
      final context = tester.element(find.byKey(const ValueKey('transcript')));

      controller.handleScrollNotification(
        ScrollUpdateNotification(
          metrics: _metrics(180),
          context: context,
          scrollDelta: 180,
        ),
      );
      expect(
        controller.showJumpToLatest,
        isFalse,
        reason: 'a notification without user activity can come from jumpTo',
      );

      controller.handleScrollNotification(
        UserScrollNotification(
          metrics: _metrics(0),
          context: context,
          direction: ScrollDirection.forward,
        ),
      );
      controller.handleScrollNotification(
        ScrollUpdateNotification(
          metrics: _metrics(12),
          context: context,
          scrollDelta: 12,
        ),
      );
      expect(controller.showJumpToLatest, isTrue);

      controller.followLatest();
      expect(controller.showJumpToLatest, isFalse);
      controller.handleScrollNotification(
        ScrollUpdateNotification(
          metrics: _metrics(160),
          context: context,
          scrollDelta: 148,
        ),
      );
      expect(
        controller.showJumpToLatest,
        isFalse,
        reason: 'an explicit jump clears the preceding user scroll activity',
      );

      controller.handleScrollNotification(
        UserScrollNotification(
          metrics: _metrics(0),
          context: context,
          direction: ScrollDirection.forward,
        ),
      );
      controller.handleScrollNotification(
        ScrollUpdateNotification(
          metrics: _metrics(12),
          context: context,
          scrollDelta: 12,
        ),
      );
      expect(controller.showJumpToLatest, isTrue);

      controller.handleScrollNotification(
        ScrollUpdateNotification(
          metrics: _metrics(40),
          context: context,
          scrollDelta: 28,
        ),
      );
      expect(
        controller.showJumpToLatest,
        isTrue,
        reason: 'moving away must remain paused even inside the threshold',
      );

      controller.handleScrollNotification(
        ScrollUpdateNotification(
          metrics: _metrics(20),
          context: context,
          scrollDelta: -20,
        ),
      );
      expect(
        controller.showJumpToLatest,
        isFalse,
        reason: 'returning toward the near-bottom range resumes follow',
      );

      controller.handleScrollNotification(
        UserScrollNotification(
          metrics: _metrics(20),
          context: context,
          direction: ScrollDirection.idle,
        ),
      );
      controller.handleScrollNotification(
        ScrollUpdateNotification(
          metrics: _metrics(160),
          context: context,
          scrollDelta: 120,
        ),
      );
      expect(controller.showJumpToLatest, isFalse);
    },
  );
}

List<AgentChatTurnModel> _turns(int count) => List.generate(
  count,
  (index) => AgentChatTurnModel(
    ordinal: index,
    userMessage: UserMessage.text('turn $index'),
    userMessageIndex: index,
  ),
);

Future<void> _pumpThreadViewport(
  WidgetTester tester,
  AgentChatPanelController controller, {
  required List<AgentChatTurnModel> turns,
  required Widget live,
  required double Function(AgentChatTurnModel turn) turnHeight,
  double width = 600,
}) {
  return tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          height: 300,
          width: width,
          child: AgentChatThreadViewport(
            sessionId: 'a',
            turns: turns,
            controller: controller,
            horizontalPadding: 0,
            maxWidth: width,
            compactLayout: true,
            hasEarlier: false,
            historyLoading: false,
            prependAnchorEntryId: null,
            onLoadEarlier: null,
            live: live,
            turnBuilder: (context, turn, current) => SizedBox(
              height: turnHeight(turn),
              child: Text('turn ${turn.ordinal}'),
            ),
          ),
        ),
      ),
    ),
  );
}

RenderBox _sliverChildOf(WidgetTester tester, Finder finder) {
  RenderObject node = tester.renderObject(finder);
  while (node.parent is! RenderSliver) {
    node = node.parent!;
  }
  return node as RenderBox;
}

// Reads this frame's paint position so a one-frame-late correction shows up.
double _paintedBottomEdge(WidgetTester tester, Finder finder) {
  final child = _sliverChildOf(tester, finder);
  final parentData = child.parentData! as SliverMultiBoxAdaptorParentData;
  final sliver = child.parent! as RenderSliver;
  return parentData.layoutOffset! - sliver.constraints.scrollOffset;
}

double _paintedTopEdge(WidgetTester tester, Finder finder) =>
    _paintedBottomEdge(tester, finder) +
    _sliverChildOf(tester, finder).size.height;

List<double> _transcriptHeights() => List<double>.generate(
  20,
  (index) => index == 0 ? 120 : 80,
  growable: false,
);

AgentChatState _streamingState(String sessionId, {String token = 'token'}) =>
    AgentChatState(
      initialized: true,
      routeReady: true,
      activeSessionId: sessionId,
      status: AgentChatRunStatus.running,
      streamingMessage: AssistantMessage(
        content: [AssistantTextContent(token)],
        stopReason: StopReason.stop,
      ),
    );

FixedScrollMetrics _metrics(double pixels) => FixedScrollMetrics(
  minScrollExtent: 0,
  maxScrollExtent: 1200,
  pixels: pixels,
  viewportDimension: 300,
  axisDirection: AxisDirection.up,
  devicePixelRatio: 1,
);

Future<void> _pumpTranscript(
  WidgetTester tester,
  AgentChatPanelController controller,
  AgentChatState state,
  List<double> heights, {
  double viewportHeight = 300,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: viewportHeight,
          child: _Transcript(
            controller: controller,
            state: state,
            heights: heights,
          ),
        ),
      ),
    ),
  );
}

class _LifecycleProbe extends StatefulWidget {
  const _LifecycleProbe({
    super.key,
    required this.ordinal,
    required this.buildCounts,
  });

  final int ordinal;
  final Map<int, int> buildCounts;

  @override
  State<_LifecycleProbe> createState() => _LifecycleProbeState();
}

class _LifecycleProbeState extends State<_LifecycleProbe> {
  @override
  void initState() {
    super.initState();
    widget.buildCounts.update(
      widget.ordinal,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 700,
    child: Align(
      alignment: Alignment.topLeft,
      child: Text('probe ${widget.ordinal}'),
    ),
  );
}

class _Transcript extends StatelessWidget {
  const _Transcript({
    required this.controller,
    required this.state,
    required this.heights,
  });

  final AgentChatPanelController controller;
  final AgentChatState state;
  final List<double> heights;

  @override
  Widget build(BuildContext context) {
    controller.observe(state);
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: controller.handleScrollMetricsNotification,
      child: NotificationListener<ScrollNotification>(
        onNotification: controller.handleScrollNotification,
        child: ListView.builder(
          key: const ValueKey('transcript'),
          controller: controller.scrollController,
          reverse: true,
          itemCount: heights.length,
          itemBuilder: (context, index) => SizedBox(
            key: ValueKey('item-$index'),
            height: heights[index],
            child: Text('item $index'),
          ),
        ),
      ),
    );
  }
}
