import 'agent_types.dart';
import 'harness/compaction/compaction.dart';

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

/// Resolves current context use from the last successful non-zero assistant
/// usage plus locally estimated trailing messages. Without such an anchor the
/// token count remains unknown rather than presenting a whole-history guess.
AgentContextUsage resolveAgentContextUsage(
  List<AgentMessage> messages, {
  required int? contextWindow,
}) {
  final estimate = estimateContextTokens(messages);
  final tokens = estimate.lastUsageIndex == null ? null : estimate.tokens;
  final validWindow = contextWindow != null && contextWindow > 0
      ? contextWindow
      : null;
  return AgentContextUsage(
    tokens: tokens,
    contextWindow: validWindow,
    percent: tokens != null && validWindow != null
        ? tokens / validWindow * 100
        : null,
    estimated: tokens != null && estimate.trailingTokens > 0,
  );
}
