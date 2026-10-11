import '../../../core/constants/model_capabilities.dart';
import 'generation_enhance_resolver.dart';

Map<String, dynamic> generationPreparationProperties({
  required bool includeOperation,
}) => {
  if (includeOperation)
    'operation': {
      'type': 'string',
      'enum': ['generate', 'queue'],
    },
  'prompt': {
    'type': 'string',
    'description':
        'Positive prompt for this request only, English danbooru-style tags; '
        'does not change the launcher page.',
  },
  'negative_prompt': {
    'type': 'string',
    'description':
        'Undesired content for this request only; omit to inherit the page '
        'value.',
  },
  'width': {
    'type': 'integer',
    'description':
        'Multiple of 64; omit to inherit the page value, or the source image '
        'import resolution when a source is given.',
  },
  'height': {
    'type': 'integer',
    'description':
        'Multiple of 64; omit to inherit the page value, or the source image '
        'import resolution when a source is given.',
  },
  'count': {
    'type': 'integer',
    'description': 'Variations of this prompt; omit for 1.',
  },
  'seed': {
    'type': 'integer',
    'description':
        '-1 or omitted for random; a fixed seed only applies to count 1.',
  },
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
  'enhance': generationEnhanceProperty,
  'inpaint_strength': {'type': 'number'},
  'auto_start': {'type': 'boolean'},
  'save_path': {
    'type': 'string',
    'description':
        'Optional .png file target for every finished image, '
        'workspace-relative or a permitted absolute path. When count x '
        'batch_size exceeds 1 the file name must contain {index}, {seed} or '
        '{id}. Only for operation generate. Without it saved_path points at '
        'the launcher gallery original; an empty string on update restores '
        'that default.',
  },
};

/// 增强沿用同一次生成事务，只额外决定尺寸、强度与增强专属请求标记。
const Map<String, dynamic> generationEnhanceProperty = {
  'type': 'object',
  'additionalProperties': false,
  'description':
      'NovelAI Enhance of source_ref/source_image: re-renders the image with '
      'your prompt at the chosen scale. Requires a source without a mask; '
      'width and height derive from the source import resolution and scale, '
      'so omit them. strength/noise follow the level unless given '
      'explicitly. Omitted level/scale inherit the generation page Enhance '
      'panel; an inherited scale that does not fit falls back like the page.',
  'properties': {
    'level': {
      'type': 'integer',
      'minimum': 1,
      'maximum': 5,
      'description':
          'Magnitude: strength 0.2/0.4/0.5/0.6/0.7, level 5 adds noise 0.1.',
    },
    'scale': {
      'type': 'string',
      'enum': GenerationEnhanceResolver.scaleWireNames,
      'description':
          'Output scale. max (models that support it, source under about '
          '2.5 megapixels) sends the source size and lets the server upscale '
          'to 3.14 megapixels, billed at that area. An unavailable explicit '
          'scale is rejected with the available list.',
    },
  },
};
