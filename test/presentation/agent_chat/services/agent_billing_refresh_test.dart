import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent.dart';
import 'package:nai_launcher/core/agent/audit/audit_sink.dart';
import 'package:nai_launcher/core/agent/permissions/permissions.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/queue/replication_task.dart';
import 'package:nai_launcher/data/models/queue/replication_task_generation_snapshot.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_state.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_prepared_anlas_estimator.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_tool_permission_controller.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_tool_registry_builder.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_preparation_runtime.dart';
import 'package:nai_launcher/presentation/agent_chat/services/image_upscale_toolbox.dart';
import 'package:nai_launcher/presentation/agent_chat/services/manual_inpaint_toolbox.dart';
import 'package:nai_launcher/presentation/agent_chat/services/queue_toolbox.dart';
import 'package:nai_launcher/presentation/providers/generation/image_workflow_controller.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/queue_execution_provider.dart';
import 'package:nai_launcher/presentation/providers/replication_queue_provider.dart';
import 'package:nai_launcher/presentation/providers/subscription_billing.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';

import '../../../helpers/app_bootstrap_effects_harness.dart';
import '../../../helpers/stale_opus_subscription.dart';

final _refProvider = Provider<Ref>((ref) => ref);

const _freeV5Request = ImageParams(
  prompt: 'quota',
  model: ImageModels.animeDiffusionV5Full,
  width: 832,
  height: 1216,
  steps: 28,
);

const _opusWithQuota = SubscriptionBillingView(
  isOpus: true,
  opusQuotaExhausted: false,
);

const _opusQuotaExhausted = SubscriptionBillingView(
  isOpus: true,
  opusQuotaExhausted: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('queue preparation', () {
    Future<(int, StaleOpusSubscription)> prepareQueue(
      StaleOpusRefreshOutcome outcome,
    ) async {
      final subscription = StaleOpusSubscription(outcome);
      final task = ReplicationTask.create(
        prompt: _freeV5Request.prompt,
        generationSnapshot: await ReplicationTaskGenerationSnapshot.encode(
          _freeV5Request,
          batchSize: 1,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          replicationQueueNotifierProvider.overrideWith(
            () => _SeededQueue([task]),
          ),
          queueExecutionNotifierProvider.overrideWith(_IdleQueueExecution.new),
          subscriptionNotifierProvider.overrideWith(() => subscription),
          imageWorkflowControllerProvider.overrideWith(_IdleWorkflow.new),
          generationParamsNotifierProvider.overrideWith(
            InertGenerationParamsNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);
      final toolbox = QueueToolbox(
        container.read(_refProvider),
        QueueControlRuntime(),
      );
      final result = await toolbox
          .tools()
          .firstWhere(
            (tool) => tool.name == 'prepare_generation_queue_execution',
          )
          .execute('prepare', {'action': 'start'});
      final prepared =
          jsonDecode(
                result.content.whereType<ToolResultTextContent>().single.text,
              )
              as Map<String, dynamic>;
      expect(prepared['ok'], isTrue, reason: '$prepared');
      return (prepared['estimated_anlas'] as int, subscription);
    }

    test('refreshes stale data first; an exhausted quota is charged', () async {
      final (estimate, subscription) = await prepareQueue(
        StaleOpusRefreshOutcome.quotaExhausted,
      );

      expect(subscription.billingChecks, 1);
      expect(estimate, greaterThan(0));
    });

    test('a failed refresh is charged instead of assumed free', () async {
      final (estimate, _) = await prepareQueue(StaleOpusRefreshOutcome.failed);

      expect(estimate, greaterThan(0));
    });

    test('verified data keeps the free estimate', () async {
      final (estimate, subscription) = await prepareQueue(
        StaleOpusRefreshOutcome.stillFresh,
      );

      expect(subscription.billingChecks, 1);
      expect(estimate, 0);
    });
  });

  group('agent approval of a free preparation', () {
    late Directory supportDirectory;

    setUp(() async {
      supportDirectory = await Directory.systemTemp.createTemp(
        'nai_agent_billing_refresh_',
      );
      addTearDown(() => supportDirectory.delete(recursive: true));
    });

    Future<(AgentToolApprovalRequest?, AgentPermissionDecision)> approve(
      String toolName,
      Map<String, dynamic> args, {
      required SubscriptionBillingView current,
      GenerationPreparationRuntime? generationRuntime,
      QueueControlRuntime? queueRuntime,
    }) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ref = container.read(_refProvider);
      var refreshes = 0;
      AgentToolApprovalRequest? approval;
      final descriptor = describeAgentToolPermission(toolName);
      final controller = AgentToolPermissionController(
        auditSink: MemoryAgentAuditSink(),
        estimateAnlas: (toolName, args) => estimatePreparedAnlas(
          toolName,
          args,
          generationRuntime:
              generationRuntime ?? GenerationPreparationRuntime(),
          queueRuntime: queueRuntime ?? QueueControlRuntime(),
          manualInpaintToolbox: ManualInpaintToolbox(
            ref,
            supportDirectory: supportDirectory,
          ),
          imageUpscaleToolbox: ImageUpscaleToolbox(ref),
          freshBilling: () async {
            refreshes++;
            return current;
          },
        ),
        describeFileTargets: (_, _) => const [],
        chargeConfirmThreshold: () => null,
        onApprovalChanged: (value) => approval = value,
        isMounted: () => true,
      );
      addTearDown(controller.dispose);
      controller.configure(
        AgentToolRegistry(
          tools: const [],
          catalog: AgentToolPermissionCatalog(
            toolNames: [toolName],
            descriptors: [descriptor],
          ),
          policy: AgentPermissionPolicy({
            descriptor.domain: AgentAccessMode.allowWrite,
            AgentPermissionDomain.file: AgentAccessMode.allowWrite,
          }, chargeApproval: AgentChargeApproval.confirmEach),
        ),
      );

      final pending = controller.beforeToolCall(
        _toolCallContext(toolName, args),
        null,
      );
      await pumpEventQueue();
      expect(refreshes, greaterThan(0));
      final requested = approval;
      if (requested != null) controller.resolveApproval(_toolCallId, false);
      await pending;
      return (requested, controller.takeDecision(_toolCallId));
    }

    Future<(AgentToolApprovalRequest?, AgentPermissionDecision)> approveSubmit(
      SubscriptionBillingView current,
    ) {
      final runtime = GenerationPreparationRuntime();
      final prepared = runtime.add(
        GenerationPreparation(
          kind: GenerationPreparationKind.generate,
          baseParams: _freeV5Request,
          params: _freeV5Request,
          batchSize: 1,
          count: 1,
          autoStart: true,
          estimatedAnlas: 0,
          billing: _opusWithQuota,
          arguments: const {'prompt': 'quota'},
        ),
      );
      return approve(
        'submit_generation',
        {'preparation_id': prepared.id, 'confirmed': true},
        current: current,
        generationRuntime: runtime,
      );
    }

    Future<(AgentToolApprovalRequest?, AgentPermissionDecision)> approveQueue(
      String toolName,
      SubscriptionBillingView current,
    ) {
      final runtime = QueueControlRuntime();
      final prepared = runtime.add(
        QueueControlPreparation(
          kind: toolName == 'resume_generation_queue'
              ? QueueControlPreparationKind.resume
              : QueueControlPreparationKind.start,
          taskIds: const ['task'],
          taskFingerprints: const ['fingerprint'],
          estimatedAnlas: 0,
          billing: _opusWithQuota,
        ),
      );
      return approve(
        toolName,
        {'queue_preparation_id': prepared.id},
        current: current,
        queueRuntime: runtime,
      );
    }

    test(
      'a quota exhausted since preparation asks to confirm the charge',
      () async {
        final (approval, _) = await approveSubmit(_opusQuotaExhausted);

        expect(approval, isNotNull);
        expect(approval!.estimatedAnlas, greaterThan(0));
      },
    );

    test('an unverified subscription asks to confirm the charge', () async {
      final (approval, _) = await approveSubmit(
        SubscriptionBillingView.unverified,
      );

      expect(approval?.estimatedAnlas, greaterThan(0));
    });

    test('an unchanged subscription is approved as free', () async {
      final (approval, decision) = await approveSubmit(_opusWithQuota);

      expect(approval, isNull);
      expect(decision, AgentPermissionDecision.allow);
    });

    for (final toolName in [
      'start_generation_queue',
      'resume_generation_queue',
    ]) {
      for (final current in [
        _opusQuotaExhausted,
        SubscriptionBillingView.unverified,
      ]) {
        test('$toolName after the subscription changed to $current asks to '
            'confirm at an unknown price', () async {
          final (approval, _) = await approveQueue(toolName, current);

          expect(approval, isNotNull);
          expect(approval!.estimatedAnlas, isNull);
        });
      }

      test(
        '$toolName with an unchanged subscription is approved as free',
        () async {
          final (approval, decision) = await approveQueue(
            toolName,
            _opusWithQuota,
          );

          expect(approval, isNull);
          expect(decision, AgentPermissionDecision.allow);
        },
      );
    }
  });
}

const _toolCallId = 'call';

BeforeToolCallContext _toolCallContext(
  String toolName,
  Map<String, dynamic> args,
) {
  final toolCall = ToolCallContent(
    id: _toolCallId,
    name: toolName,
    arguments: args,
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

class _SeededQueue extends ReplicationQueueNotifier {
  _SeededQueue(this.tasks);

  final List<ReplicationTask> tasks;

  @override
  ReplicationQueueState build() => ReplicationQueueState(tasks: tasks);
}

class _IdleQueueExecution extends QueueExecutionNotifier {
  @override
  QueueExecutionState build() => const QueueExecutionState();
}

class _IdleWorkflow extends ImageWorkflowController {
  @override
  ImageWorkflowState build() => const ImageWorkflowState();
}
