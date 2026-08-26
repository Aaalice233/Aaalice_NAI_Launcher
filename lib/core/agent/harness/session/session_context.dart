import '../../agent_types.dart';
import '../harness_messages.dart';
import 'session_types.dart';


class SessionContext {
  const SessionContext({
    required this.messages,
    required this.thinkingLevel,
    required this.model,
    required this.activeToolNames,
  });

  final List<AgentMessage> messages;
  final String thinkingLevel;
  final ({String provider, String modelId})? model;
  final List<String>? activeToolNames;
}

typedef ContextEntryTransform = List<SessionEntry> Function(
  List<SessionEntry> entries,
);

typedef CustomEntryContextMessageProjector = List<AgentMessage>? Function(
  CustomEntry entry,
  int index,
  List<SessionEntry> entries,
);

class SessionContextBuildOptions {
  const SessionContextBuildOptions({
    this.entryTransforms,
    this.entryProjectors,
  });

  final List<ContextEntryTransform>? entryTransforms;
  final Map<String, CustomEntryContextMessageProjector>? entryProjectors;
}

({String thinkingLevel, ({String provider, String modelId})? model,
        List<String>? activeToolNames})
    _deriveSessionContextState(List<SessionEntry> pathEntries) {
  var thinkingLevel = 'off';
  ({String provider, String modelId})? model;
  List<String>? activeToolNames;

  for (final entry in pathEntries) {
    if (entry is ThinkingLevelEntry) {
      thinkingLevel = entry.thinkingLevel;
    } else if (entry is ModelChangeEntry) {
      model = (provider: entry.provider, modelId: entry.modelId);
    } else if (entry is MessageEntry && entry.message is AssistantMessage) {
      final assistant = entry.message as AssistantMessage;
      if (assistant.provider != null && assistant.model != null) {
        model = (provider: assistant.provider!, modelId: assistant.model!);
      }
    } else if (entry is ActiveToolsEntry) {
      activeToolNames = List.of(entry.activeToolNames);
    }
  }

  return (
    thinkingLevel: thinkingLevel,
    model: model,
    activeToolNames: activeToolNames,
  );
}

/// 默认变换：折叠最后一次 compaction 之前的历史。
List<SessionEntry> defaultContextEntryTransform(
  List<SessionEntry> pathEntries,
) {
  CompactionEntry? compaction;
  var compactionIndex = -1;
  for (var index = pathEntries.length - 1; index >= 0; index--) {
    final entry = pathEntries[index];
    if (entry is CompactionEntry) {
      compaction = entry;
      compactionIndex = index;
      break;
    }
  }
  if (compaction == null) {
    return List.of(pathEntries);
  }
  return [compaction, ...pathEntries.sublist(compactionIndex + 1)];
}

List<SessionEntry> buildContextEntries(
  List<SessionEntry> pathEntries, [
  SessionContextBuildOptions? options,
]) {
  var entries = defaultContextEntryTransform(pathEntries);
  for (final transform in options?.entryTransforms ?? const []) {
    entries = transform(entries);
  }
  return entries;
}

List<AgentMessage> sessionEntryToContextMessages(
  SessionEntry entry,
  int index,
  List<SessionEntry> entries, [
  SessionContextBuildOptions? options,
]) {
  if (entry is MessageEntry) {
    final message = entry.message;
    if (message is AssistantMessage) {
      if (message.stopReason == StopReason.deferred ||
          !isReplayableAssistantMessage(message)) {
        return const [];
      }
    }
    return [message];
  }
  if (entry is CompactionEntry) {
    return [
      createCompactionSummaryMessage(
        entry.summary,
        entry.tokensBefore,
        entry.timestamp,
      ),
      ...entry.retainedTail,
    ];
  }
  if (entry is BranchSummaryEntry && entry.summary.isNotEmpty) {
    return [
      createBranchSummaryMessage(entry.summary, entry.fromId, entry.timestamp),
    ];
  }
  if (entry is CustomEntry) {
    final projector = options?.entryProjectors?[entry.customType];
    final projected = projector?.call(entry, index, entries);
    return projected == null ? const [] : List.of(projected);
  }
  return const [];
}

SessionContext buildSessionContext(
  List<SessionEntry> pathEntries, [
  SessionContextBuildOptions? options,
]) {
  final state = _deriveSessionContextState(pathEntries);
  final contextEntries = buildContextEntries(pathEntries, options);
  final messages = <AgentMessage>[];
  for (var index = 0; index < contextEntries.length; index++) {
    messages.addAll(
      sessionEntryToContextMessages(
        contextEntries[index],
        index,
        contextEntries,
        options,
      ),
    );
  }
  return SessionContext(
    messages: messages,
    thinkingLevel: state.thinkingLevel,
    model: state.model,
    activeToolNames: state.activeToolNames,
  );
}
