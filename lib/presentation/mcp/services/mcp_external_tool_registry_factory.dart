import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agent/agent_types.dart';
import '../../../core/agent/permissions/permissions.dart';
import '../../../core/mcp/mcp_image_http_endpoint.dart';
import '../../agent_chat/services/agent_resource_resolver.dart';
import '../../agent_chat/services/agent_tool_registry_builder.dart';
import '../../agent_chat/services/agent_user_question_controller.dart';
import '../../agent_chat/services/defined_agent_tool.dart';
import '../../agent_chat/services/generation_preparation_runtime.dart';
import '../../agent_chat/services/manual_inpaint_toolbox.dart';
import '../../agent_chat/services/queue_toolbox.dart';
import '../../prompt_assistant/models/prompt_assistant_models.dart';
import '../../providers/share_image_settings_provider.dart';
import '../../router/app_router_config.dart';
import 'mcp_compact_tool_response.dart';
import 'mcp_image_response_service.dart';
import 'mcp_image_tool_descriptions.dart';

/// 外部 MCP 客户端可见的工具面。
abstract final class McpExternalToolSurface {
  /// 排除需要就地追问用户的交互工具与外部客户端自带的检索和技能能力。
  static const Set<String> excludedToolNames = {
    'ask_user_question',
    'read',
    'read_skill',
    'read_skill_resource',
    'get_skill_diagnostics',
    'reload_skills',
    'web_search',
    'web_read',
  };

  /// 保留注册顺序，让 `tools/list` 在同一权限模式下逐次一致。
  static AgentToolRegistry filter(AgentToolRegistry registry) {
    final tools = [
      for (final tool in registry.tools)
        if (!excludedToolNames.contains(tool.name))
          if (mcpImageToolDescriptions[tool.name] case final description?)
            DefinedAgentTool(
              name: tool.name,
              label: tool.label,
              description: description,
              parameters: _parametersFor(tool.name, tool.parameters),
              executionModeOverride: tool.executionMode,
              executeWithControl: tool.execute,
            )
          else
            tool,
    ];
    return AgentToolRegistry(
      tools: tools,
      catalog: AgentToolPermissionCatalog(
        toolNames: tools.map((tool) => tool.name),
        descriptors: tools.map(
          (tool) => describeAgentToolPermission(tool.name),
        ),
      ),
      policy: registry.policy,
    );
  }

  static Map<String, dynamic> _parametersFor(
    String name,
    Map<String, dynamic> parameters,
  ) => {
    ...parameters,
    'properties': {
      ...parameters['properties'] as Map<String, dynamic>,
      if (mcpPreparationToolNames.contains(name))
        'include_parameters': {
          'type': 'boolean',
          'description':
              'Return the full prepared snapshot instead of a compact summary. Default false.',
        },
      if (name == 'get_application_context')
        'include_draft_details': {
          'type': 'boolean',
          'description':
              'Include full draft parameter snapshots. Default false.',
        },
      if ({
        'generate_image',
        'submit_generation',
        'display_images',
      }.contains(name)) ...{
        'include_display_file': {
          'type': 'boolean',
          'description':
              'Include a safe same-machine display-cache file. Defaults to true for Codex, false otherwise.',
        },
        'include_display_url': {
          'type': 'boolean',
          'description':
              'Include a temporary same-machine HTTP display reference. Default true.',
        },
      },
    },
  };
}

/// 为外部 MCP 客户端组装第二套工具注册表，复用聊天端同一份工具与权限目录，
/// 但换上不依赖聊天会话的替身依赖。
class McpExternalToolRegistryFactory {
  McpExternalToolRegistryFactory({
    required Ref ref,
    required Directory supportDir,
    required String workspaceDir,
    required bool Function() isHostAlive,
    McpImageDisplayPublisher? publishDisplayImage,
  }) : _isHostAlive = isHostAlive,
       generationRuntime = GenerationPreparationRuntime(),
       queueRuntime = QueueControlRuntime(),
       manualInpaintToolbox = ManualInpaintToolbox(
         ref,
         supportDirectory: supportDir,
         workspaceDir: workspaceDir,
         navigator: () => ref
             .read(appRouterProvider)
             .routerDelegate
             .navigatorKey
             .currentState,
         activeSessionId: () => sessionId,
       ) {
    final resolver = AgentResourceResolver(
      ref,
      loadInpaintDraftImage: manualInpaintToolbox.loadDraftImage,
    );
    imageResponses = McpImageResponseService(
      resolve: resolver.resolve,
      validate: resolver.validateImageResource,
      publishDisplayImage: publishDisplayImage,
      shouldStripMetadata: () {
        if (!_isHostAlive()) throw StateError('MCP host is unavailable');
        return ref
            .read(shareImageSettingsProvider)
            .effectiveStripMetadataForCopyAndDrag;
      },
    );
    _builder = AgentToolRegistryBuilder(
      ref: ref,
      workspaceDir: workspaceDir,
      skills: const {},
      skillDiagnostics: const [],
      reloadSkills: () async => 0,
      generationRuntime: generationRuntime,
      queueRuntime: queueRuntime,
      manualInpaintToolbox: manualInpaintToolbox,
      activeSessionId: () => sessionId,
      isMounted: _isHostAlive,
      messages: () => const [],
      questionController: AgentUserQuestionController(onChanged: (_) {}),
      prepareImageExport: imageResponses.prepareExportImage,
      observationGuidance:
          'Call inspect_images with the image resource_ref first; it returns '
          'the full-resolution image.',
    );
  }

  /// 外部调用没有聊天会话，用固定 id 让草稿与观察台账仍能归属同一来源。
  static const String sessionId = 'mcp';

  final bool Function() _isHostAlive;
  final GenerationPreparationRuntime generationRuntime;
  final QueueControlRuntime queueRuntime;
  final ManualInpaintToolbox manualInpaintToolbox;
  late final AgentToolRegistryBuilder _builder;
  late final McpImageResponseService imageResponses;

  AgentToolRegistry build(AgentPermissionMode mode) {
    return McpExternalToolSurface.filter(
      _builder.build(
        fullAccess: mode == AgentPermissionMode.fullAccess,
        permissionMode: mode,
      ),
    );
  }

  void observeToolResult(AgentToolResult result) =>
      _builder.observeToolResult(result);
}
