import '../../../core/agent/harness/session/session.dart';
import '../models/agent_chat_prompt_envelope.dart';

/// The name an unnamed session is auto-named and listed with.
///
/// Auto-naming and the list fallback must agree, so both resolve the earliest
/// user turn that carries visible text and share one length limit.
abstract final class AgentChatSessionNaming {
  static const lengthLimit = 40;

  static final _whitespace = RegExp(r'\s+');

  static String fromText(String text) {
    final normalized = text.replaceAll(_whitespace, ' ').trim();
    if (normalized.length <= lengthLimit) return normalized;
    return '${normalized.substring(0, lengthLimit)}…';
  }

  /// Empty when the branch carries no user turn with visible text.
  static Future<String> fromHistory(Session session) async {
    final entries = await session.findEntriesOnBranch(
      const EntryQuery(type: 'message', order: EntryOrder.oldestFirst),
    );
    for (final entry in entries) {
      if (entry is! MessageEntry) continue;
      final message = visibleUserMessage(entry.message);
      if (message == null) continue;
      final name = fromText(message.text);
      if (name.isNotEmpty) return name;
    }
    return '';
  }
}
