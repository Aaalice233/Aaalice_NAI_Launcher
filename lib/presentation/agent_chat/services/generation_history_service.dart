import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/agent/agent_types.dart';
import '../../../core/agent/harness/tools/image.dart';
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';
import '../../../core/utils/display_thumbnail_utils.dart';
import '../../providers/image_generation_provider.dart';
import 'agent_resource_resolver.dart';
import 'defined_agent_tool.dart';
import 'generation_tool_results.dart';

class GenerationHistoryService {
  GenerationHistoryService(
    this._ref, {
    required AgentResourceResolver resourceResolver,
    required int maxRecentImageLimit,
  }) : _resourceResolver = resourceResolver,
       _maxRecentImageLimit = maxRecentImageLimit;
  final Ref _ref;
  final AgentResourceResolver _resourceResolver;
  final int _maxRecentImageLimit;
  Future<AgentToolResult> recentImages(Map<String, dynamic> args) async {
    final rawLimit = args['limit'];
    if (rawLimit == null) {
      return generationErrorResult('Parameter "limit" is required.');
    }
    if (rawLimit is! num || rawLimit != rawLimit.roundToDouble()) {
      return generationErrorResult('Parameter "limit" must be an integer.');
    }
    final limit = rawLimit.toInt();
    if (limit < 1 || limit > _maxRecentImageLimit) {
      return generationErrorResult(
        'Parameter "limit" must be between 1 and $_maxRecentImageLimit.',
      );
    }
    final history = _ref.read(imageGenerationNotifierProvider).history;
    final images = [
      for (final image in history)
        if (image.filePath != null) image,
    ].take(limit).toList(growable: false);
    final report = [
      for (final image in images)
        {
          'seed': image.metadata?.seed,
          'size': '${image.width}x${image.height}',
          'resource_ref': AgentChatResourceReferenceCodec.encodeJsonMap(
            generatedImageReference(image.id),
          ),
        },
    ];
    if (images.isEmpty) {
      return generationErrorResult(
        'No saved images yet. generate_image results and queue outputs '
        'appear here after they are saved.',
      );
    }
    return agentToolJsonResult({'ok': true, 'images': report});
  }

  Future<AgentToolResult> previewGeneratedImage(
    Map<String, dynamic> args,
  ) async {
    AgentChatResourceReference reference;
    try {
      reference = _resourceResolver.decode(args['resource_ref']);
    } on FormatException catch (error) {
      return agentToolError('invalid_resource_ref', '$error');
    }
    if (reference.kind != AgentChatResourceKind.generatedImage) {
      return agentToolError(
        'wrong_resource_kind',
        'resource_ref must identify a generated image.',
      );
    }
    final resolved = await _resourceResolver.resolve(reference);
    if (resolved?.bytes == null) {
      return agentToolError(
        'resource_unavailable',
        'Generated image is unavailable.',
      );
    }
    final thumbnail = await DisplayThumbnailUtils.normalize(resolved!.bytes!);
    final mime = thumbnail == null
        ? null
        : detectSupportedImageMimeType(thumbnail);
    if (thumbnail == null || mime == null) {
      return agentToolError(
        'preview_invalid',
        'Generated image preview is invalid.',
      );
    }
    final details = <String, dynamic>{
      'ok': true,
      'resource_ref': AgentChatResourceReferenceCodec.encodeJsonMap(reference),
    };
    return AgentToolResult(
      content: [
        ToolResultTextContent(jsonEncode(details)),
        ToolResultImageContent(
          ImageContent(
            source: ImageSource.base64(
              mimeType: mime,
              base64Data: base64Encode(thumbnail),
            ),
          ),
        ),
      ],
      details: details,
    );
  }

  AgentChatResourceReference generatedImageReference(String imageId) =>
      AgentChatResourceReference(
        kind: AgentChatResourceKind.generatedImage,
        source: 'generation_history',
        resourceId: imageId,
        display: {'title': imageId},
      );
}
