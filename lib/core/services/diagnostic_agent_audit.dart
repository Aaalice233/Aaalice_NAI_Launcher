import 'dart:convert';

import 'package:crypto/crypto.dart';
import '../agent/permissions/agent_permission.dart';

/// Export only permission metadata. Tool error text can contain user content,
/// so it is classified locally and is never copied into the diagnostics ZIP.
abstract final class DiagnosticAgentAudit {
  static String sanitizeLine(String line) {
    try {
      final value = jsonDecode(line);
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Expected an audit object');
      }
      final timestamp = DateTime.tryParse('${value['timestamp']}');
      final result = AgentPermissionDecision.values
          .where((decision) => decision.name == value['result'])
          .firstOrNull;
      if (timestamp == null || result == null) {
        throw const FormatException('Invalid audit metadata');
      }
      final summary = value['summary'];
      final error = value['error'];
      final id = '${value['id']}';
      final phase = RegExp(r'\.(decision|approval|result)$').firstMatch(id);
      return jsonEncode({
        'timestamp': timestamp.toUtc().toIso8601String(),
        'toolCallIdHash': sha256
            .convert(
              utf8.encode(phase == null ? id : id.substring(0, phase.start)),
            )
            .toString(),
        if (phase != null) 'phase': phase.group(1),
        'result': result.name,
        'summary': summary is String && _summary.hasMatch(summary)
            ? summary
            : '[REDACTED AUDIT SUMMARY]',
        if (error != null) 'errorCategory': _errorCategory(error),
      });
    } on FormatException {
      // A snapshot can end in a partial append; never export its raw content.
      return jsonEncode({'diagnostic': 'invalid_or_incomplete_audit_record'});
    }
  }

  static final _summary = RegExp(
    r'^[a-z][a-z0-9_]* (?:completed|user approval|permission catalog unavailable|'
    '(?:${AgentPermissionDomain.values.map((value) => value.name).join('|')})'
    '/(?:${AgentPermissionOperation.values.map((value) => value.name).join('|')}))\$',
  );

  static String _errorCategory(Object error) {
    if (error is! String) return 'tool_error';
    if (error.contains('blocked by its permission domain policy')) {
      return 'permission_policy';
    }
    if (error.contains('user declined this tool call')) {
      return 'approval_declined';
    }
    if (error.contains('Image path is not permitted')) return 'image_path';
    if (error.contains('resource_ref') ||
        error.contains('resource reference') ||
        error.contains('Lists and byte payloads are not allowed')) {
      return 'resource_reference';
    }
    return 'tool_error';
  }
}
