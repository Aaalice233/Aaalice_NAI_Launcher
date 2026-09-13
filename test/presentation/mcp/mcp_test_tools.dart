import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/permissions/permissions.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_tool_registry_builder.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';

typedef FakeToolRunner =
    Future<AgentToolResult> Function(
      Map<String, dynamic> args,
      AbortSignal? signal,
    );

const Map<String, dynamic> fakeToolParameters = {
  'type': 'object',
  'properties': {
    'value': {'type': 'string'},
  },
  'additionalProperties': false,
};

class FakeAgentTool extends AgentTool {
  FakeAgentTool({
    required super.name,
    super.description = 'Fake tool for MCP pipeline tests',
    super.label = 'Fake tool',
    super.parameters = fakeToolParameters,
    this.runner,
  });

  final FakeToolRunner? runner;

  @override
  Future<AgentToolResult> execute(
    String toolCallId,
    Map<String, dynamic> params, [
    AbortSignal? signal,
    AgentToolUpdateCallback? onUpdate,
  ]) {
    final run = runner;
    if (run != null) return run(params, signal);
    return Future.value(
      AgentToolResult(
        content: [ToolResultTextContent('ok:$name')],
        details: {'tool': name},
      ),
    );
  }
}

AgentToolRegistry fakeToolRegistry(
  List<AgentTool> tools, {
  AgentPermissionMode mode = AgentPermissionMode.askBeforeSensitiveActions,
}) {
  return AgentToolRegistry(
    tools: tools,
    catalog: AgentToolPermissionCatalog(
      toolNames: tools.map((tool) => tool.name),
      descriptors: tools.map((tool) => describeAgentToolPermission(tool.name)),
    ),
    policy: agentPermissionPolicy(
      safeMode: mode == AgentPermissionMode.safe,
      fullAccess: mode == AgentPermissionMode.fullAccess,
    ),
  );
}

BeforeToolCallContext fakeBeforeToolCallContext({
  required String callId,
  required String toolName,
  required Map<String, dynamic> args,
  required List<AgentTool> tools,
}) {
  final toolCall = ToolCallContent(
    id: callId,
    name: toolName,
    arguments: args,
  );
  return BeforeToolCallContext(
    assistantMessage: AssistantMessage(
      content: [toolCall],
      stopReason: StopReason.toolUse,
    ),
    toolCall: toolCall,
    args: args,
    context: AgentContext(
      systemPrompt: '',
      messages: const [],
      tools: tools,
    ),
  );
}
