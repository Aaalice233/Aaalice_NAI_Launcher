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
    'description':
        'Layout for an explicitly provided characters snapshot. ai_choice '
        'lets NovelAI place every character and forbids coordinates. custom '
        'uses continuous centers where x is left-to-right and y is '
        'top-to-bottom, both 0..1. Omit to infer custom when any character '
        'has a position, otherwise ai_choice.',
  },
  'characters': {
    'type': 'array',
    'description':
        'Complete ordered character snapshot for this call. Omit to inherit '
        'the current character editor state. In custom mode, a complete x/y '
        'pair or legacy A1-E5 position is accepted; characters with neither '
        'receive stable non-overlapping defaults. Single-axis coordinates are '
        'rejected. Legacy grid values map to continuous cell centers.',
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
