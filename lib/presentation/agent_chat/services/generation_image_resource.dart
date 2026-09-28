import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';
import '../../providers/image_generation_provider.dart';

const String generationImageResourceSource = 'generation_history';

AgentChatResourceReference generationImageResourceReference(String imageId) {
  return AgentChatResourceReference(
    kind: AgentChatResourceKind.generatedImage,
    source: generationImageResourceSource,
    resourceId: imageId,
    display: {'title': imageId},
  );
}

final class GenerationImageResourceException implements Exception {
  const GenerationImageResourceException(this.code, this.message);

  final String code;
  final String message;
}

/// Parses only stable generation identities. A resource reference takes
/// precedence over the compatibility image_id when both are supplied.
AgentChatResourceReference parseGenerationImageResource(
  Map<String, dynamic> args,
) {
  if (args.containsKey('resource_ref')) {
    final value = args['resource_ref'];
    if (value is! Map) {
      throw const GenerationImageResourceException(
        'invalid_resource_ref',
        'resource_ref must be a stable resource reference object.',
      );
    }

    final AgentChatResourceReference reference;
    try {
      reference = AgentChatResourceReferenceCodec.decodeJsonMap(
        Map<String, dynamic>.from(value),
      );
    } on FormatException catch (error) {
      throw GenerationImageResourceException(
        'invalid_resource_ref',
        'resource_ref is invalid: ${error.message}',
      );
    }
    if (reference.kind != AgentChatResourceKind.generatedImage) {
      throw const GenerationImageResourceException(
        'wrong_resource_kind',
        'resource_ref must identify a generated image.',
      );
    }
    final imageId = reference.resourceId.trim();
    if (imageId.isEmpty) {
      throw const GenerationImageResourceException(
        'invalid_resource_ref',
        'resource_ref must contain a non-empty generated image ID.',
      );
    }
    return generationImageResourceReference(imageId);
  }

  final imageId = args['image_id'];
  if (imageId is! String || imageId.trim().isEmpty) {
    throw const GenerationImageResourceException(
      'missing_image_resource',
      'Provide resource_ref or a stable image_id.',
    );
  }
  return generationImageResourceReference(imageId.trim());
}

GeneratedImage requireAvailableGenerationImage(
  ImageGenerationState state,
  AgentChatResourceReference reference,
) {
  final image = state.findImageById(reference.resourceId);
  if (image == null) {
    throw GenerationImageResourceException(
      'stale_image_resource',
      'Generated image ${reference.resourceId} no longer exists in '
          'currentImages, history, or displayImages.',
    );
  }
  if (image.isFailedStreamSnapshot) {
    throw GenerationImageResourceException(
      'failed_stream_snapshot',
      'Generated image ${reference.resourceId} is a failed stream snapshot '
          'and cannot be used.',
    );
  }
  return image;
}
