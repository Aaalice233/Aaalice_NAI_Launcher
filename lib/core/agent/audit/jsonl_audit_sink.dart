import 'dart:convert';
import 'dart:io';

import 'audit_event.dart';
import 'audit_sink.dart';

class JsonlAgentAuditSink implements AgentAuditSink {
  JsonlAgentAuditSink(this.file);

  final File file;
  Future<void> _pendingWrite = Future.value();

  @override
  Future<void> write(AgentAuditEvent event) {
    final write = _pendingWrite.then((_) async {
      await file.parent.create(recursive: true);
      await file.writeAsString(
        '${jsonEncode(event.toJson())}\n',
        mode: FileMode.append,
        flush: true,
      );
    });
    // Keep the queue usable after surfacing an individual write failure.
    _pendingWrite = write.catchError((_) {});
    return write;
  }
}
