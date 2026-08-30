import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/permissions/permissions.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference.dart';
import 'package:nai_launcher/core/agent/harness/env/dart_io_execution_env.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_resource_resolver.dart';
import 'package:nai_launcher/presentation/agent_chat/services/application_toolbox.dart';
import 'package:nai_launcher/presentation/agent_chat/services/gallery_toolbox.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_image_favorite_toolbox.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_image_workflow_service.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_image_workflow_toolbox.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_resource_toolbox.dart';
import 'package:nai_launcher/presentation/agent_chat/services/image_resource_action_service.dart';
import 'package:nai_launcher/presentation/agent_chat/services/image_resource_action_toolbox.dart';
import 'package:nai_launcher/presentation/agent_chat/services/queue_toolbox.dart';
import 'package:nai_launcher/presentation/agent_chat/services/reference_library_toolbox.dart';
import 'package:nai_launcher/presentation/agent_chat/services/tag_toolbox.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';

final _refProvider = Provider<Ref>((ref) => ref);

void main() {
  test('business toolbox exposes complete unique strict tool contracts', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final ref = container.read(_refProvider);
    final tools = <AgentTool>[
      ...ApplicationToolbox(ref).tools(),
      ...GalleryToolbox(ref).tools(),
      ...ReferenceLibraryToolbox(ref, AgentResourceResolver(ref)).tools(),
      ...QueueToolbox(ref, QueueControlRuntime()).tools(),
      ...TagToolbox(ref).tools(),
      ...GenerationResourceToolbox.withService(
        GenerationResourceService(
          readState: () => const ImageGenerationState(),
          select: (_) {},
          navigateToGeneration: () {},
        ),
      ).tools(),
      ...GenerationImageWorkflowToolbox(
        GenerationImageWorkflowService(
          loadResource: (_) async => GenerationWorkflowResourceSnapshot(
            status: GenerationWorkflowResourceStatus.ready,
            bytes: Uint8List(0),
          ),
          launcher: _WorkflowLauncher(),
        ),
      ).tools(),
      ...GenerationImageFavoriteToolbox.forTesting(
        resolveImage: (_) => null,
        readFavorite: (_) async => null,
        writeFavorite: (_, __) async => false,
      ).tools(),
      ...ImageResourceActionToolbox(
        ImageResourceActionService(
          resolve: (_) async => null,
          env: DartIoExecutionEnv(),
          clipboardWriter: (_) async {},
        ),
      ).tools(),
    ];
    final names = tools.map((tool) => tool.name).toList();

    expect(names.toSet(), hasLength(names.length));
    expect(
      names,
      containsAll(const [
        'get_application_context',
        'navigate_application',
        'list_fixed_tags',
        'create_fixed_tag',
        'list_tag_library_entries',
        'create_tag_library_entry',
        'search_local_gallery',
        'preview_local_gallery_image',
        'search_online_gallery',
        'preview_online_gallery_media',
        'list_vibe_library',
        'create_vibe_library_entry',
        'apply_vibe_library_entry',
        'list_precise_reference_library',
        'create_precise_reference_entry',
        'apply_precise_reference_entry',
        'get_active_generation_references',
        'inspect_generation_queue',
        'prepare_generation_queue_execution',
        'start_generation_queue',
        'pause_generation_queue',
        'resume_generation_queue',
        'stop_generation_queue',
        'search_tags',
        'select_generated_image',
        'open_generation_image_workflow',
        'set_generated_image_favorite',
        'save_generated_image',
        'copy_generated_image_to_clipboard',
        'send_generated_image_to_krita',
      ]),
    );
    for (final tool in tools) {
      expect(tool.parameters['type'], 'object', reason: tool.name);
      expect(
        tool.parameters['additionalProperties'],
        isFalse,
        reason: tool.name,
      );
      expect(
        () => describeAgentToolPermission(tool.name),
        returnsNormally,
        reason: tool.name,
      );
    }
  });
}

final class _WorkflowLauncher
    implements GenerationImageWorkflowLauncherAdapter {
  @override
  Future<Map<String, dynamic>> open(
    GenerationImageWorkflowMode mode,
    AgentChatResourceReference reference,
    Uint8List imageBytes, {
    required bool Function() isCurrent,
  }) async => const {};
}
