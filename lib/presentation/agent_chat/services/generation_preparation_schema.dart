import '../../../core/constants/model_capabilities.dart';

Map<String, dynamic> generationPreparationProperties({
  required bool includeOperation,
}) => {
  if (includeOperation)
    'operation': {
      'type': 'string',
      'enum': ['generate', 'queue'],
    },
  'prompt': {'type': 'string'},
  'negative_prompt': {'type': 'string'},
  'width': {'type': 'integer'},
  'height': {'type': 'integer'},
  'count': {'type': 'integer'},
  'seed': {'type': 'integer'},
  'source_image': {'type': 'string'},
  'mask_image': {'type': 'string'},
  'source_ref': {'type': 'object'},
  'mask_ref': {'type': 'object'},
  'prompt_refs': {
    'type': 'array',
    'items': {'type': 'object'},
    'maxItems': 100,
  },
  'negative_prompt_refs': {
    'type': 'array',
    'items': {'type': 'object'},
    'maxItems': 100,
  },
  'vibe_refs': {
    'type': 'array',
    'items': {'type': 'object'},
    'maxItems': 16,
  },
  'precise_reference_refs': {
    'type': 'array',
    'items': {'type': 'object'},
    'maxItems': 16,
  },
  'character_layout_mode': {
    'type': 'string',
    'enum': ['ai_choice', 'custom'],
    'default': 'ai_choice',
    'description':
        'Layout for an explicitly provided characters snapshot. Omit or use '
        'ai_choice by default so NovelAI places every character; coordinates '
        'are forbidden in that mode. Use custom only when the user explicitly '
        'requests manual placement, and then provide every character position. '
        'Coordinates use x left-to-right and y top-to-bottom, both 0..1.',
  },
  'characters': {
    'type': 'array',
    'description':
        'Complete ordered character snapshot for this call. Omit to inherit '
        'the current character editor state. Characters without positions use '
        'NovelAI AI placement. Only when the user explicitly requests manual '
        'placement may you provide a complete x/y pair or legacy A1-E5 '
        'position for every character; never estimate coordinates proactively. '
        'Single-axis or incomplete custom layouts are rejected. Legacy grid '
        'values map to continuous cell centers.',
    'items': {
      'type': 'object',
      'additionalProperties': false,
      'properties': {
        'prompt': {
          'type': 'string',
          'minLength': 1,
          'description': 'Non-empty positive prompt for this character.',
        },
        'negative_prompt': {
          'type': 'string',
          'description': 'Independent undesired content for this character.',
        },
        'position': {
          'type': 'string',
          'pattern': r'^[A-Ea-e][1-5]$',
          'description': 'Legacy A1-E5 grid position; do not combine with x/y.',
        },
        'position_x': {
          'type': 'number',
          'minimum': 0,
          'maximum': 1,
          'description': 'Horizontal center: 0 is left, 1 is right.',
        },
        'position_y': {
          'type': 'number',
          'minimum': 0,
          'maximum': 1,
          'description': 'Vertical center: 0 is top, 1 is bottom.',
        },
      },
      'required': ['prompt'],
    },
    'maxItems': ModelCapabilityRegistry.maximumCharacterCount,
  },
  'strength': {'type': 'number'},
  'noise': {'type': 'number'},
  'inpaint_strength': {'type': 'number'},
  'auto_start': {'type': 'boolean'},
};
