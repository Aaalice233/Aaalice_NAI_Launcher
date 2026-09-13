import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agent/permissions/permissions.dart';
import '../../agent_chat/services/agent_tool_registry_builder.dart';
import '../../agent_chat/services/agent_user_question_controller.dart';
import '../../agent_chat/services/generation_preparation_runtime.dart';
import '../../agent_chat/services/manual_inpaint_toolbox.dart';
import '../../agent_chat/services/queue_toolbox.dart';
import '../../prompt_assistant/models/prompt_assistant_models.dart';
import '../../router/app_router_config.dart';

/// 外部 MCP 客户端可见的工具面。
abstract final class McpExternalToolSurface {
  /// 排除项分三类：需要就地追问用户的交互工具、只对聊天气泡有意义的呈现工具、
  /// 以及外部客户端自带的检索与技能能力。
  static const Set<String> excludedToolNames = {
    'ask_user_question',
    'display_images',
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
        if (!excludedToolNames.contains(tool.name)) tool,
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
}

/// 为外部 MCP 客户端组装第二套工具注册表，复用聊天端同一份工具与权限目录，
/// 但换上不依赖聊天会话的替身依赖。
class McpExternalToolRegistryFactory {
  McpExternalToolRegistryFactory({
    required Ref ref,
    required Directory supportDir,
    required String workspaceDir,
    required bool Function() isHostAlive,
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
    );
  }

  /// 外部调用没有聊天会话，用固定 id 让草稿与观察台账仍能归属同一来源。
  static const String sessionId = 'mcp';

  final bool Function() _isHostAlive;
  final GenerationPreparationRuntime generationRuntime;
  final QueueControlRuntime queueRuntime;
  final ManualInpaintToolbox manualInpaintToolbox;
  late final AgentToolRegistryBuilder _builder;

  AgentToolRegistry build(AgentPermissionMode mode) {
    return McpExternalToolSurface.filter(
      _builder.build(
        fullAccess: mode == AgentPermissionMode.fullAccess,
        permissionMode: mode,
      ),
    );
  }
}
