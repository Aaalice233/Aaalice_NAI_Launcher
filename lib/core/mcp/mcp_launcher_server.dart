import 'package:dart_mcp/server.dart' as mcp;

import '../agent/agent_types.dart';
import '../utils/portable_logger.dart';
import 'mcp_server_constants.dart';
import 'mcp_tool_adapter.dart';
import 'mcp_tool_executor.dart';

/// One MCP protocol endpoint. It owns no transport: the caller hands it a
/// channel and every tool call is delegated to [McpToolExecutor].
final class McpLauncherServer extends mcp.MCPServer with mcp.ToolsSupport {
  McpLauncherServer.fromStreamChannel(
    super.channel, {
    required McpToolExecutor executor,
    required this.sessionId,
    required String appVersion,
    required AbortSignal Function(String callId) signalFor,
    this.onClientInfo,
  }) : _executor = executor,
       _signalFor = signalFor,
       super.fromStreamChannel(
         implementation: mcp.Implementation(
           name: McpServerDefaults.serverName,
           version: appVersion,
         ),
         instructions: _instructions,
       ) {
    for (final tool in executor.tools) {
      registerTool(
        McpToolAdapter.toMcpTool(tool),
        (request) => _invoke(tool.name, request),
        validateArguments: false,
      );
    }
  }

  static const String unknownClientLabel = 'unknown client';
  static const String _logTag = 'McpServer';

  static const String _instructions =
      'Images: prepare_generation then submit_generation; embed top-level '
      'display_markdown in the final answer, not only tool images. Read state '
      'as needed. Paid calls wait for launcher approval; never retry pending calls.';

  final String sessionId;
  final McpToolExecutor _executor;
  final AbortSignal Function(String callId) _signalFor;
  final void Function(mcp.Implementation clientInfo)? onClientInfo;

  mcp.Implementation? _connectedClient;
  int _fallbackCallSequence = 0;

  /// `<name> <version>` of the connected client, for approval prompts and the
  /// session list.
  String get clientLabel => clientLabelFor(_connectedClient);

  static String clientLabelFor(mcp.Implementation? clientInfo) {
    if (clientInfo == null) {
      return unknownClientLabel;
    }
    try {
      final label = '${clientInfo.name} ${clientInfo.version}'.trim();
      return label.isEmpty ? unknownClientLabel : label;
    } on ArgumentError {
      return unknownClientLabel;
    }
  }

  @override
  Future<mcp.InitializeResult> initialize(mcp.InitializeRequest request) async {
    final result = await super.initialize(request);
    final info = clientInfo;
    _connectedClient = info;
    onClientInfo?.call(info);
    return result;
  }

  Future<mcp.CallToolResult> _invoke(
    String toolName,
    mcp.CallToolRequest request,
  ) async {
    final callId = _callIdOf(request);
    try {
      return await _executor.call(
        McpToolCallRequest(
          sessionId: sessionId,
          callId: callId,
          toolName: toolName,
          arguments: Map<String, dynamic>.from(
            request.arguments ?? const <String, Object?>{},
          ),
          signal: _signalFor(callId),
          clientLabel: clientLabel,
        ),
      );
    } catch (error, stackTrace) {
      PortableLogger.e(
        'tools/call $toolName failed',
        error,
        stackTrace,
        _logTag,
      );
      return McpToolAdapter.errorResult('Tool "$toolName" failed: $error');
    }
  }

  String _callIdOf(mcp.CallToolRequest request) {
    final injected = request.meta?[McpServerDefaults.callIdMetaKey];
    if (injected is String && injected.isNotEmpty) {
      return injected;
    }
    return '$sessionId-local-${_fallbackCallSequence++}';
  }
}
