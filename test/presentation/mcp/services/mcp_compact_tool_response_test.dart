import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/agent_chat/services/defined_agent_tool.dart';
import 'package:nai_launcher/presentation/mcp/services/mcp_compact_tool_response.dart';

void main() {
  final parameters = {
    'prompt': 'positive,' * 1000,
    'negative_prompt': 'negative,' * 500,
    'characters': [
      for (var i = 0; i < 8; i++) {'prompt': 'character,' * 300},
    ],
    'model': 'nai-diffusion-5-full',
    'width': 832,
    'height': 1216,
    'steps': 28,
    'character_count': 8,
    'character_layout_mode': 'ai_choice',
  };
  Map<String, dynamic> preparation({
    int cost = 0,
    String operation = 'generate',
  }) => {
    'ok': true,
    'preparation_id': 'prepared-1',
    'status': 'prepared',
    'operation': operation,
    'estimated_anlas': cost,
    'confirmation_required': cost != 0,
    'auto_start': true,
    'count': 1,
    'batch_size': 1,
    'parameters': parameters,
  };

  for (final tool in mcpPreparationToolNames) {
    test('$tool returns a bounded summary and a direct free submission', () {
      final original = agentToolJsonResult(preparation());
      final compact = compactMcpToolResponse(tool, original);
      final data = compact.details;
      expect(jsonEncode(data).length, lessThan(700));
      expect(data['parameters']['prompt'], isNull);
      expect(data['parameters']['characters'], isNull);
      expect(data['parameters']['character_count'], 8);
      expect(data.containsKey('auto_start'), isFalse);
      expect(data['next_action'], {
        'tool': 'submit_generation',
        'arguments': {'preparation_id': 'prepared-1'},
      });
      expect(original.details['parameters'], parameters);
      expect(jsonEncode(original.details).length, greaterThan(30000));
    });
  }

  test(
    'paid summary preserves cost and confirmation, queue retains auto_start',
    () {
      final compact = compactMcpToolResponse(
        'prepare_generation',
        agentToolJsonResult(preparation(cost: 24, operation: 'queue')),
      );
      expect(compact.details['estimated_anlas'], 24);
      expect(compact.details['confirmation_required'], isTrue);
      expect(compact.details['auto_start'], isTrue);
      expect(compact.details['next_action']['arguments'], {
        'preparation_id': 'prepared-1',
        'confirmed': true,
      });
    },
  );

  test('full snapshots are opt-in and explicit inspection stays complete', () {
    final original = agentToolJsonResult(preparation());
    final full = compactMcpToolResponse(
      'generate_image',
      original,
      includeParameters: true,
    );
    expect(full.details['parameters'], parameters);
    expect(
      compactMcpToolResponse('inspect_generation_preparation', original),
      same(original),
    );
  });

  test('generation results and errors are never replaced by a preparation', () {
    final generated = agentToolJsonResult({
      'ok': true,
      'images': [
        {'resource_ref': {}},
      ],
    });
    expect(
      compactMcpToolResponse('generate_image', generated),
      same(generated),
    );
    final error = agentToolError('failure', 'No generation');
    expect(compactMcpToolResponse('prepare_generation', error), same(error));
  });

  test('application context omits unrelated full drafts unless requested', () {
    final original = agentToolJsonResult({
      'ok': true,
      'route': {'path': '/generation'},
      'queue': {'pending_count': 3},
      'drafts': [
        {
          'draftId': 'draft-1',
          'status': 'ready',
          'estimatedAnlas': 12,
          'prompt': parameters['prompt'],
          'params': parameters,
          'updatedAt': '2026-09-15T00:00:00Z',
        },
      ],
    });
    final compact = compactMcpToolResponse('get_application_context', original);
    expect(jsonEncode(compact.details).length, lessThan(300));
    expect(compact.details['route'], original.details['route']);
    expect(compact.details['queue'], original.details['queue']);
    expect((compact.details['drafts'] as List).single, {
      'draftId': 'draft-1',
      'status': 'ready',
      'estimatedAnlas': 12,
      'updatedAt': '2026-09-15T00:00:00Z',
    });
    expect(
      compactMcpToolResponse(
        'get_application_context',
        original,
        includeDraftDetails: true,
      ),
      same(original),
    );
  });
}
