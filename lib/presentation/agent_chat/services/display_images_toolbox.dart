import 'dart:convert';

import '../../../core/agent/agent_types.dart';
import '../../../core/agent/harness/tools/image.dart';
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';
import '../../../core/utils/display_thumbnail_utils.dart';
import 'agent_resource_resolver.dart';
import 'defined_agent_tool.dart';
import 'generation_image_resource.dart';

typedef DisplayImageResourceResolver =
    Future<ResolvedAgentResource?> Function(
      AgentChatResourceReference reference,
    );
typedef DisplayImageResourceValidator =
    Future<void> Function(AgentChatResourceReference reference);

/// Resolves stable application-owned image references into bounded previews.
class DisplayImagesService {
  DisplayImagesService({
    required DisplayImageResourceResolver resolve,
    DisplayImageResourceValidator? validate,
  }) : _resolve = resolve,
       _validate = validate;

  factory DisplayImagesService.fromResolver(AgentResourceResolver resolver) =>
      DisplayImagesService(
        resolve: resolver.resolve,
        validate: resolver.validateForDisplay,
      );

  final DisplayImageResourceResolver _resolve;
  final DisplayImageResourceValidator? _validate;

  Future<AgentToolResult> display(Map<String, dynamic> args) async {
    final values = args['resource_refs'];
    if (values is! List || values.isEmpty || values.length > 12) {
      return agentToolError(
        'invalid_resource_refs',
        'resource_refs must contain between 1 and 12 stable references.',
      );
    }

    final references = <AgentChatResourceReference>[];
    for (var index = 0; index < values.length; index++) {
      final value = values[index];
      if (value is! Map) {
        return agentToolError(
          'invalid_resource_ref',
          'resource_refs[$index] must be a stable resource reference object.',
        );
      }
      try {
        references.add(
          AgentChatResourceReferenceCodec.decodeJsonMap(
            Map<String, dynamic>.from(value),
          ),
        );
      } on FormatException catch (error) {
        return agentToolError(
          'invalid_resource_ref',
          'resource_refs[$index] is invalid: ${error.message}',
        );
      }
    }

    final previews =
        <
          ({
            AgentChatResourceReference reference,
            String label,
            String mime,
            String data,
          })
        >[];
    for (var index = 0; index < references.length; index++) {
      final ResolvedAgentResource? resolved;
      try {
        await _validate?.call(references[index]);
        resolved = await _resolve(references[index]);
      } on GenerationImageResourceException catch (error) {
        return agentToolError(error.code, error.message);
      } on Exception {
        return agentToolError(
          'resource_resolution_failed',
          'resource_refs[$index] could not be resolved.',
        );
      }
      if (resolved == null) {
        return agentToolError(
          'resource_unavailable',
          'resource_refs[$index] is unavailable.',
        );
      }
      final bytes = resolved.bytes;
      if (bytes == null) {
        return agentToolError(
          'resource_not_image',
          'resource_refs[$index] does not identify an image.',
        );
      }
      final thumbnail = await DisplayThumbnailUtils.normalize(bytes);
      final mime = thumbnail == null
          ? null
          : detectSupportedImageMimeType(thumbnail);
      if (thumbnail == null || mime == null) {
        return agentToolError(
          'resource_not_image',
          'resource_refs[$index] could not be decoded as a supported image.',
        );
      }
      previews.add((
        reference: resolved.reference,
        label: resolved.label,
        mime: mime,
        data: base64Encode(thumbnail),
      ));
    }

    final details = <String, dynamic>{
      'ok': true,
      'count': previews.length,
      'images': [
        for (final preview in previews)
          {
            'label': preview.label,
            'resource_ref': AgentChatResourceReferenceCodec.encodeJsonMap(
              preview.reference,
            ),
          },
      ],
    };
    return AgentToolResult(
      content: [
        ToolResultTextContent(jsonEncode(details)),
        for (final preview in previews)
          ToolResultImageContent(
            ImageContent(
              source: ImageSource.base64(
                mimeType: preview.mime,
                base64Data: preview.data,
              ),
            ),
          ),
      ],
      details: details,
    );
  }
}

/// Read-only display contract; it cannot resolve paths or arbitrary URLs.
class DisplayImagesToolbox {
  DisplayImagesToolbox(AgentResourceResolver resolver)
    : service = DisplayImagesService.fromResolver(resolver);

  DisplayImagesToolbox.withService(this.service);

  final DisplayImagesService service;

  List<AgentTool> tools() => [
    DefinedAgentTool(
      name: 'display_images',
      label: 'Display Images',
      description:
          'The only explicit multi-image display tool. Display 1-12 images from '
          'stable resource_ref objects returned by application image tools. Use '
          'when the user asks to see retrieved images; preserve the selected '
          'references and order. onlineGalleryMedia references render as '
          'interactive gallery cards. Paths and arbitrary URLs are not accepted.',
      parameters: const {
        'type': 'object',
        'properties': {
          'resource_refs': {
            'type': 'array',
            'minItems': 1,
            'maxItems': 12,
            'items': {'type': 'object'},
          },
        },
        'required': ['resource_refs'],
      },
      executeFn: (_, args) => service.display(args),
    ),
  ];
}
