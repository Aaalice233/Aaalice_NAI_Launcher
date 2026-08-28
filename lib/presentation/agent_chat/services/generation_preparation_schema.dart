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
  'characters': {
    'type': 'array',
    'items': {
      'type': 'object',
      'properties': {
        'prompt': {'type': 'string'},
        'negative_prompt': {'type': 'string'},
        'position': {'type': 'string'},
        'position_x': {'type': 'number', 'minimum': 0, 'maximum': 1},
        'position_y': {'type': 'number', 'minimum': 0, 'maximum': 1},
      },
      'required': ['prompt'],
    },
    'maxItems': 6,
  },
  'strength': {'type': 'number'},
  'noise': {'type': 'number'},
  'inpaint_strength': {'type': 'number'},
  'auto_start': {'type': 'boolean'},
};
