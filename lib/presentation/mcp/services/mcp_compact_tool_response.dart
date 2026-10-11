import 'dart:convert';

import '../../../core/agent/agent_types.dart';
import '../../agent_chat/services/defined_agent_tool.dart';

const mcpPreparationToolNames = {
  'prepare_generation',
  'update_generation_preparation',
  'generate_image',
  'queue_image_task',
};

/// Summaries never change stored transactions or the internal chat contract.
AgentToolResult compactMcpToolResponse(
  String toolName,
  AgentToolResult result, {
  bool includeParameters = false,
  bool includeDraftDetails = false,
}) {
  if (result.isError ||
      (!mcpPreparationToolNames.contains(toolName) &&
          toolName != 'get_application_context')) {
    return result;
  }
  final payload = _jsonPayload(result);
  if (payload == null) return result;
  if (toolName == 'get_application_context') {
    if (includeDraftDetails || payload['drafts'] is! List) return result;
    return agentToolJsonResult({
      ...payload,
      'drafts': [
        for (final draft in payload['drafts'] as List)
          if (draft is Map)
            {
              for (final key in [
                'draftId',
                'status',
                'estimatedAnlas',
                'updatedAt',
              ])
                if (draft.containsKey(key)) key: draft[key],
            },
      ],
    });
  }
  if (payload['status'] != 'prepared' || payload['preparation_id'] is! String) {
    return result;
  }
  final parameters = payload['parameters'];
  return agentToolJsonResult(
    {
      ...payload,
      if (parameters is Map && !includeParameters)
        'parameters': {
          for (final key in [
            'model',
            'width',
            'height',
            'steps',
            'sampler',
            'action',
            'character_layout_mode',
            'character_count',
            'has_source_image',
            'has_mask_image',
          ])
            if (parameters.containsKey(key)) key: parameters[key],
        },
      'next_action': {
        'tool': 'submit_generation',
        'arguments': {
          'preparation_id': payload['preparation_id'],
          if (payload['confirmation_required'] == true) 'confirmed': true,
        },
      },
    }..removeWhere(
      (key, _) => key == 'auto_start' && payload['operation'] != 'queue',
    ),
  );
}

Map<String, dynamic>? _jsonPayload(AgentToolResult result) {
  for (final block in result.content.whereType<ToolResultTextContent>()) {
    try {
      final value = jsonDecode(block.text);
      if (value is Map<String, dynamic>) return value;
    } on FormatException {
      continue;
    }
  }
  return null;
}
