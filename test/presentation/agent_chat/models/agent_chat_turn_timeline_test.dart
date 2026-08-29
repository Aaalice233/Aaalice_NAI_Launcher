import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent.dart';
import 'package:nai_launcher/core/agent/harness/session/session_types.dart';
import 'package:nai_launcher/presentation/agent_chat/models/agent_chat_turn_timeline.dart';

void main() {
  test('start, tool call, result, and end rebuild one durable turn', () {
    final entries = [
      MessageEntry(
        id: 'user-1',
        seq: 2,
        timestamp: 110,
        message: UserMessage.text('inspect'),
      ),
      MessageEntry(
        id: 'assistant-1',
        seq: 3,
        parentId: 'user-1',
        timestamp: 120,
        message: AssistantMessage(
          content: const [
            ToolCallContent(id: 'call-1', name: 'read', arguments: {}),
          ],
          stopReason: StopReason.toolUse,
          timestamp: 120,
        ),
      ),
      MessageEntry(
        id: 'result-1',
        seq: 5,
        parentId: 'assistant-1',
        timestamp: 180,
        message: ToolResultMessage(
          toolCallId: 'call-1',
          toolName: 'read',
          content: const [ToolResultTextContent('done')],
          timestamp: 180,
        ),
      ),
      MessageEntry(
        id: 'assistant-2',
        seq: 6,
        parentId: 'result-1',
        timestamp: 200,
        message: AssistantMessage(
          content: const [AssistantTextContent('finished')],
          stopReason: StopReason.stop,
          timestamp: 200,
        ),
      ),
    ];
    final records = <LaneRecord>[
      OperationStartedRecord(
        id: 'turn-1',
        lane: 'main',
        sourceLeafId: null,
        intent: const RunIntent(kind: RunIntentKind.run),
        seq: 1,
        timestamp: 100,
      ),
      ToolStartedRecord(
        id: 'tool-1',
        lane: 'main',
        runId: 'turn-1',
        assistantEntryId: 'assistant-1',
        toolIndex: 0,
        toolCallId: 'call-1',
        toolName: 'read',
        effectiveArgs: const {},
        resultEntryId: 'result-1',
        replay: ReplayMode.never,
        seq: 4,
        timestamp: 130,
      ),
      OperationFinishedRecord(
        id: 'finish-1',
        lane: 'main',
        runId: 'turn-1',
        outcome: OperationOutcomeKind.completed,
        seq: 7,
        timestamp: 220,
      ),
    ];

    final page = buildAgentChatTimelinePage(
      entries: entries,
      records: records,
      hasEarlier: false,
    );
    final reloaded = buildAgentChatTimelinePage(
      entries: List.of(entries),
      records: List.of(records),
      hasEarlier: false,
    );

    expect(page.turns.single.id, 'turn-1');
    expect(page.turns.single.status, AgentChatTurnStatus.completed);
    expect(page.turns.single.duration, const Duration(milliseconds: 120));
    expect(
      page.turns.single.items
          .where(
            (item) => item.kind == AgentChatTimelineItemKind.assistantMessage,
          )
          .last
          .entryId,
      'assistant-2',
    );
    expect(
      page.turns.single.items
          .where((item) => item.kind == AgentChatTimelineItemKind.toolCall)
          .single
          .toolCallId,
      'call-1',
    );
    expect(
      page.turns.single.items
          .where((item) => item.kind == AgentChatTimelineItemKind.toolResult)
          .single
          .toolCallId,
      'call-1',
    );
    expect(reloaded.turns.single.id, page.turns.single.id);
  });

  test('final assistant persisted after finish stays in the finished turn', () {
    final entries = [
      MessageEntry(id: 'user-1', seq: 2, message: UserMessage.text('first')),
      MessageEntry(
        id: 'assistant-1',
        seq: 4,
        parentId: 'user-1',
        message: AssistantMessage(
          content: const [AssistantTextContent('final after finish')],
          stopReason: StopReason.stop,
        ),
      ),
      MessageEntry(
        id: 'user-2',
        seq: 6,
        parentId: 'assistant-1',
        message: UserMessage.text('second'),
      ),
    ];
    final records = <LaneRecord>[
      OperationStartedRecord(
        id: 'turn-1',
        lane: 'main',
        sourceLeafId: null,
        intent: const RunIntent(kind: RunIntentKind.run),
        seq: 1,
      ),
      OperationFinishedRecord(
        id: 'finish-1',
        lane: 'main',
        runId: 'turn-1',
        outcome: OperationOutcomeKind.completed,
        seq: 3,
      ),
      OperationStartedRecord(
        id: 'turn-2',
        lane: 'main',
        sourceLeafId: 'assistant-1',
        intent: const RunIntent(kind: RunIntentKind.run),
        seq: 5,
      ),
    ];

    final page = buildAgentChatTimelinePage(
      entries: entries,
      records: records,
      hasEarlier: false,
      activeTurnId: 'turn-2',
    );

    expect(page.turns, hasLength(2));
    expect(page.turns.first.id, 'turn-1');
    expect(
      page.turns.first.items.map((item) => item.entryId),
      containsAll(<String>['user-1', 'assistant-1']),
    );
    expect(page.turns.first.status, AgentChatTurnStatus.completed);
    expect(page.turns.last.id, 'turn-2');
    expect(page.turns.last.status, AgentChatTurnStatus.running);
  });

  test('unfinished operation becomes interrupted when a new turn starts', () {
    final page = buildAgentChatTimelinePage(
      entries: [
        MessageEntry(id: 'user-1', seq: 2, message: UserMessage.text('stale')),
        MessageEntry(
          id: 'user-2',
          seq: 4,
          parentId: 'user-1',
          message: UserMessage.text('current'),
        ),
      ],
      records: <LaneRecord>[
        OperationStartedRecord(
          id: 'turn-1',
          lane: 'main',
          sourceLeafId: null,
          intent: const RunIntent(kind: RunIntentKind.run),
          seq: 1,
        ),
        OperationStartedRecord(
          id: 'turn-2',
          lane: 'main',
          sourceLeafId: 'user-1',
          intent: const RunIntent(kind: RunIntentKind.run),
          seq: 3,
        ),
      ],
      hasEarlier: false,
      activeTurnId: 'turn-2',
    );

    expect(page.turns, hasLength(2));
    expect(page.turns.first.status, AgentChatTurnStatus.interrupted);
    expect(page.turns.last.status, AgentChatTurnStatus.running);
  });

  test('legacy and fork projections keep entry identity without duration', () {
    final entries = [
      MessageEntry(
        id: 'preserved-user',
        seq: 1,
        message: UserMessage.text('legacy'),
      ),
      MessageEntry(
        id: 'preserved-assistant',
        seq: 2,
        parentId: 'preserved-user',
        message: AssistantMessage(
          content: const [AssistantTextContent('reply')],
          stopReason: StopReason.stop,
        ),
      ),
    ];

    final original = buildAgentChatTimelinePage(
      entries: entries,
      records: const [],
      hasEarlier: true,
    );
    final fork = buildAgentChatTimelinePage(
      entries: [for (final entry in entries) entry],
      records: const [],
      hasEarlier: true,
    );

    expect(original.turns.single.id, 'legacy:preserved-user');
    expect(original.turns.single.duration, isNull);
    expect(fork.turns.single.id, original.turns.single.id);
    expect(original.earlierCursor!.beforeSeq, 1);
    expect(original.earlierCursor!.parentEntryId, isNull);
  });
}
