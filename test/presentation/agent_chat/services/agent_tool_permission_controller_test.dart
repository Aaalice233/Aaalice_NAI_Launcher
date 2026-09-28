import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent.dart';
import 'package:nai_launcher/core/agent/audit/audit_sink.dart';
import 'package:nai_launcher/core/agent/permissions/permissions.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_state.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_tool_permission_controller.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_tool_registry_builder.dart';

void main() {
  test(
    'ask mode permits read-only image interrogation without approval',
    () async {
      final descriptor = describeAgentToolPermission('interrogate_image');
      final audit = MemoryAgentAuditSink();
      final controller = AgentToolPermissionController(
        auditSink: audit,
        estimateAnlas: (_, _) async => throw StateError('Read does not bill'),
        onApprovalChanged: (_) =>
            fail('Read should not request write approval'),
        isMounted: () => true,
      );
      addTearDown(controller.dispose);
      controller.configure(
        AgentToolRegistry(
          tools: const [],
          catalog: AgentToolPermissionCatalog(
            toolNames: ['interrogate_image'],
            descriptors: [descriptor],
          ),
          policy: agentPermissionPolicy(safeMode: false, fullAccess: false),
        ),
      );
      const call = ToolCallContent(
        id: 'read',
        name: 'interrogate_image',
        arguments: {
          'resource_ref': {'resourceId': 'library-image'},
        },
      );
      final assistant = AssistantMessage(
        content: [call],
        stopReason: StopReason.toolUse,
      );
      expect(
        await controller.beforeToolCall(
          BeforeToolCallContext(
            assistantMessage: assistant,
            toolCall: call,
            args: call.arguments,
            context: AgentContext(
              systemPrompt: '',
              messages: [assistant],
              tools: const [],
            ),
          ),
          null,
        ),
        isNull,
      );
      expect(controller.takeDecision('read'), AgentPermissionDecision.allow);
    },
  );
  group('AgentToolPermissionController billing decisions', () {
    test(
      'full access automatically allows an exact zero-cost submit',
      () async {
        AgentToolApprovalRequest? approval;
        final controller = _controller(
          mode: AgentAccessMode.allowWrite,
          estimate: 0,
          onApproval: (value) => approval = value,
        );

        final result = await controller.beforeToolCall(
          _context('zero-cost'),
          null,
        );

        expect(result, isNull);
        expect(approval, isNull);
      },
    );

    test('positive cost requires approval even with full access', () async {
      AgentToolApprovalRequest? approval;
      final controller = _controller(
        mode: AgentAccessMode.allowWrite,
        estimate: 4,
        onApproval: (value) => approval = value,
      );

      final pending = controller.beforeToolCall(_context('positive'), null);
      await Future<void>.delayed(Duration.zero);

      expect(approval?.estimatedAnlas, 4);
      expect(controller.resolveApproval('positive', true), isTrue);
      expect(await pending, isNull);
    });

    test('invalid negative estimate is blocked without approval', () async {
      AgentToolApprovalRequest? approval;
      final controller = _controller(
        mode: AgentAccessMode.allowWrite,
        estimate: -3,
        onApproval: (value) => approval = value,
      );

      final result = await controller.beforeToolCall(
        _context('invalid-cost'),
        null,
      );

      expect(result?.block, isTrue);
      expect(approval, isNull);
    });

    test('ask mode still asks for a zero-cost mutation', () async {
      AgentToolApprovalRequest? approval;
      final controller = _controller(
        mode: AgentAccessMode.askBeforeWrite,
        estimate: 0,
        onApproval: (value) => approval = value,
      );

      final pending = controller.beforeToolCall(_context('ask-zero'), null);
      await Future<void>.delayed(Duration.zero);

      expect(approval?.estimatedAnlas, 0);
      controller.resolveApproval('ask-zero', false);
      expect((await pending)?.block, isTrue);
    });

    test('safe mode blocks submit without presenting approval', () async {
      AgentToolApprovalRequest? approval;
      final controller = _controller(
        mode: AgentAccessMode.readOnly,
        estimate: 0,
        onApproval: (value) => approval = value,
      );

      final result = await controller.beforeToolCall(_context('blocked'), null);

      expect(result?.block, isTrue);
      expect(approval, isNull);
    });

    test('stale window response cannot resolve a newer approval', () async {
      final controller = _controller(
        mode: AgentAccessMode.allowWrite,
        estimate: 2,
        onApproval: (_) {},
      );
      final pending = controller.beforeToolCall(_context('current'), null);
      await Future<void>.delayed(Duration.zero);

      expect(controller.resolveApproval('stale', true), isFalse);
      var completed = false;
      unawaited(pending.then((_) => completed = true));
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);

      expect(controller.resolveApproval('current', false), isTrue);
      expect((await pending)?.block, isTrue);
    });
  });
}

AgentToolPermissionController _controller({
  required AgentAccessMode mode,
  required int? estimate,
  required void Function(AgentToolApprovalRequest?) onApproval,
}) {
  final descriptor = describeAgentToolPermission('submit_generation');
  final catalog = AgentToolPermissionCatalog(
    toolNames: const ['submit_generation'],
    descriptors: [descriptor],
  );
  final controller = AgentToolPermissionController(
    auditSink: MemoryAgentAuditSink(),
    estimateAnlas: (_, _) async => estimate,
    onApprovalChanged: onApproval,
    isMounted: () => true,
  );
  controller.configure(
    AgentToolRegistry(
      tools: const [],
      catalog: catalog,
      policy: AgentPermissionPolicy({descriptor.domain: mode}),
    ),
  );
  return controller;
}

BeforeToolCallContext _context(String id) {
  final toolCall = ToolCallContent(
    id: id,
    name: 'submit_generation',
    arguments: const {'preparation_id': 'prepared', 'confirmed': true},
  );
  final assistant = AssistantMessage(
    content: [toolCall],
    stopReason: StopReason.toolUse,
  );
  return BeforeToolCallContext(
    assistantMessage: assistant,
    toolCall: toolCall,
    args: toolCall.arguments,
    context: AgentContext(
      systemPrompt: '',
      messages: [assistant],
      tools: const [],
    ),
  );
}
