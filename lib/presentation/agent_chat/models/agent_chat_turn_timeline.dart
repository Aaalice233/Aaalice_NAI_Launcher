import '../../../core/agent/agent.dart';
import '../../../core/agent/harness/session/session_types.dart';
import 'agent_chat_prompt_envelope.dart';

enum AgentChatTurnStatus { running, completed, failed, aborted, interrupted }

enum AgentChatTimelineItemKind {
  userMessage,
  assistantMessage,
  toolCall,
  toolResult,
  customMessage,
}

/// Stable cursor for prepending an older history page without relying on a
/// transient list index. [parentEntryId] is also the viewport anchor identity.
class AgentChatHistoryCursor {
  const AgentChatHistoryCursor({
    required this.beforeSeq,
    required this.parentEntryId,
  });

  final int beforeSeq;
  final String? parentEntryId;
}

class AgentChatTimelineItem {
  const AgentChatTimelineItem({
    required this.id,
    required this.entryId,
    required this.seq,
    required this.parentEntryId,
    required this.kind,
    required this.timestamp,
    this.toolCallId,
    this.toolName,
    this.isError = false,
  });

  final String id;
  final String entryId;
  final int seq;
  final String? parentEntryId;
  final AgentChatTimelineItemKind kind;
  final int? timestamp;
  final String? toolCallId;
  final String? toolName;
  final bool isError;
}

class AgentChatTurnTimeline {
  const AgentChatTurnTimeline({
    required this.id,
    required this.status,
    required this.items,
    required this.firstSeq,
    required this.lastSeq,
    this.startedAt,
    this.completedAt,
    this.duration,
    this.error,
  });

  final String id;
  final AgentChatTurnStatus status;
  final List<AgentChatTimelineItem> items;
  final int firstSeq;
  final int lastSeq;
  final int? startedAt;
  final int? completedAt;

  /// Null unless both lifecycle timestamps came from durable runtime records.
  final Duration? duration;
  final String? error;
}

class AgentChatTimelinePage {
  const AgentChatTimelinePage({
    required this.turns,
    required this.messages,
    required this.entries,
    required this.hasEarlier,
    this.earlierCursor,
    this.prependAnchorEntryId,
  });

  final List<AgentChatTurnTimeline> turns;
  final List<Message> messages;
  final List<MessageEntry> entries;
  final bool hasEarlier;
  final AgentChatHistoryCursor? earlierCursor;
  final String? prependAnchorEntryId;
}

/// Projects durable branch entries and lane records into the UI timeline.
/// Entries and records remain the source of truth; this projection is safe to
/// rebuild after reload, rewind, and forks.
AgentChatTimelinePage buildAgentChatTimelinePage({
  required List<MessageEntry> entries,
  required List<LaneRecord> records,
  required bool hasEarlier,
  String? prependAnchorEntryId,
  String? activeTurnId,
}) {
  final orderedEntries = [...entries]..sort((a, b) => a.seq.compareTo(b.seq));
  final starts = records.whereType<OperationStartedRecord>().toList()
    ..sort((a, b) => a.seq.compareTo(b.seq));
  final finishes = <String, OperationFinishedRecord>{};
  for (final record in records.whereType<OperationFinishedRecord>()) {
    final existing = finishes[record.runId];
    if (existing == null || record.seq < existing.seq) {
      finishes[record.runId] = record;
    }
  }
  final toolRecords = <String, ToolStartedRecord>{
    for (final record in records.whereType<ToolStartedRecord>())
      record.toolCallId: record,
  };

  final builders = <String, _TurnBuilder>{};
  String? legacyTurnId;
  var startIndex = -1;
  for (final entry in orderedEntries) {
    // A finish records lifecycle state, not the message boundary. Some event
    // sources persist the final assistant message immediately after the finish;
    // it still belongs to this operation until the next operation starts.
    while (startIndex + 1 < starts.length &&
        starts[startIndex + 1].seq < entry.seq) {
      startIndex++;
    }
    final operation = startIndex < 0 ? null : starts[startIndex];
    if (operation == null && isVisualUserMessage(entry.message)) {
      legacyTurnId = 'legacy:${entry.id}';
    }
    final turnId = operation?.id ?? legacyTurnId ?? 'legacy:${entry.id}';
    final builder = builders.putIfAbsent(
      turnId,
      () => _TurnBuilder(
        id: turnId,
        startedAt: operation?.timestamp.validTimestamp,
        startSeq: operation?.seq,
        finish: operation == null ? null : finishes[operation.id],
        active: operation?.id == activeTurnId,
      ),
    );
    builder.addEntry(entry, toolRecords);
  }

  final turns = builders.values.map((builder) => builder.build()).toList()
    ..sort((a, b) => a.firstSeq.compareTo(b.firstSeq));
  final oldest = orderedEntries.firstOrNull;
  return AgentChatTimelinePage(
    turns: turns,
    messages: [for (final entry in orderedEntries) entry.message],
    entries: orderedEntries,
    hasEarlier: hasEarlier,
    earlierCursor: hasEarlier && oldest != null
        ? AgentChatHistoryCursor(
            beforeSeq: oldest.seq,
            parentEntryId: oldest.parentId,
          )
        : null,
    prependAnchorEntryId: prependAnchorEntryId,
  );
}


class _TurnBuilder {
  _TurnBuilder({
    required this.id,
    required this.startedAt,
    required this.startSeq,
    required this.finish,
    required this.active,
  });

  final String id;
  final int? startedAt;
  final int? startSeq;
  final OperationFinishedRecord? finish;
  final bool active;
  final List<AgentChatTimelineItem> items = [];

  void addEntry(
    MessageEntry entry,
    Map<String, ToolStartedRecord> toolRecords,
  ) {
    final message = entry.message;
    items.add(
      AgentChatTimelineItem(
        id: 'entry:${entry.id}',
        entryId: entry.id,
        seq: entry.seq,
        parentEntryId: entry.parentId,
        kind: switch (message) {
          UserMessage() => AgentChatTimelineItemKind.userMessage,
          AssistantMessage() => AgentChatTimelineItemKind.assistantMessage,
          ToolResultMessage() => AgentChatTimelineItemKind.toolResult,
          _ => AgentChatTimelineItemKind.customMessage,
        },
        timestamp: entry.timestamp.validTimestamp,
        toolCallId: message is ToolResultMessage ? message.toolCallId : null,
        toolName: message is ToolResultMessage ? message.toolName : null,
        isError: message is ToolResultMessage && message.isError,
      ),
    );
    if (message is AssistantMessage) {
      for (final call in message.toolCalls) {
        final record = toolRecords[call.id];
        items.add(
          AgentChatTimelineItem(
            id: 'call:${call.id}',
            entryId: entry.id,
            seq: record?.seq ?? entry.seq,
            parentEntryId: entry.parentId,
            kind: AgentChatTimelineItemKind.toolCall,
            timestamp: record?.timestamp.validTimestamp,
            toolCallId: call.id,
            toolName: call.name,
          ),
        );
      }
    }
  }

  AgentChatTurnTimeline build() {
    items.sort((a, b) => a.seq.compareTo(b.seq));
    final completedAt = finish?.timestamp.validTimestamp;
    final duration = startedAt != null && completedAt != null
        ? Duration(milliseconds: completedAt - startedAt!)
        : null;
    final outcome = finish?.outcome;
    return AgentChatTurnTimeline(
      id: id,
      status: outcome == null
          ? active
                ? AgentChatTurnStatus.running
                : startSeq == null
                ? AgentChatTurnStatus.completed
                : AgentChatTurnStatus.interrupted
          : switch (outcome) {
              OperationOutcomeKind.completed => AgentChatTurnStatus.completed,
              OperationOutcomeKind.failed => AgentChatTurnStatus.failed,
              OperationOutcomeKind.aborted ||
              OperationOutcomeKind.declined => AgentChatTurnStatus.aborted,
            },
      items: List.unmodifiable(items),
      firstSeq: items.firstOrNull?.seq ?? startSeq ?? 0,
      lastSeq: items.lastOrNull?.seq ?? finish?.seq ?? startSeq ?? 0,
      startedAt: startedAt,
      completedAt: completedAt,
      duration: duration != null && !duration.isNegative ? duration : null,
      error: finish?.error?.message,
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
  T? get lastOrNull => isEmpty ? null : last;
}

extension on int {
  int? get validTimestamp => this > 0 ? this : null;
}
