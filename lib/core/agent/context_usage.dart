import 'agent_types.dart';
import 'harness/compaction/compaction.dart';
import 'harness/harness_messages.dart';

/// Current model-context occupancy using Pi's last-valid-usage anchor semantics.
class AgentContextUsage {
  const AgentContextUsage({
    required this.tokens,
    required this.contextWindow,
    required this.percent,
    required this.estimated,
  });

  const AgentContextUsage.unknown({int? contextWindow})
    : this(
        tokens: null,
        contextWindow: contextWindow,
        percent: null,
        estimated: false,
      );

  final int? tokens;
  final int? contextWindow;
  final double? percent;

  /// True when messages after the provider usage anchor were locally estimated.
  final bool estimated;

  bool get available =>
      tokens != null && contextWindow != null && contextWindow! > 0;

  Map<String, dynamic> toJson() => {
    if (tokens != null) 'tokens': tokens,
    if (contextWindow != null) 'contextWindow': contextWindow,
    if (percent != null) 'percent': percent,
    'estimated': estimated,
  };
}

/// Mirrors Pi's context-usage contract: use the latest valid provider usage as
/// an anchor and estimate trailing messages; when no anchor exists, estimate
/// the complete context. Immediately after compaction the pre-compaction
/// anchor is invalid, so usage remains unknown until a later assistant response.
AgentContextUsage resolveAgentContextUsage(
  List<AgentMessage> messages, {
  required int? contextWindow,
}) {
  if (contextWindow == null || contextWindow <= 0) {
    return const AgentContextUsage.unknown();
  }
  final validWindow = contextWindow;
  final estimate = estimateContextTokens(messages);
  final latestCompactionIndex = messages.lastIndexWhere(
    (message) => message is CompactionSummaryMessage,
  );
  final compactionBoundary = latestCompactionIndex < 0
      ? -1
      : latestCompactionIndex +
            (messages[latestCompactionIndex] as CompactionSummaryMessage)
                .retainedTailLength;
  final anchorIndex = estimate.lastUsageIndex;
  final hasPostCompactionAnchor =
      latestCompactionIndex < 0 ||
      (anchorIndex != null && anchorIndex > compactionBoundary);
  final tokens = hasPostCompactionAnchor ? estimate.tokens : null;

  return AgentContextUsage(
    tokens: tokens,
    contextWindow: validWindow,
    percent: tokens != null && validWindow != null
        ? tokens / validWindow * 100
        : null,
    estimated: tokens != null && estimate.trailingTokens > 0,
  );
}
