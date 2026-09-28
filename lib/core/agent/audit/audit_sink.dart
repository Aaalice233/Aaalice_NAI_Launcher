import 'audit_event.dart';

abstract interface class AgentAuditSink {
  Future<void> write(AgentAuditEvent event);
}

class MemoryAgentAuditSink implements AgentAuditSink {
  final List<AgentAuditEvent> _events = [];

  List<AgentAuditEvent> get events => List.unmodifiable(_events);

  @override
  Future<void> write(AgentAuditEvent event) async {
    _events.add(event);
  }
}

typedef StructuredAgentAuditWriter =
    Future<void> Function(Map<String, dynamic> event);

/// Adapts logging or storage systems that accept structured values.
class StructuredAgentAuditSink implements AgentAuditSink {
  const StructuredAgentAuditSink(this.writer);

  final StructuredAgentAuditWriter writer;

  @override
  Future<void> write(AgentAuditEvent event) => writer(event.toJson());
}
