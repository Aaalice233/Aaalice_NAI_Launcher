import 'dart:async';

import '../../../core/agent/audit/audit_sink.dart';
import '../../../core/mcp/mcp_server_constants.dart';
import '../../agent_chat/providers/agent_chat_state.dart';
import '../../agent_chat/services/agent_tool_permission_controller.dart';
import '../../agent_chat/services/agent_tool_registry_builder.dart';

/// 一次等待用户裁决的外部工具调用。
class McpApprovalRequest {
  const McpApprovalRequest({
    required this.request,
    required this.clientLabel,
    required this.expiresAt,
  });

  final AgentToolApprovalRequest request;
  final String clientLabel;
  final DateTime expiresAt;

  String get toolCallId => request.toolCallId;
}

/// 把聊天端的权限门用于外部 MCP 调用：补上发起方标签，并给每次授权加上
/// 到期自动拒绝，避免客户端在无人值守时永久挂起。
class McpApprovalCoordinator {
  McpApprovalCoordinator({
    required AgentAuditSink auditSink,
    required Future<int?> Function(String toolName, Map<String, dynamic> args)
    estimateAnlas,
    required List<String> Function(String toolName, Map<String, dynamic> args)
    describeFileTargets,
    required bool Function() isMounted,
    Duration timeout = McpServerDefaults.approvalTimeout,
    DateTime Function()? clock,
    Future<void> Function()? notifyRequested,
  }) : _timeout = timeout,
       _clock = clock ?? DateTime.now,
       _notifyRequested = notifyRequested {
    controller = AgentToolPermissionController(
      auditSink: auditSink,
      estimateAnlas: estimateAnlas,
      describeFileTargets: describeFileTargets,
      onApprovalChanged: _handleApprovalChanged,
      isMounted: () => !_disposed && isMounted(),
    );
  }

  final Duration _timeout;
  final DateTime Function() _clock;
  final Future<void> Function()? _notifyRequested;
  final Map<String, String> _clientLabels = {};
  final StreamController<McpApprovalRequest?> _changes =
      StreamController<McpApprovalRequest?>.broadcast();

  late final AgentToolPermissionController controller;
  Timer? _expiry;
  McpApprovalRequest? _current;
  bool _disposed = false;

  McpApprovalRequest? get current => _current;

  Stream<McpApprovalRequest?> get changes => _changes.stream;

  void configure(AgentToolRegistry registry) => controller.configure(registry);

  void bindClientLabel(String toolCallId, String clientLabel) {
    if (_disposed) return;
    _clientLabels[toolCallId] = clientLabel;
  }

  void releaseClientLabel(String toolCallId) =>
      _clientLabels.remove(toolCallId);

  bool resolve(String toolCallId, bool approved) {
    if (_disposed) return false;
    final resolved = controller.resolveApproval(toolCallId, approved);
    if (resolved && _current?.toolCallId == toolCallId) _clear();
    return resolved;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _expiry?.cancel();
    _expiry = null;
    _current = null;
    _clientLabels.clear();
    controller.dispose();
    unawaited(_changes.close());
  }

  void _handleApprovalChanged(AgentToolApprovalRequest? request) {
    if (_disposed) return;
    if (request == null) {
      _clear();
      return;
    }
    _expiry?.cancel();
    final pending = McpApprovalRequest(
      request: request,
      clientLabel: _clientLabels[request.toolCallId] ?? '',
      expiresAt: _clock().add(_timeout),
    );
    _current = pending;
    _expiry = Timer(_timeout, () => resolve(pending.toolCallId, false));
    _emit(pending);
    final notify = _notifyRequested;
    if (notify != null) unawaited(notify());
  }

  void _clear() {
    _expiry?.cancel();
    _expiry = null;
    if (_current == null) return;
    _current = null;
    _emit(null);
  }

  void _emit(McpApprovalRequest? request) {
    if (_changes.isClosed) return;
    _changes.add(request);
  }
}
