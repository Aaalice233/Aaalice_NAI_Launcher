import 'dart:convert';

import '../../../core/agent/agent_types.dart';
import '../../../core/agent/harness/tools/image.dart';
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';
import '../../../core/utils/display_thumbnail_utils.dart';
import 'agent_resource_resolver.dart';
import 'defined_agent_tool.dart';
import 'generation_image_resource.dart';

typedef AgentImageResourceResolver =
    Future<ResolvedAgentResource?> Function(
      AgentChatResourceReference reference,
    );
typedef AgentImageResourceValidator =
    Future<void> Function(AgentChatResourceReference reference);

enum AgentImagePresentation { modelOnly, conversation }

/// Resolves application-owned image references for either private inspection
/// by the model or explicit presentation in the conversation.
class AgentImagePresentationService {
  AgentImagePresentationService({
    required AgentImageResourceResolver resolve,
    AgentImageResourceValidator? validate,
  }) : _resolve = resolve,
       _validate = validate;

  factory AgentImagePresentationService.fromResolver(
    AgentResourceResolver resolver,
  ) => AgentImagePresentationService(
    resolve: resolver.resolve,
    validate: resolver.validateImageResource,
  );

  final AgentImageResourceResolver _resolve;
  final AgentImageResourceValidator? _validate;

  Future<AgentToolResult> present(
    Map<String, dynamic> args, {
    required AgentImagePresentation presentation,
  }) async {
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

    final userVisible = presentation == AgentImagePresentation.conversation;
    final details = <String, dynamic>{
      'ok': true,
      'media_presentation': userVisible ? 'conversation' : 'model_only',
      'user_visible': userVisible,
      'count': previews.length,
      if (userVisible) 'displayed_count': previews.length,
      if (!userVisible) 'inspected_count': previews.length,
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

class ImagePresentationToolbox {
  ImagePresentationToolbox(AgentResourceResolver resolver)
    : service = AgentImagePresentationService.fromResolver(resolver);

  ImagePresentationToolbox.withService(this.service);

  final AgentImagePresentationService service;

  List<AgentTool> tools() => [
    DefinedAgentTool(
      name: 'inspect_images',
      label: 'Inspect Images',
      description:
          'Privately inspect 1-12 images from stable resource_ref objects. '
          'The model receives the images, but they are NOT shown to the user. '
          'The result reports user_visible=false. Use display_images instead '
          'whenever the user should see the images.',
      parameters: _parameters,
      executeFn: (_, args) =>
          service.present(args, presentation: AgentImagePresentation.modelOnly),
    ),
    DefinedAgentTool(
      name: 'display_images',
      label: 'Display Images',
      description:
          'Show 1-12 images in the conversation from stable resource_ref '
          'objects returned by application image tools. Use this whenever the '
          'user asks to see retrieved images. The result reports '
          'user_visible=true only after the images are available to the user. '
          'Paths and arbitrary URLs are not accepted.',
      parameters: _parameters,
      executeFn: (_, args) => service.present(
        args,
        presentation: AgentImagePresentation.conversation,
      ),
    ),
  ];
}

const Map<String, dynamic> _parameters = {
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
  'additionalProperties': false,
};
