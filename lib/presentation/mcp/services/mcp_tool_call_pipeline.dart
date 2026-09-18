import 'package:dart_mcp/server.dart' show CallToolResult;
import 'package:synchronized/synchronized.dart';

import '../../../core/agent/agent_types.dart';
import '../../../core/agent/audit/audit_event.dart';
import '../../../core/agent/audit/audit_sink.dart';
import '../../../core/agent/permissions/permissions.dart';
import '../../../core/agent/validate_tool_arguments.dart';
import '../../../core/mcp/mcp_tool_adapter.dart';
import '../../../core/mcp/mcp_tool_executor.dart';
import '../../../core/utils/app_logger.dart';
import '../../agent_chat/services/agent_tool_registry_builder.dart';
import 'mcp_approval_coordinator.dart';
import 'mcp_compact_tool_response.dart';
import 'mcp_image_response_service.dart';

const String _logTag = 'McpServer';

/// 外部 `tools/call` 的执行链：与聊天端共用注册表、参数校验、权限门与审计，
/// 只把非只读工具串行化，保证同一时刻至多一个待授权的写操作。
class LauncherMcpToolExecutor implements McpToolExecutor {
  LauncherMcpToolExecutor({
    required AgentToolRegistry Function() registry,
    required McpApprovalCoordinator approvals,
    required AgentAuditSink auditSink,
    required McpImageResponseService imageResponses,
    void Function(AgentToolResult result)? observeResult,
    Lock? writeLock,
  }) : _registry = registry,
       _approvals = approvals,
       _auditSink = auditSink,
       _imageResponses = imageResponses,
       _observeResult = observeResult,
       _writeLock = writeLock ?? Lock();

  final AgentToolRegistry Function() _registry;
  final McpApprovalCoordinator _approvals;
  final AgentAuditSink _auditSink;
  final McpImageResponseService _imageResponses;
  final void Function(AgentToolResult result)? _observeResult;
  final Lock _writeLock;

  @override
  List<AgentTool> get tools => _registry().tools;

  @override
  Future<CallToolResult> call(McpToolCallRequest request) async {
    final registry = _registry();
    final tool = registry.tools
        .where((candidate) => candidate.name == request.toolName)
        .firstOrNull;
    if (tool == null) {
      await _writeAudit(
        request,
        stage: 'lookup',
        result: AgentPermissionDecision.block,
        error: 'unknown tool',
      );
      return McpToolAdapter.errorResult('Tool ${request.toolName} not found');
    }

    final Map<String, dynamic> args;
    try {
      args = validateToolArguments(
        tool,
        ToolCallContent(
          id: request.callId,
          name: request.toolName,
          arguments: request.arguments,
        ),
      );
    } catch (error) {
      await _writeAudit(
        request,
        stage: 'validation',
        result: AgentPermissionDecision.block,
        error: '$error',
      );
      return McpToolAdapter.errorResult('$error');
    }

    final descriptor = registry.catalog.descriptorFor(request.toolName);
    if (descriptor.operation == AgentPermissionOperation.read) {
      return _gateAndExecute(registry, tool, args, request);
    }
    return _writeLock.synchronized(
      () => _gateAndExecute(registry, tool, args, request),
    );
  }

  Future<CallToolResult> _gateAndExecute(
    AgentToolRegistry registry,
    AgentTool tool,
    Map<String, dynamic> args,
    McpToolCallRequest request,
  ) async {
    if (request.signal.aborted) {
      // 排队等写锁期间被取消：抢在审批卡和提示音之前退出。
      await _writeAudit(
        request,
        stage: 'result',
        result: AgentPermissionDecision.block,
        error: 'Operation aborted',
      );
      return McpToolAdapter.errorResult('Operation aborted');
    }
    final toolCall = ToolCallContent(
      id: request.callId,
      name: request.toolName,
      arguments: args,
    );
    _approvals.bindClientLabel(request.callId, request.clientLabel);
    try {
      final gate = await _approvals.controller.beforeToolCall(
        BeforeToolCallContext(
          assistantMessage: AssistantMessage(
            content: [toolCall],
            stopReason: StopReason.toolUse,
          ),
          toolCall: toolCall,
          args: args,
          context: AgentContext(
            systemPrompt: '',
            messages: const [],
            tools: registry.tools,
          ),
        ),
        request.signal,
      );
      if (request.signal.aborted) {
        return McpToolAdapter.errorResult('Operation aborted');
      }
      if (gate?.block == true) {
        return McpToolAdapter.errorResult(
          gate?.reason ?? 'Tool execution was blocked',
        );
      }
      final rawResult = await tool.execute(
        request.callId,
        Map<String, dynamic>.from(args)
          ..remove('include_parameters')
          ..remove('include_draft_details')
          ..remove('include_display_file')
          ..remove('include_display_url'),
        request.signal,
      );
      final result = await _imageResponses.prepare(
        tool.name,
        compactMcpToolResponse(
          tool.name,
          rawResult,
          includeParameters: args['include_parameters'] == true,
          includeDraftDetails: args['include_draft_details'] == true,
        ),
        signal: request.signal,
        includeDisplayFile: args['include_display_file'] as bool?,
        includeDisplayUrl: args['include_display_url'] != false,
        style: McpImageResponseService.styleForClient(request.clientLabel),
      );
      // 记的是 prepare 之后的结果：外部客户端收到的是原图，不是工具原始返回的缩略图。
      _observeResult?.call(result);
      await _writeAudit(
        request,
        stage: 'result',
        result: result.isError
            ? AgentPermissionDecision.block
            : AgentPermissionDecision.allow,
      );
      return McpToolAdapter.toCallToolResult(result);
    } catch (error) {
      await _writeAudit(
        request,
        stage: 'result',
        result: AgentPermissionDecision.block,
        error: '$error',
      );
      return McpToolAdapter.errorResult('$error');
    } finally {
      _approvals.releaseClientLabel(request.callId);
    }
  }

  Future<void> _writeAudit(
    McpToolCallRequest request, {
    required String stage,
    required AgentPermissionDecision result,
    String? error,
  }) async {
    try {
      await _auditSink.write(
        AgentAuditEvent(
          id: _auditId('${request.callId}.$stage'),
          summary: '${request.toolName} via ${request.clientLabel}',
          result: result,
          error: error,
          timestamp: DateTime.now(),
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.e('mcp audit write failed', error, stackTrace, _logTag);
    }
  }

  static String _auditId(String value) {
    final sanitized = value.replaceAll(RegExp(r'[^A-Za-z0-9._:-]'), '_');
    return sanitized.isEmpty ? 'mcp_call' : sanitized;
  }
}
