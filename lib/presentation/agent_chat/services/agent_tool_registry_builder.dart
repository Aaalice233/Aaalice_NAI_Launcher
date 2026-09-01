import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agent/agent.dart';
import '../../../core/agent/harness/env/dart_io_execution_env.dart';
import '../../../core/agent/harness/harness_types.dart';
import '../../../core/agent/harness/skills.dart';
import '../../../core/agent/permissions/permissions.dart';
import '../../agent_settings/providers/agent_settings_provider.dart';
import '../../prompt_assistant/models/prompt_assistant_models.dart';
import '../../prompt_assistant/providers/web_access_provider.dart';
import '../../providers/generation/image_workflow_controller.dart';
import '../../providers/krita/krita_bridge_notifier.dart';
import '../../router/app_router_config.dart';
import '../../router/app_routes.dart';
import 'agent_image_observation_ledger.dart';
import 'agent_resource_resolver.dart';
import 'application_toolbox.dart';
import 'display_images_toolbox.dart';
import 'execution_toolbox.dart';
import 'gallery_toolbox.dart';
import 'generation_image_favorite_toolbox.dart';
import 'generation_image_workflow_launcher_adapter.dart';
import 'generation_image_workflow_service.dart';
import 'generation_image_workflow_toolbox.dart';
import 'generation_preparation_runtime.dart';
import 'generation_resource_toolbox.dart';
import 'generation_toolbox.dart';
import 'image_resource_action_service.dart';
import 'image_resource_action_toolbox.dart';
import 'manual_inpaint_toolbox.dart';
import 'prompt_toolbox.dart';
import 'queue_toolbox.dart';
import 'reference_library_toolbox.dart';
import 'tag_toolbox.dart';
import 'web_access_toolbox.dart';

class AgentToolRegistry {
  const AgentToolRegistry({
    required this.tools,
    required this.catalog,
    required this.policy,
  });

  final List<AgentTool> tools;
  final AgentToolPermissionCatalog catalog;
  final AgentPermissionPolicy policy;
}

/// Builds the single tool registry used by the active chat runtime.
class AgentToolRegistryBuilder {
  AgentToolRegistryBuilder({
    required Ref ref,
    required String workspaceDir,
    required Map<String, HarnessSkill> skills,
    required List<SkillDiagnostic> skillDiagnostics,
    required Future<int> Function() reloadSkills,
    required GenerationPreparationRuntime generationRuntime,
    required QueueControlRuntime queueRuntime,
    required ManualInpaintToolbox manualInpaintToolbox,
    required String Function() activeSessionId,
    required bool Function() isMounted,
  }) : _ref = ref,
       _workspaceDir = workspaceDir,
       _skills = skills,
       _skillDiagnostics = skillDiagnostics,
       _reloadSkills = reloadSkills,
       _generationRuntime = generationRuntime,
       _queueRuntime = queueRuntime,
       _manualInpaintToolbox = manualInpaintToolbox,
       _activeSessionId = activeSessionId,
       _isMounted = isMounted;

  final Ref _ref;
  final String _workspaceDir;
  final Map<String, HarnessSkill> _skills;
  final List<SkillDiagnostic> _skillDiagnostics;
  final Future<int> Function() _reloadSkills;
  final GenerationPreparationRuntime _generationRuntime;
  final QueueControlRuntime _queueRuntime;
  final ManualInpaintToolbox _manualInpaintToolbox;
  final String Function() _activeSessionId;
  final bool Function() _isMounted;

  /// 跨 build() 保留：权限模式切换不该抹掉本会话已经看过的图。
  final AgentImageObservationLedger _observationLedger =
      AgentImageObservationLedger();

  AgentToolRegistry build({
    required bool fullAccess,
    required AgentPermissionMode permissionMode,
  }) {
    final webAccessEnabled = _ref
        .read(agentSettingsProvider)
        .settings
        .chat
        .webAccessEnabled;
    _manualInpaintToolbox.configureFileAccess(
      workspaceDir: _workspaceDir,
      allowOutsideWorkspace: fullAccess,
    );
    _manualInpaintToolbox.configureObservationLedger(
      _observationLedger,
      activeSessionId: _activeSessionId,
    );
    _manualInpaintToolbox.configurePanelHandoff(({
      required source,
      required sourceWidth,
      required sourceHeight,
      required mask,
      required focusedInpaintEnabled,
      required focusedSelectionRect,
      required minimumContextMegaPixels,
      required sourceIsOutpaint,
    }) async {
      _ref
          .read(imageWorkflowControllerProvider.notifier)
          .applyInpaintEditorResult(
            sourceImage: source,
            sourceWidth: sourceWidth,
            sourceHeight: sourceHeight,
            maskImage: mask,
            focusedInpaintEnabled: focusedInpaintEnabled,
            focusedSelectionRect: focusedSelectionRect,
            minimumContextMegaPixels: minimumContextMegaPixels,
            sourceIsOutpaint: sourceIsOutpaint,
          );
      _ref.read(appRouterProvider).go(AppRoutes.generation);
    });
    final resourceResolver = AgentResourceResolver(
      _ref,
      loadInpaintDraftImage: _manualInpaintToolbox.loadDraftImage,
    );
    _manualInpaintToolbox.configureResourceResolver(resourceResolver);
    final workflowService = GenerationImageWorkflowService(
      loadResource: generationWorkflowResourceLoader(_ref),
      activeSessionId: _activeSessionId,
      isMounted: _isMounted,
      launcher: ApplicationGenerationImageWorkflowLauncher(
        ref: _ref,
        navigator: () => _ref
            .read(appRouterProvider)
            .routerDelegate
            .navigatorKey
            .currentState,
        openGeneration: () async =>
            _ref.read(appRouterProvider).go(AppRoutes.generation),
        manualInpaintToolbox: _manualInpaintToolbox,
      ),
    );
    final imageActionService = ImageResourceActionService(
      resolve: (reference) async {
        await resourceResolver.validateForDisplay(reference);
        final resolved = await resourceResolver.resolve(reference);
        final bytes = resolved?.bytes;
        return resolved == null || bytes == null
            ? null
            : ResolvedImageResourceActionSource(
                label: resolved.label,
                bytes: bytes,
              );
      },
      env: DartIoExecutionEnv(
        workingDirectory: _workspaceDir,
        allowOutsideWorkingDirectory: fullAccess,
      ),
      readKritaBridgeState: () {
        final state = _ref.read(kritaBridgeNotifierProvider);
        return ImageResourceKritaBridgeState(
          configured: state.enabled,
          connected: state.status == KritaBridgeStatus.connected,
        );
      },
      sendToKrita: (bytes, {required name}) => _ref
          .read(kritaBridgeNotifierProvider.notifier)
          .sendImageToKrita(bytes, name: name),
    );
    final tools = <AgentTool>[
      ...PromptToolbox(
        _ref,
        skills: _skills,
        skillDiagnostics: _skillDiagnostics,
        reloadSkills: _reloadSkills,
      ).tools(),
      ...ExecutionToolbox(
        _workspaceDir,
        allowOutsideWorkspace: fullAccess,
        observationLedger: _observationLedger,
        activeSessionId: _activeSessionId,
      ).tools(),
      ...GenerationToolbox(
        _ref,
        workspaceDir: _workspaceDir,
        allowOutsideWorkspace: fullAccess,
        runtime: _generationRuntime,
        resourceResolver: resourceResolver,
      ).tools(),
      ...QueueToolbox(_ref, _queueRuntime).tools(),
      ..._manualInpaintToolbox.tools(),
      ...TagToolbox(_ref).tools(),
      ...ApplicationToolbox(
        _ref,
        loadDrafts: _manualInpaintToolbox.listDraftSummaries,
        resourceResolver: resourceResolver,
      ).tools(),
      ...GalleryToolbox(_ref).tools(),
      ...ReferenceLibraryToolbox(_ref, resourceResolver).tools(),
      ...DisplayImagesToolbox(resourceResolver).tools(),
      ...GenerationResourceToolbox(_ref).tools(),
      ...GenerationImageWorkflowToolbox(workflowService).tools(),
      ...GenerationImageFavoriteToolbox(_ref).tools(),
      ...ImageResourceActionToolbox(imageActionService).tools(),
      if (webAccessEnabled)
        ...WebAccessToolbox(
          config: _ref
              .read(webAccessConfigProvider)
              .config
              .copyWith(enabled: true),
          loadGateway: () => _ref.read(webAccessGatewayProvider),
        ).tools(),
    ];
    final catalog = AgentToolPermissionCatalog(
      toolNames: tools.map((tool) => tool.name),
      descriptors: tools.map((tool) => describeAgentToolPermission(tool.name)),
    );
    final policy = agentPermissionPolicy(
      safeMode: permissionMode == AgentPermissionMode.safe,
      fullAccess: permissionMode == AgentPermissionMode.fullAccess,
    );
    return AgentToolRegistry(
      tools: [
        for (final tool in tools)
          if (_canRegisterTool(catalog.descriptorFor(tool.name), policy)) tool,
      ],
      catalog: catalog,
      policy: policy,
    );
  }

  bool _canRegisterTool(
    AgentToolPermissionDescriptor descriptor,
    AgentPermissionPolicy policy,
  ) {
    final mode = policy.modeFor(descriptor.domain);
    if (mode == AgentAccessMode.blocked) return false;
    return mode != AgentAccessMode.readOnly ||
        descriptor.operation == AgentPermissionOperation.read;
  }
}
