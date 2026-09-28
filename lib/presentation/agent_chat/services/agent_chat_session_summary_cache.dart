import '../../../core/agent/harness/session/session.dart';
import '../../../core/agent/harness/session/session_jsonl.dart';
import '../providers/agent_chat_session_view.dart';
import 'agent_chat_session_naming.dart';

/// Session list names, reused while the backing JSONL file is unchanged.
///
/// The list header carries no name, so a name still costs one replay. Files are
/// fingerprinted by modification time and size because Windows timestamps are
/// too coarse to catch an append on their own.
class AgentChatSessionSummaryCache {
  AgentChatSessionSummaryCache({
    required JsonlSessionRepo repository,
    Future<Session> Function(SessionMetadata metadata)? openSession,
  }) : _repository = repository,
       _openSession = openSession ?? repository.open;

  final JsonlSessionRepo _repository;
  final Future<Session> Function(SessionMetadata metadata) _openSession;
  final Map<String, _CachedName> _names = {};

  Future<List<AgentChatSessionSummary>> list() async {
    final listings = await _repository.listWithFileInfo();
    final resolved = <String, _CachedName>{};
    final summaries = <AgentChatSessionSummary>[];
    for (final listing in listings) {
      final cached = _names[listing.path];
      final name = cached != null && cached.matches(listing)
          ? cached.name
          : await _readName(listing.metadata);
      resolved[listing.path] = _CachedName(
        name: name,
        modifiedAt: listing.modifiedAt,
        size: listing.size,
      );
      summaries.add(
        AgentChatSessionSummary(
          metadata: listing.metadata,
          name: name,
          updatedAt: listing.modifiedAt,
        ),
      );
    }
    _names
      ..clear()
      ..addAll(resolved);
    return summaries;
  }

  /// Persisted name first, then the earliest user turn.
  Future<String> _readName(SessionMetadata metadata) async {
    final Session session;
    try {
      session = await _openSession(metadata);
    } catch (_) {
      return '';
    }
    var name = '';
    try {
      name = (await session.getName())?.trim() ?? '';
    } catch (_) {
      name = '';
    }
    if (name.isNotEmpty) return name;
    try {
      return await AgentChatSessionNaming.fromHistory(session);
    } catch (_) {
      return '';
    }
  }
}

class _CachedName {
  const _CachedName({
    required this.name,
    required this.modifiedAt,
    required this.size,
  });

  final String name;
  final DateTime modifiedAt;
  final int size;

  bool matches(SessionFileInfo listing) =>
      modifiedAt == listing.modifiedAt && size == listing.size;
}
