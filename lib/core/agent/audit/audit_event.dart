import '../permissions/agent_permission.dart';
import 'audit_sanitizer.dart';

/// Minimal persisted record of one agent permission decision or tool outcome.
class AgentAuditEvent {
  AgentAuditEvent({
    required String id,
    required String summary,
    required this.result,
    required DateTime timestamp,
    String? error,
  }) : id = _validatedId(id),
       summary = AgentAuditSanitizer.sanitize(summary),
       error = error == null ? null : AgentAuditSanitizer.sanitize(error),
       timestamp = timestamp.toUtc();

  final String id;
  final String summary;
  final AgentPermissionDecision result;
  final String? error;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
    'id': id,
    'summary': summary,
    'result': result.name,
    if (error != null) 'error': error,
    'timestamp': timestamp.toIso8601String(),
  };

  factory AgentAuditEvent.fromJson(Map<String, dynamic> json) {
    return AgentAuditEvent(
      id: json['id'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      result: AgentPermissionDecision.values.firstWhere(
        (value) => value.name == json['result'],
        orElse: () =>
            throw FormatException('Unknown audit result: ${json['result']}'),
      ),
      error: json['error'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  static String _validatedId(String id) {
    if (id.isEmpty || !RegExp(r'^[A-Za-z0-9._:-]+$').hasMatch(id)) {
      throw ArgumentError.value(id, 'id', 'Must be a non-empty stable ID');
    }
    return id;
  }
}
