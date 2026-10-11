import 'package:dart_mcp/server.dart' as mcp;
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/mcp/mcp_tool_adapter.dart';
import 'package:nai_launcher/core/mcp/mcp_tool_executor.dart';

typedef FakeAgentToolHandler =
    Future<AgentToolResult> Function(
      String toolCallId,
      Map<String, dynamic> params,
      AbortSignal? signal,
    );

/// Minimal [AgentTool] for core tests; the real tools live in the
/// presentation layer and drag in Riverpod.
class FakeAgentTool extends AgentTool {
  FakeAgentTool({
    required super.name,
    required super.label,
    super.description = 'Fake tool.',
    super.parameters = const {
      'type': 'object',
      'properties': <String, dynamic>{},
    },
    FakeAgentToolHandler? handler,
  }) : _handler = handler;

  final FakeAgentToolHandler? _handler;

  @override
  Future<AgentToolResult> execute(
    String toolCallId,
    Map<String, dynamic> params, [
    AbortSignal? signal,
    AgentToolUpdateCallback? onUpdate,
  ]) async {
    final handler = _handler;
    if (handler != null) {
      return handler(toolCallId, params, signal);
    }
    return AgentToolResult(
      content: [ToolResultTextContent('$name ran')],
      details: <String, dynamic>{'tool': name, 'params': params},
    );
  }
}

/// Records what the transport handed over and, unless [onCall] overrides it,
/// runs the matching [FakeAgentTool] through [McpToolAdapter].
class FakeMcpToolExecutor implements McpToolExecutor {
  FakeMcpToolExecutor(this.tools, {this.onCall});

  @override
  final List<AgentTool> tools;

  final List<McpToolCallRequest> calls = <McpToolCallRequest>[];

  Future<mcp.CallToolResult> Function(McpToolCallRequest request)? onCall;

  McpToolCallRequest get lastCall => calls.last;

  @override
  Future<mcp.CallToolResult> call(McpToolCallRequest request) async {
    calls.add(request);
    final handler = onCall;
    if (handler != null) {
      return handler(request);
    }
    final tool = tools.firstWhere((tool) => tool.name == request.toolName);
    final result = await tool.execute(
      request.callId,
      request.arguments,
      request.signal,
    );
    return McpToolAdapter.toCallToolResult(result);
  }
}
