import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/services/diagnostic_agent_audit.dart';

void main() {
  Map<String, dynamic> project(
    String phase, {
    String? error,
    String? summary,
  }) =>
      jsonDecode(
            DiagnosticAgentAudit.sanitizeLine(
              jsonEncode({
                'id': 'call-1.$phase',
                'timestamp': '2026-09-06T13:37:00Z',
                'result': 'allow',
                'summary': summary ?? 'interrogate_image generation/read',
                if (error != null) 'error': error,
              }),
            ),
          )
          as Map<String, dynamic>;

  test('correlates phases while retaining only controlled metadata', () {
    final decision = project('decision');
    final result = project('result', summary: 'interrogate_image completed');
    expect(decision['toolCallIdHash'], result['toolCallIdHash']);
    expect(decision['phase'], 'decision');
    expect(result['phase'], 'result');
    expect(decision['summary'], 'interrogate_image generation/read');
    expect(
      project('result', summary: 'private conversation')['summary'],
      '[REDACTED AUDIT SUMMARY]',
    );
  });

  test(
    'separates policy, approval, path and resource errors without raw text',
    () {
      for (final entry in {
        'This tool is blocked by its permission domain policy.':
            'permission_policy',
        'The user declined this tool call.': 'approval_declined',
        'Image path is not permitted.': 'image_path',
        r'Lists and byte payloads are not allowed at $.references':
            'resource_reference',
        'private model response with Bearer secret': 'tool_error',
      }.entries) {
        final result = project('result', error: entry.key);
        expect(result['errorCategory'], entry.value);
        expect(result.containsKey('error'), isFalse);
      }
    },
  );
}
