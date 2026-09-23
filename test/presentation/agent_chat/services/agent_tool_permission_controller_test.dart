import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent.dart';
import 'package:nai_launcher/core/agent/audit/audit_sink.dart';
import 'package:nai_launcher/core/agent/permissions/permissions.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_state.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_prepared_file_targets.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_tool_permission_controller.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_preparation_runtime.dart';
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
        describeFileTargets: (_, _) => const [],
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
  test('full access runs destructive tools without approval', () async {
    final descriptor = describeAgentToolPermission('delete_fixed_tag');
    final controller = AgentToolPermissionController(
      auditSink: MemoryAgentAuditSink(),
      estimateAnlas: (_, _) async => throw StateError('Delete does not bill'),
      describeFileTargets: (_, _) => const [],
      onApprovalChanged: (_) => fail('Full access must not ask for deletes'),
      isMounted: () => true,
    );
    addTearDown(controller.dispose);
    controller.configure(
      AgentToolRegistry(
        tools: const [],
        catalog: AgentToolPermissionCatalog(
          toolNames: const ['delete_fixed_tag'],
          descriptors: [descriptor],
        ),
        policy: agentPermissionPolicy(safeMode: false, fullAccess: true),
      ),
    );
    const call = ToolCallContent(
      id: 'delete',
      name: 'delete_fixed_tag',
      arguments: {'id': 'tag-1'},
    );
    final assistant = AssistantMessage(
      content: [call],
      stopReason: StopReason.toolUse,
    );

    final result = await controller.beforeToolCall(
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
    );

    expect(result, isNull);
    expect(controller.takeDecision('delete'), AgentPermissionDecision.allow);
  });

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

    test('a prepared save path reaches the approval request', () async {
      final runtime = GenerationPreparationRuntime();
      final prepared = runtime.add(
        GenerationPreparation(
          kind: GenerationPreparationKind.generate,
          baseParams: const ImageParams(prompt: 'test'),
          params: const ImageParams(prompt: 'test'),
          batchSize: 1,
          count: 1,
          autoStart: false,
          estimatedAnlas: 0,
          arguments: const {'prompt': 'test'},
          savePath: r'D:\art\out.png',
        ),
      );
      AgentToolApprovalRequest? approval;
      final controller = _controller(
        mode: AgentAccessMode.askBeforeWrite,
        estimate: 0,
        onApproval: (value) => approval = value,
        describeFileTargets: (toolName, args) =>
            preparedFileTargets(toolName, args, generationRuntime: runtime),
      );

      final pending = controller.beforeToolCall(
        _context('ask-save', preparationId: prepared.id),
        null,
      );
      await Future<void>.delayed(Duration.zero);

      expect(approval?.fileTargets, [r'D:\art\out.png']);
      expect(controller.resolveApproval('ask-save', true), isTrue);
      expect(await pending, isNull);
      expect(controller.takeDecision('ask-save'), AgentPermissionDecision.ask);
    });

    test('full access writes a prepared save path without asking', () async {
      AgentToolApprovalRequest? approval;
      final controller = _controller(
        mode: AgentAccessMode.allowWrite,
        estimate: 0,
        onApproval: (value) => approval = value,
        describeFileTargets: (_, _) => const [r'D:\art\out.png'],
      );

      final result = await controller.beforeToolCall(
        _context('allow-save'),
        null,
      );

      expect(result, isNull);
      expect(approval, isNull);
      expect(
        controller.takeDecision('allow-save'),
        AgentPermissionDecision.allow,
      );
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

  group('AgentToolPermissionController.mergeDecisions', () {
    test('a blocked side blocks the merged decision', () {
      expect(
        AgentToolPermissionController.mergeDecisions(
          AgentPermissionDecision.confirmCharge,
          AgentPermissionDecision.block,
        ),
        AgentPermissionDecision.block,
      );
    });

    test('a charge confirmation outranks ask and allow', () {
      expect(
        AgentToolPermissionController.mergeDecisions(
          AgentPermissionDecision.confirmCharge,
          AgentPermissionDecision.ask,
        ),
        AgentPermissionDecision.confirmCharge,
      );
    });

    test('an ask outranks allow', () {
      expect(
        AgentToolPermissionController.mergeDecisions(
          AgentPermissionDecision.allow,
          AgentPermissionDecision.ask,
        ),
        AgentPermissionDecision.ask,
      );
    });

    test('allow survives only when both sides allow', () {
      expect(
        AgentToolPermissionController.mergeDecisions(
          AgentPermissionDecision.allow,
          AgentPermissionDecision.allow,
        ),
        AgentPermissionDecision.allow,
      );
    });
  });
}

AgentToolPermissionController _controller({
  required AgentAccessMode mode,
  required int? estimate,
  required void Function(AgentToolApprovalRequest?) onApproval,
  List<String> Function(String, Map<String, dynamic>)? describeFileTargets,
}) {
  final descriptor = describeAgentToolPermission('submit_generation');
  final catalog = AgentToolPermissionCatalog(
    toolNames: const ['submit_generation'],
    descriptors: [descriptor],
  );
  final controller = AgentToolPermissionController(
    auditSink: MemoryAgentAuditSink(),
    estimateAnlas: (_, _) async => estimate,
    describeFileTargets: describeFileTargets ?? ((_, _) => const []),
    onApprovalChanged: onApproval,
    isMounted: () => true,
  );
  controller.configure(
    AgentToolRegistry(
      tools: const [],
      catalog: catalog,
      policy: AgentPermissionPolicy({
        descriptor.domain: mode,
        AgentPermissionDomain.file: mode,
      }),
    ),
  );
  return controller;
}

BeforeToolCallContext _context(
  String id, {
  String preparationId = 'prepared',
}) {
  final toolCall = ToolCallContent(
    id: id,
    name: 'submit_generation',
    arguments: {'preparation_id': preparationId, 'confirmed': true},
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
