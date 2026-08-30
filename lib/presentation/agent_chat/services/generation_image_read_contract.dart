import 'dart:io';

import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';
import '../../providers/image_generation_provider.dart';
import 'generation_image_resource.dart';
import 'generation_workspace_path_resolver.dart';

/// Defines the only model-visible bridge between an application-owned
/// generated image and the file-system `read` tool.
final class GenerationImageReadContract {
  const GenerationImageReadContract(this._pathResolver);

  final GenerationWorkspacePathResolver _pathResolver;

  AgentChatResourceReference resourceReference(String imageId) =>
      generationImageResourceReference(imageId);

  Future<GenerationImageReadDescriptor> describe(GeneratedImage image) async {
    final filePath = image.filePath;
    final saved = filePath != null && await File(filePath).exists();
    final readPath = saved
        ? await _pathResolver.readPathForExistingFile(filePath)
        : null;
    return GenerationImageReadDescriptor(
      image: image,
      resourceReference: resourceReference(image.id),
      saved: saved,
      readPath: readPath,
    );
  }
}

final class GenerationImageReadDescriptor {
  const GenerationImageReadDescriptor({
    required this.image,
    required this.resourceReference,
    required this.saved,
    required this.readPath,
  });

  final GeneratedImage image;
  final AgentChatResourceReference resourceReference;
  final bool saved;

  /// Exact workspace-relative argument accepted by the current `read` tool.
  /// Null means no file path may be exposed for this image.
  final String? readPath;

  Map<String, dynamic> toModelJson() => {
    'seed': image.metadata?.seed,
    'size': '${image.width}x${image.height}',
    'saved': saved,
    if (readPath case final path?) 'path': path,
    'resource_ref': AgentChatResourceReferenceCodec.encodeJsonMap(
      resourceReference,
    ),
  };
}
