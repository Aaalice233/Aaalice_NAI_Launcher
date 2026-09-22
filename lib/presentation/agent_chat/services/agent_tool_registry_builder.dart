import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agent/agent.dart';
import '../../../core/agent/harness/env/dart_io_execution_env.dart';
import '../../../core/agent/harness/harness_types.dart';
import '../../../core/agent/harness/skills.dart';
import '../../../core/agent/permissions/permissions.dart';
import '../../agent_settings/providers/agent_settings_provider.dart';
import '../../../data/models/prompt_assistant/prompt_assistant_models.dart';
import '../../prompt_assistant/providers/web_access_provider.dart';
import '../../providers/generation/image_workflow_controller.dart';
import '../../providers/krita/krita_bridge_notifier.dart';
import '../../router/app_router_config.dart';
import '../../router/app_routes.dart';
import 'agent_image_observation_ledger.dart';
import 'agent_attached_image.dart';
import 'agent_resource_resolver.dart';
import 'application_context_toolbox.dart';
import 'execution_toolbox.dart';
import 'fixed_tags_toolbox.dart';
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
import 'image_presentation_toolbox.dart';
import 'manual_inpaint_toolbox.dart';
import 'prompt_toolbox.dart';
import 'queue_toolbox.dart';
import 'reference_library_toolbox.dart';
import 'tag_toolbox.dart';
import 'tag_library_toolbox.dart';
import 'web_access_toolbox.dart';
import 'agent_user_question_controller.dart';
import 'user_question_toolbox.dart';

/// 聊天端唯一能拿到原分辨率图片的入口就是 read 工具。
const String _chatObservationGuidance =
    'Read the image file with the read tool first; generated images expose a '
    'workspace path only once they are saved to disk.';

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
    required List<Message> Function() messages,
    required AgentUserQuestionController questionController,
    ImageResourceExportPreparer? prepareImageExport,
    AgentImageObservationLedger? observationLedger,
    bool referencesGalleryOriginal = false,
    String observationGuidance = _chatObservationGuidance,
  }) : _ref = ref,
       _workspaceDir = workspaceDir,
       _skills = skills,
       _skillDiagnostics = skillDiagnostics,
       _reloadSkills = reloadSkills,
       _generationRuntime = generationRuntime,
       _queueRuntime = queueRuntime,
       _manualInpaintToolbox = manualInpaintToolbox,
       _activeSessionId = activeSessionId,
       _isMounted = isMounted,
       _messages = messages,
       _questionController = questionController,
       _prepareImageExport = prepareImageExport,
       _observationLedger = observationLedger ?? AgentImageObservationLedger(),
       _referencesGalleryOriginal = referencesGalleryOriginal,
       _observationGuidance = observationGuidance;

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
  final List<Message> Function() _messages;
  final AgentUserQuestionController _questionController;
  final ImageResourceExportPreparer? _prepareImageExport;
  final bool _referencesGalleryOriginal;
  final String _observationGuidance;

  /// 跨 build() 保留：权限模式切换不该抹掉本会话已经看过的图。
  final AgentImageObservationLedger _observationLedger;

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
      observationGuidance: _observationGuidance,
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
      prepareExport: _prepareImageExport,
      resolve: (reference) async {
        await resourceResolver.validateImageResource(reference);
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
      ...UserQuestionToolbox(_questionController).tools(),
      ...PromptToolbox(
        _ref,
        skills: _skills,
        skillDiagnostics: _skillDiagnostics,
        reloadSkills: _reloadSkills,
      ).tools(),
      ...ExecutionToolbox(
        _workspaceDir,
        allowOutsideWorkspace: fullAccess,
      ).tools(),
      ...GenerationToolbox(
        _ref,
        workspaceDir: _workspaceDir,
        allowOutsideWorkspace: fullAccess,
        runtime: _generationRuntime,
        resourceResolver: resourceResolver,
        readAttachedImage: (index) =>
            readAgentAttachedImage(_messages(), index),
        prepareImageExport: _prepareImageExport,
        referencesGalleryOriginal: _referencesGalleryOriginal,
      ).tools(),
      ...QueueToolbox(_ref, _queueRuntime).tools(),
      ..._manualInpaintToolbox.tools(),
      ...TagToolbox(_ref).tools(),
      ...ApplicationContextToolbox(
        _ref,
        loadDrafts: _manualInpaintToolbox.listDraftSummaries,
      ).tools(),
      ...TagLibraryToolbox(_ref, resourceResolver: resourceResolver).tools(),
      ...FixedTagsToolbox(_ref).tools(),
      ...GalleryToolbox(_ref).tools(),
      ...ReferenceLibraryToolbox(_ref, resourceResolver).tools(),
      ...ImagePresentationToolbox(resourceResolver).tools(),
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
          if (_canRegisterTool(catalog.descriptorFor(tool.name), policy))
            // 任何工具都可能把图喂给模型，记录点放在注册表出口而不是某个工具内部。
            ImageObservingAgentTool(
              tool,
              ledger: _observationLedger,
              activeSessionId: _activeSessionId,
            ),
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
