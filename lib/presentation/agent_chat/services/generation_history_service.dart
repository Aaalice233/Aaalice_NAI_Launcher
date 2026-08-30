import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/agent/agent_types.dart';
import '../../../core/agent/harness/tools/image.dart';
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';
import '../../../core/utils/display_thumbnail_utils.dart';
import '../../providers/image_generation_provider.dart';
import 'agent_resource_resolver.dart';
import 'defined_agent_tool.dart';
import 'generation_image_resource.dart';
import 'generation_tool_results.dart';
import 'generation_workspace_path_resolver.dart';

class GenerationHistoryService {
  GenerationHistoryService(
    this._ref, {
    required AgentResourceResolver resourceResolver,
    required GenerationWorkspacePathResolver pathResolver,
    required int maxRecentImageLimit,
  }) : _resourceResolver = resourceResolver,
       _pathResolver = pathResolver,
       _maxRecentImageLimit = maxRecentImageLimit;
  final Ref _ref;
  final AgentResourceResolver _resourceResolver;
  final GenerationWorkspacePathResolver _pathResolver;
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
    await _ref
        .read(imageGenerationNotifierProvider.notifier)
        .ensureGenerationHistoryRestored();
    final history = _ref.read(imageGenerationNotifierProvider).history;
    final report = <Map<String, dynamic>>[];
    for (final image in history) {
      if (image.isFailedStreamSnapshot) continue;
      final filePath = image.filePath;
      if (filePath == null || !await File(filePath).exists()) continue;
      final readablePath = _pathResolver.readableRelativePath(filePath);
      if (readablePath == null) continue;
      report.add({
        'seed': image.metadata?.seed,
        'size': '${image.width}x${image.height}',
        'path': readablePath,
        'resource_ref': AgentChatResourceReferenceCodec.encodeJsonMap(
          generatedImageReference(image.id),
        ),
      });
      if (report.length == limit) break;
    }
    if (report.isEmpty) {
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
    await _ref
        .read(imageGenerationNotifierProvider.notifier)
        .ensureGenerationHistoryRestored();
    final AgentChatResourceReference reference;
    try {
      reference = parseGenerationImageResource(args);
      requireAvailableGenerationImage(
        _ref.read(imageGenerationNotifierProvider),
        reference,
      );
    } on GenerationImageResourceException catch (error) {
      return agentToolError(
        error.code,
        'preview_generated_image: ${error.message}',
      );
    }
    final ResolvedAgentResource? resolved;
    try {
      resolved = await _resourceResolver.resolve(reference);
    } on Object catch (error) {
      return agentToolError(
        'resource_resolution_failed',
        'preview_generated_image: generated image ${reference.resourceId} '
            'failed during resource resolution (${error.runtimeType}).',
      );
    }
    if (resolved?.bytes == null) {
      return agentToolError(
        'resource_unavailable',
        'preview_generated_image: generated image ${reference.resourceId} '
            'has no available bytes.',
      );
    }
    final thumbnail = await DisplayThumbnailUtils.normalize(resolved!.bytes!);
    final mime = thumbnail == null
        ? null
        : detectSupportedImageMimeType(thumbnail);
    if (thumbnail == null || mime == null) {
      return agentToolError(
        'preview_invalid',
        'preview_generated_image: generated image ${reference.resourceId} '
            'could not be normalized for preview.',
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
      generationImageResourceReference(imageId);
}
