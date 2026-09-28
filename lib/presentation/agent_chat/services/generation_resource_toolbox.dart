import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agent/agent_types.dart';
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';
import '../../providers/generation/preview_selection_provider.dart';
import '../../providers/image_generation_provider.dart';
import '../../router/app_router_config.dart';
import '../../router/app_routes.dart';
import 'defined_agent_tool.dart';
import 'generation_image_resource.dart';

class GenerationResourceService {
  GenerationResourceService({
    required ImageGenerationState Function() readState,
    required void Function(String imageId) select,
    required void Function() navigateToGeneration,
    Future<void> Function(AgentChatResourceReference reference)? beforeMutation,
  }) : _readState = readState,
       _select = select,
       _navigateToGeneration = navigateToGeneration,
       _beforeMutation = beforeMutation ?? _noDelay;

  factory GenerationResourceService.fromRef(Ref ref) {
    return GenerationResourceService(
      readState: () => ref.read(imageGenerationNotifierProvider),
      select: (imageId) =>
          ref.read(generationPreviewSelectionProvider.notifier).select(imageId),
      navigateToGeneration: () =>
          ref.read(appRouterProvider).go(AppRoutes.generation),
      beforeMutation: (_) => ref
          .read(imageGenerationNotifierProvider.notifier)
          .ensureGenerationHistoryRestored(),
    );
  }

  final ImageGenerationState Function() _readState;
  final void Function(String imageId) _select;
  final void Function() _navigateToGeneration;
  final Future<void> Function(AgentChatResourceReference reference)
  _beforeMutation;

  static Future<void> _noDelay(AgentChatResourceReference _) async {}

  Future<AgentToolResult> selectGeneratedImage(
    Map<String, dynamic> args,
  ) async {
    final navigate = args['navigate'];
    if (navigate != null && navigate is! bool) {
      return agentToolError(
        'invalid_navigation',
        'navigate must be a boolean when provided.',
      );
    }

    final AgentChatResourceReference reference;
    try {
      reference = parseGenerationImageResource(args);
    } on GenerationImageResourceException catch (error) {
      return agentToolError(
        error.code,
        'select_generated_image: ${error.message}',
      );
    }
    try {
      await _beforeMutation(reference);
      // Resolve persisted history first, then re-read the authoritative owner.
      requireAvailableGenerationImage(_readState(), reference);
    } on GenerationImageResourceException catch (error) {
      return agentToolError(
        error.code,
        'select_generated_image: ${error.message}',
      );
    } on Object catch (error) {
      return agentToolError(
        'resource_resolution_failed',
        'select_generated_image: generated image ${reference.resourceId} '
            'failed during history resolution (${error.runtimeType}).',
      );
    }

    _select(reference.resourceId);
    if (navigate == null || navigate == true) {
      _navigateToGeneration();
    }

    return agentToolJsonResult({
      'ok': true,
      'selected': true,
      'navigated': navigate == null || navigate == true,
      'resource_ref': AgentChatResourceReferenceCodec.encodeJsonMap(reference),
    });
  }
}

/// Mutation toolbox for selecting a state-owned generated image preview.
class GenerationResourceToolbox {
  GenerationResourceToolbox(Ref ref)
    : service = GenerationResourceService.fromRef(ref);

  GenerationResourceToolbox.withService(this.service);

  final GenerationResourceService service;

  List<AgentTool> tools() => [
    DefinedAgentTool(
      name: 'select_generated_image',
      label: 'Select Generated Image',
      description:
          'Select a generated image by stable resource_ref (preferred) or '
          'stable image_id. List indexes and file paths are not accepted. '
          'Optionally navigate to the generation page.',
      parameters: const {
        'type': 'object',
        'properties': {
          'resource_ref': {'type': 'object'},
          'image_id': {'type': 'string'},
          'navigate': {
            'type': 'boolean',
            'description':
                'Navigate to generation after selecting; defaults to true.',
          },
        },
        'required': <String>[],
        'additionalProperties': false,
      },
      // Selection and navigation mutate application UI state and must not run
      // concurrently with sibling tool calls.
      executionModeOverride: ToolExecutionMode.sequential,
      executeFn: (_, args) => service.selectGeneratedImage(args),
    ),
  ];
}
