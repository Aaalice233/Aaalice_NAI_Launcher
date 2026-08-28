import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/audit/audit.dart';
import 'package:nai_launcher/core/agent/permissions/permissions.dart';

void main() {
  group('AgentAuditEvent', () {
    test('contains only stable, sanitized fields', () {
      final event = AgentAuditEvent(
        id: 'call-42',
        summary:
            r'Read C:\Users\alice\secret.txt with token=super-secret-value',
        result: AgentPermissionDecision.block,
        error: 'Bearer abc.def.ghi ${List.filled(48, 'A').join()}',
        timestamp: DateTime.parse('2026-03-01T12:00:00+08:00'),
      );

      expect(event.toJson(), {
        'id': 'call-42',
        'summary': 'Read [REDACTED_PATH] with token=[REDACTED_TOKEN]',
        'result': 'block',
        'error': 'Bearer [REDACTED_TOKEN] [REDACTED_BASE64]',
        'timestamp': '2026-03-01T04:00:00.000Z',
      });
      expect(AgentAuditEvent.fromJson(event.toJson()).toJson(), event.toJson());
    });

    test('sanitizes Unix paths, data URIs, and JWT values', () {
      const jwt = 'eyJabcdefghijk.abcdefghijklmnop.signature';
      final sanitized = AgentAuditSanitizer.sanitize(
        'open /home/alice/private.png; image=data:image/png;base64,'
        '${List.filled(48, 'Z').join()}; auth=$jwt',
      );

      expect(sanitized, contains('[REDACTED_PATH]'));
      expect(sanitized, contains('data:image/png;base64,[REDACTED_BASE64]'));
      expect(sanitized, contains('[REDACTED_TOKEN]'));
      expect(sanitized, isNot(contains('/home/alice')));
      expect(sanitized, isNot(contains(jwt)));
    });

    test('sanitizes standalone NovelAI persistent tokens', () {
      const token = 'pst-abcdefghijklmnopqrstuvwxyz123456';
      final sanitized = AgentAuditSanitizer.sanitize('failed with $token');

      expect(sanitized, 'failed with [REDACTED_TOKEN]');
    });

    test('rejects unstable IDs', () {
      expect(
        () => AgentAuditEvent(
          id: 'contains a secret',
          summary: 'summary',
          result: AgentPermissionDecision.allow,
          timestamp: DateTime.now(),
        ),
        throwsArgumentError,
      );
    });
  });

  test('memory and structured sinks receive events', () async {
    final event = AgentAuditEvent(
      id: 'event-1',
      summary: 'Read status',
      result: AgentPermissionDecision.allow,
      timestamp: DateTime.utc(2026),
    );
    final memory = MemoryAgentAuditSink();
    Map<String, dynamic>? structured;
    final structuredSink = StructuredAgentAuditSink((value) async {
      structured = value;
    });

    await memory.write(event);
    await structuredSink.write(event);

    expect(memory.events, [event]);
    expect(structured, event.toJson());
    expect(() => memory.events.add(event), throwsUnsupportedError);
  });

  test('JSONL sink appends complete records in write order', () async {
    final directory = await Directory.systemTemp.createTemp('agent-audit-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}audit.jsonl');
    final sink = JsonlAgentAuditSink(file);

    final writes = [
      for (var index = 0; index < 3; index++)
        sink.write(
          AgentAuditEvent(
            id: 'event-$index',
            summary: 'event $index',
            result: AgentPermissionDecision.allow,
            timestamp: DateTime.utc(2026, 1, index + 1),
          ),
        ),
    ];
    await Future.wait(writes);

    final records = await file.readAsLines().then(
      (lines) => lines.map(jsonDecode).toList(),
    );
    expect(records.map((record) => record['id']), [
      'event-0',
      'event-1',
      'event-2',
    ]);
  });
}
