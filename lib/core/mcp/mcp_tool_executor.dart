import 'package:dart_mcp/server.dart' show CallToolResult;

import '../agent/agent_types.dart';

/// One `tools/call` as seen by the launcher, already stripped of transport
/// details.
class McpToolCallRequest {
  const McpToolCallRequest({
    required this.sessionId,
    required this.callId,
    required this.toolName,
    required this.arguments,
    required this.signal,
    required this.clientLabel,
  });

  final String sessionId;
  final String callId;
  final String toolName;
  final Map<String, dynamic> arguments;
  final AbortSignal signal;
  final String clientLabel;
}

/// Boundary between the transport-only server in `core/mcp` and the
/// Riverpod-bound tool host in `presentation/mcp`.
abstract interface class McpToolExecutor {
  /// Deterministically ordered; drives `tools/list`.
  List<AgentTool> get tools;

  Future<CallToolResult> call(McpToolCallRequest request);
}
