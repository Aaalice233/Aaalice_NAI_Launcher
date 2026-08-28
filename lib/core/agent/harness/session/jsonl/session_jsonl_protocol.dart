import '../session_types.dart';

/// Stable operation names written to a session JSONL stream.
abstract final class SessionJsonlProtocol {
  static const header = 'header';
  static const entry = 'entry';
  static const record = 'record';
  static const lane = 'lane';
  static const fact = 'fact';

  static Map<String, dynamic> encodeHeader(SessionMetadata metadata) => {
    'op': header,
    'id': metadata.id,
    'createdAt': metadata.createdAt,
    'parentSessionId': metadata.parentSessionId,
  };

  static SessionMetadata? decodeHeader(Object? value) {
    if (value is! Map<String, dynamic> || value['op'] != header) return null;
    return SessionMetadata(
      id: value['id'] as String? ?? '',
      createdAt: (value['createdAt'] as num?)?.toInt() ?? 0,
      parentSessionId: value['parentSessionId'] as String?,
    );
  }
}
