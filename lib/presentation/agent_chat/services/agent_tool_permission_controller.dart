import 'dart:async';

import '../../../core/agent/agent.dart';
import '../../../core/agent/audit/audit_event.dart';
import '../../../core/agent/audit/audit_sink.dart';
import '../../../core/agent/permissions/permissions.dart';
import '../../../core/utils/app_logger.dart';
import '../providers/agent_chat_state.dart';
import 'agent_tool_registry_builder.dart';

class AgentToolPermissionController {
  AgentToolPermissionController({
    required AgentAuditSink auditSink,
    required Future<int?> Function(String toolName, Map<String, dynamic> args)
    estimateAnlas,
    required void Function(AgentToolApprovalRequest? request) onApprovalChanged,
    required bool Function() isMounted,
  }) : _auditSink = auditSink,
       _estimateAnlas = estimateAnlas,
       _onApprovalChanged = onApprovalChanged,
       _isMounted = isMounted;

  final AgentAuditSink _auditSink;
  final Future<int?> Function(String, Map<String, dynamic>) _estimateAnlas;
  final void Function(AgentToolApprovalRequest?) _onApprovalChanged;
  final bool Function() _isMounted;
  final Map<String, AgentPermissionDecision> _toolDecisions = {};

  AgentToolPermissionCatalog? _catalog;
  AgentPermissionPolicy? _policy;
  Completer<bool>? _approvalCompleter;

  void configure(AgentToolRegistry registry) {
    _catalog = registry.catalog;
    _policy = registry.policy;
  }

  Future<BeforeToolCallResult?> beforeToolCall(
    BeforeToolCallContext context,
    AbortSignal? signal,
  ) async {
    final catalog = _catalog;
    final permissionPolicy = _policy;
    if (catalog == null || permissionPolicy == null) {
      await writeAudit(
        id: '${context.toolCall.id}.decision',
        summary: '${context.toolCall.name} permission catalog unavailable',
        result: AgentPermissionDecision.block,
      );
      return const BeforeToolCallResult(
        block: true,
        reason: 'Agent tool permission catalog is unavailable.',
      );
    }
    final descriptor = catalog.descriptorFor(context.toolCall.name);
    final accessMode = permissionPolicy.modeFor(descriptor.domain);
    if (accessMode == AgentAccessMode.blocked ||
        (accessMode == AgentAccessMode.readOnly &&
            descriptor.operation != AgentPermissionOperation.read)) {
      await writeAudit(
        id: '${context.toolCall.id}.decision',
        summary:
            '${context.toolCall.name} ${descriptor.domain.name}/'
            '${descriptor.operation.name}',
        result: AgentPermissionDecision.block,
      );
      return const BeforeToolCallResult(
        block: true,
        reason: 'This tool is blocked by its permission domain policy.',
      );
    }
    final args = context.args is Map<String, dynamic>
        ? Map<String, dynamic>.from(context.args as Map<String, dynamic>)
        : const <String, dynamic>{};
    final catalogDecision = catalog.decide(
      toolName: context.toolCall.name,
      policy: permissionPolicy,
    );
    final isNonBillingPreparation =
        (context.toolCall.name == 'generate_image' ||
            context.toolCall.name == 'queue_image_task') &&
        args['preparation_id'] is! String;
    final decision = isNonBillingPreparation
        ? AgentPermissionDecision.allow
        : catalogDecision;
    _toolDecisions[context.toolCall.id] = decision;
    await writeAudit(
      id: '${context.toolCall.id}.decision',
      summary:
          '${context.toolCall.name} ${descriptor.domain.name}/'
          '${descriptor.operation.name}',
      result: decision,
    );
    if (decision == AgentPermissionDecision.allow) {
      return null;
    }
    if (decision == AgentPermissionDecision.block) {
      return const BeforeToolCallResult(
        block: true,
        reason: 'This tool is blocked by its permission domain policy.',
      );
    }
    final previousApproval = _approvalCompleter;
    if (previousApproval != null && !previousApproval.isCompleted) {
      previousApproval.complete(false);
    }
    final completer = Completer<bool>();
    _approvalCompleter = completer;
    final estimatedAnlas = await _estimateAnlas(context.toolCall.name, args);
    _onApprovalChanged(
      AgentToolApprovalRequest(
        toolCallId: context.toolCall.id,
        toolName: context.toolCall.name,
        args: args,
        estimatedAnlas: estimatedAnlas,
      ),
    );

    void onAbort(String? _) {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    }

    signal?.addListener(onAbort);
    final approved = await completer.future;
    signal?.removeListener(onAbort);
    if (identical(_approvalCompleter, completer)) {
      _approvalCompleter = null;
      if (_isMounted()) {
        _onApprovalChanged(null);
      }
    }
    await writeAudit(
      id: '${context.toolCall.id}.approval',
      summary: '${context.toolCall.name} user approval',
      result: approved
          ? AgentPermissionDecision.allow
          : AgentPermissionDecision.block,
    );
    if (!approved) _toolDecisions.remove(context.toolCall.id);
    return approved
        ? null
        : const BeforeToolCallResult(
            block: true,
            reason: 'The user declined this tool call.',
          );
  }

  void resolveApproval(bool approved) {
    final completer = _approvalCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(approved);
    }
  }

  AgentPermissionDecision takeDecision(String toolCallId) =>
      _toolDecisions.remove(toolCallId) ?? AgentPermissionDecision.block;

  Future<void> writeAudit({
    required String id,
    required String summary,
    required AgentPermissionDecision result,
    String? error,
  }) async {
    try {
      await _auditSink.write(
        AgentAuditEvent(
          id: id.replaceAll(RegExp(r'[^A-Za-z0-9._:-]'), '_'),
          summary: summary,
          result: result,
          error: error,
          timestamp: DateTime.now(),
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.e('agent audit write failed', error, stackTrace, 'AgentChat');
    }
  }

  void dispose() => resolveApproval(false);
}
