import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/agent/agent_media_display_policy.dart';
import '../../../core/agent/agent_types.dart';
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../services/agent_resource_resolver.dart';
import 'agent_chat_resource_widgets.dart';
import 'agent_chat_tool_image_card.dart';
import 'agent_chat_tool_resource_preview.dart';
import 'agent_chat_tool_result_file_image.dart';
import 'agent_chat_tool_result_media_extractors.dart';

class ToolResultMediaPayload {
  const ToolResultMediaPayload({
    required this.files,
    required this.inlineImages,
    required this.unpairedInlineImages,
    required this.remoteImages,
    required this.resourceReferences,
  });

  final List<String> files;
  final List<Uint8List> inlineImages;
  final List<Uint8List> unpairedInlineImages;
  final List<String> remoteImages;
  final List<AgentChatResourceReference> resourceReferences;

  bool get isEmpty =>
      files.isEmpty &&
      unpairedInlineImages.isEmpty &&
      remoteImages.isEmpty &&
      resourceReferences.isEmpty;

  bool get isNotEmpty => !isEmpty;

  List<Widget> buildGalleryChildren({
    required String refKeyPrefix,
    required String inlineKeyPrefix,
    Future<ResolvedAgentResource?> Function(
      AgentChatResourceReference reference,
    )?
    resolveResource,
  }) => [
    for (final path in files)
      AgentChatToolResultFileImage(key: ValueKey(path), path: path),
    ...buildToolResultResourcePreviewWidgets(
      references: resourceReferences,
      inlineImages: inlineImages,
      keyPrefix: refKeyPrefix,
      resolveResource: resolveResource,
    ),
    for (var index = 0; index < unpairedInlineImages.length; index++)
      ToolResultInlineImage(
        key: ValueKey('$inlineKeyPrefix-$index'),
        bytes: unpairedInlineImages[index],
      ),
    for (final url in remoteImages)
      ToolResultNetworkImage(key: ValueKey(url), url: url),
  ];
}

ToolResultMediaPayload extractToolResultMediaPayload(ToolResultMessage result) {
  final files = extractToolResultImageFiles(result);
  final preferFileImages = files.isNotEmpty;
  final inlineImages = preferFileImages
      ? const <Uint8List>[]
      : extractToolResultInlineImages(result);
  final remoteImages = preferFileImages
      ? const <String>[]
      : extractToolResultRemoteImages(
          result,
        ).where((url) => !files.contains(url)).toList(growable: false);
  final resourceReferences = files.isEmpty
      ? extractToolResultResourceReferences(result)
      : const <AgentChatResourceReference>[];
  final unpairedInlineImages = resourceReferences.isEmpty
      ? inlineImages
      : inlineImages.skip(resourceReferences.length).toList(growable: false);
  return ToolResultMediaPayload(
    files: files,
    inlineImages: inlineImages,
    unpairedInlineImages: unpairedInlineImages,
    remoteImages: remoteImages,
    resourceReferences: resourceReferences,
  );
}

class AgentChatToolResultMedia extends StatelessWidget {
  const AgentChatToolResultMedia({
    super.key,
    required this.result,
    this.resolveResource,
  });

  final ToolResultMessage result;
  final Future<ResolvedAgentResource?> Function(
    AgentChatResourceReference reference,
  )?
  resolveResource;

  @override
  Widget build(BuildContext context) {
    if (!agentToolDisplaysMedia(result.toolName)) {
      return const SizedBox.shrink();
    }
    final media = extractToolResultMediaPayload(result);
    if (media.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      key: ValueKey('agent-tool-media-${result.toolCallId}'),
      padding: const EdgeInsets.only(bottom: 12),
      child: AgentChatResourceGallery(
        children: media.buildGalleryChildren(
          refKeyPrefix: '${result.toolCallId}-media-ref',
          inlineKeyPrefix: '${result.toolCallId}-media-inline',
          resolveResource: resolveResource,
        ),
      ),
    );
  }
}
