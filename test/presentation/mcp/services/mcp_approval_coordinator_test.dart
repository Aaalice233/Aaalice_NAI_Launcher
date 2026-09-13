import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/audit/audit_sink.dart';
import 'package:nai_launcher/presentation/mcp/services/mcp_approval_coordinator.dart';

import '../mcp_test_tools.dart';

const _timeout = Duration(minutes: 5);

void main() {
  test('pending approval auto-declines at the timeout', () {
    fakeAsync((async) {
      final harness = _Harness();
      BeforeToolCallResult? outcome;
      var completed = false;

      harness.ask('call-1', 'codex').then((value) {
        outcome = value;
        completed = true;
      });
      async.flushMicrotasks();

      expect(harness.coordinator.current, isNotNull);
      expect(harness.coordinator.current!.clientLabel, 'codex');
      expect(harness.observed.last?.toolCallId, 'call-1');

      async.elapse(_timeout);
      async.flushMicrotasks();

      expect(completed, isTrue);
      expect(outcome?.block, isTrue);
      expect(harness.coordinator.current, isNull);
      expect(harness.observed.last, isNull);

      harness.coordinator.dispose();
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('resolving cancels the expiry timer', () {
    fakeAsync((async) {
      final harness = _Harness();
      BeforeToolCallResult? outcome;
      var completed = false;

      harness.ask('call-1', 'codex').then((value) {
        outcome = value;
        completed = true;
      });
      async.flushMicrotasks();

      expect(harness.coordinator.resolve('call-1', true), isTrue);
      async.flushMicrotasks();

      expect(completed, isTrue);
      expect(outcome, isNull);
      expect(harness.coordinator.current, isNull);
      expect(async.pendingTimers, isEmpty);

      harness.coordinator.dispose();
    });
  });

  test('resolving an unrelated call id keeps the request pending', () {
    fakeAsync((async) {
      final harness = _Harness();
      harness.ask('call-1', 'codex');
      async.flushMicrotasks();

      expect(harness.coordinator.resolve('call-2', true), isFalse);
      async.flushMicrotasks();

      expect(harness.coordinator.current?.toolCallId, 'call-1');

      harness.coordinator.dispose();
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('dispose leaves no pending timers', () {
    fakeAsync((async) {
      final harness = _Harness();
      harness.ask('call-1', 'codex');
      async.flushMicrotasks();

      expect(async.pendingTimers, isNotEmpty);
      harness.coordinator.dispose();

      expect(async.pendingTimers, isEmpty);
      expect(harness.coordinator.current, isNull);
    });
  });

  test('missing client label falls back to an empty label', () {
    fakeAsync((async) {
      final harness = _Harness();
      harness.ask('call-1', null);
      async.flushMicrotasks();

      expect(harness.coordinator.current!.clientLabel, isEmpty);

      harness.coordinator.dispose();
      expect(async.pendingTimers, isEmpty);
    });
  });
}

class _Harness {
  _Harness() {
    coordinator = McpApprovalCoordinator(
      auditSink: audit,
      estimateAnlas: (_, _) async => null,
      isMounted: () => true,
      timeout: _timeout,
    );
    coordinator.configure(fakeToolRegistry(tools));
    coordinator.changes.listen(observed.add);
  }

  final MemoryAgentAuditSink audit = MemoryAgentAuditSink();
  final List<AgentTool> tools = [FakeAgentTool(name: 'set_positive_prompt')];
  final List<McpApprovalRequest?> observed = [];
  late final McpApprovalCoordinator coordinator;

  Future<BeforeToolCallResult?> ask(String callId, String? clientLabel) {
    if (clientLabel != null) coordinator.bindClientLabel(callId, clientLabel);
    return coordinator.controller.beforeToolCall(
      fakeBeforeToolCallContext(
        callId: callId,
        toolName: 'set_positive_prompt',
        args: const {'value': 'sunset'},
        tools: tools,
      ),
      null,
    );
  }
}
