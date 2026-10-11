import 'dart:convert';
import 'dart:io';

import '../../../core/agent/agent_types.dart';
import '../../../core/agent/harness/tools/image.dart';
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';
import '../../../core/utils/display_thumbnail_utils.dart';
import '../../providers/image_generation_provider.dart';
import 'generation_image_resource.dart';
import 'generation_preparation_runtime.dart';
import 'generation_workspace_path_resolver.dart';

/// Defines the only model-visible bridge between an application-owned
/// generated image and the file-system `read` tool.
final class GenerationImageReadContract {
  const GenerationImageReadContract(this._pathResolver);

  final GenerationWorkspacePathResolver _pathResolver;

  AgentChatResourceReference resourceReference(String imageId) =>
      generationImageResourceReference(imageId);

  Future<GenerationImageReadDescriptor> describe(
    GeneratedImage image, {
    GeneratedImageExportOutcome? export,
  }) async {
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
      export: export,
    );
  }

  /// Result shape shared by generation and upscale: MCP image responses find
  /// new images by `images[].resource_ref`; thumbnails let the chat show them.
  Future<AgentToolResult> buildResult(
    List<GeneratedImage> images, {
    Map<String, GeneratedImageExportOutcome> exports = const {},
    Map<String, dynamic> extra = const {},
  }) async {
    final report = <Map<String, dynamic>>[];
    final savedFiles = <String>[];
    for (final image in images) {
      final descriptor = await describe(image, export: exports[image.id]);
      if (descriptor.saved) {
        if (image.filePath case final path?) savedFiles.add(path);
      }
      report.add(descriptor.toModelJson());
    }
    final content = <ToolResultContent>[
      ToolResultTextContent(
        jsonEncode({'ok': true, ...extra, 'images': report}),
      ),
    ];
    for (final image in images) {
      final thumbnail = await DisplayThumbnailUtils.normalize(image.bytes);
      final mime = thumbnail == null
          ? null
          : detectSupportedImageMimeType(thumbnail);
      if (thumbnail != null && mime != null) {
        content.add(
          ToolResultImageContent(
            ImageContent(
              source: ImageSource.base64(
                mimeType: mime,
                base64Data: base64Encode(thumbnail),
              ),
            ),
          ),
        );
      }
    }
    return AgentToolResult(
      content: content,
      details: <String, dynamic>{
        ...extra,
        'images': report,
        if (savedFiles.isNotEmpty) ...{
          'files': savedFiles,
          'preferFileImages': true,
        },
      },
    );
  }
}

/// Result of placing one finished image at the target chosen at preparation
/// time: a written file, or the gallery original it already lives in.
final class GeneratedImageExportOutcome {
  const GeneratedImageExportOutcome.saved(
    String this.savedPath, {
    required GenerationSavePathSource source,
  }) : savedPathSource = source,
       errorCode = null,
       errorMessage = null;

  const GeneratedImageExportOutcome.failed({
    required String this.errorCode,
    required String this.errorMessage,
  }) : savedPath = null,
       savedPathSource = null;

  final String? savedPath;
  final GenerationSavePathSource? savedPathSource;
  final String? errorCode;
  final String? errorMessage;

  Map<String, dynamic> toModelJson() => savedPath != null
      ? {
          'saved_path': savedPath,
          'saved_path_source': savedPathSource!.wireName,
        }
      : {
          'save_error': {'code': errorCode, 'message': errorMessage},
        };
}

final class GenerationImageReadDescriptor {
  const GenerationImageReadDescriptor({
    required this.image,
    required this.resourceReference,
    required this.saved,
    required this.readPath,
    this.export,
  });

  final GeneratedImage image;
  final AgentChatResourceReference resourceReference;
  final bool saved;

  /// Exact workspace-relative argument accepted by the current `read` tool.
  /// Null means no file path may be exposed for this image.
  final String? readPath;

  final GeneratedImageExportOutcome? export;

  Map<String, dynamic> toModelJson() => {
    'seed': image.metadata?.seed,
    'size': '${image.width}x${image.height}',
    'saved': saved,
    if (readPath case final path?) 'path': path,
    'resource_ref': AgentChatResourceReferenceCodec.encodeJsonMap(
      resourceReference,
    ),
    ...?export?.toModelJson(),
  };
}
