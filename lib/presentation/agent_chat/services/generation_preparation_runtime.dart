import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../../data/models/image/image_params.dart';

enum GenerationPreparationKind { generate, queue }

enum GenerationPreparationStatus { prepared, submitted, cancelled }

class GenerationPreparation {
  GenerationPreparation({
    required this.kind,
    required this.baseParams,
    required this.params,
    required this.batchSize,
    required this.count,
    required this.autoStart,
    required this.estimatedAnlas,
    required this.arguments,
    this.sourceImage,
    this.maskImage,
  }) : id = const Uuid().v4(),
       createdAt = DateTime.now();

  final String id;
  final DateTime createdAt;
  final GenerationPreparationKind kind;
  final ImageParams baseParams;
  final ImageParams params;
  final int batchSize;
  final int count;
  final bool autoStart;
  final int estimatedAnlas;
  final Map<String, dynamic> arguments;
  final Uint8List? sourceImage;
  final Uint8List? maskImage;
  GenerationPreparationStatus status = GenerationPreparationStatus.prepared;

  Map<String, dynamic> toJson() => {
    'ok': true,
    'preparation_id': id,
    'status': status.name,
    'operation': kind.name,
    'estimated_anlas': estimatedAnlas,
    'count': count,
    'batch_size': batchSize,
    'auto_start': autoStart,
    'parameters': {
      'prompt': params.prompt,
      'negative_prompt': params.negativePrompt,
      'model': params.model,
      'width': params.width,
      'height': params.height,
      'steps': params.steps,
      'sampler': params.sampler,
      'scale': params.scale,
      'seed': params.seed,
      'action': params.action.value,
      'character_layout_mode': params.useCoords ? 'custom' : 'ai_choice',
      'character_count': params.characters.length,
      'characters': [
        for (var index = 0; index < params.characters.length; index++)
          {
            'order': index,
            'prompt': params.characters[index].prompt,
            'negative_prompt': params.characters[index].negativePrompt,
            if (params.useCoords)
              'center': {
                'x': params.characters[index].positionX,
                'y': params.characters[index].positionY,
              },
          },
      ],
      if (sourceImage != null) 'has_source_image': true,
      if (maskImage != null) 'has_mask_image': true,
    },
    'confirmation_required': status == GenerationPreparationStatus.prepared,
  };
}

/// In-memory transaction store owned by the Agent runtime, not by a tool list.
/// Rebuilding tools therefore cannot discard an outstanding confirmation.
class GenerationPreparationRuntime {
  final Map<String, GenerationPreparation> _preparations = {};

  GenerationPreparation add(GenerationPreparation preparation) {
    _preparations[preparation.id] = preparation;
    return preparation;
  }

  GenerationPreparation? get(String id) => _preparations[id];

  bool cancel(String id) {
    final preparation = _preparations[id];
    if (preparation == null ||
        preparation.status != GenerationPreparationStatus.prepared) {
      return false;
    }
    preparation.status = GenerationPreparationStatus.cancelled;
    return true;
  }
}
