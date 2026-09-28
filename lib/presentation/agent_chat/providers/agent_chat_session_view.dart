import '../../../core/agent/harness/session/session_types.dart';

/// 会话列表条目（UI 视图）。
class AgentChatSessionSummary {
  const AgentChatSessionSummary({
    required this.metadata,
    required this.name,
    required this.updatedAt,
  });

  final SessionMetadata metadata;
  final String name;
  final DateTime updatedAt;

  String get id => metadata.id;
}
