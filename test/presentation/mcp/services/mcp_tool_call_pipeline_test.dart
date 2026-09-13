import 'package:dart_mcp/server.dart' show CallToolResult, TextContent;
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/audit/audit_sink.dart';
import 'package:nai_launcher/presentation/mcp/services/mcp_approval_coordinator.dart';
import 'package:nai_launcher/presentation/mcp/services/mcp_tool_call_pipeline.dart';
import 'package:nai_launcher/core/mcp/mcp_tool_executor.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';

import '../mcp_test_tools.dart';

void main() {
  late _Harness harness;

  setUp(() => harness = _Harness());
  tearDown(() => harness.dispose());

  test('unknown tool fails without touching the permission gate', () async {
    final result = await harness.call('u1', 'no_such_tool');

    expect(result.isError, isTrue);
    expect(harness.auditIds, contains('u1.lookup'));
    expect(harness.coordinator.current, isNull);
  });

  test('invalid arguments fail before the permission gate', () async {
    final result = await harness.call(
      'x1',
      'set_positive_prompt',
      arguments: const {'unknown': 'field'},
    );

    expect(result.isError, isTrue);
    expect(harness.auditIds, contains('x1.validation'));
    expect(harness.executed, isEmpty);
    expect(harness.coordinator.current, isNull);
  });

  test('read tools run without approval while a write waits', () async {
    final write = harness.call('w1', 'set_positive_prompt');
    await pumpEventQueue();
    expect(harness.coordinator.current?.toolCallId, 'w1');
    expect(harness.executed, isEmpty);

    final read = await harness.call('r1', 'get_generation_settings');

    expect(read.isError, isNot(isTrue));
    expect(harness.executed, ['get_generation_settings']);
    expect(harness.coordinator.current?.toolCallId, 'w1');
    expect(harness.auditIds, containsAll(['r1.decision', 'r1.result']));

    harness.coordinator.resolve('w1', true);
    expect((await write).isError, isNot(isTrue));
    expect(harness.executed, ['get_generation_settings', 'set_positive_prompt']);
  });

  test('approved write executes and is audited', () async {
    final pending = harness.call('w1', 'set_positive_prompt');
    await pumpEventQueue();

    expect(harness.coordinator.current?.clientLabel, 'codex 1.0.0');
    harness.coordinator.resolve('w1', true);

    final result = await pending;
    expect(result.isError, isNot(isTrue));
    expect(_textOf(result), 'ok:set_positive_prompt');
    expect(
      harness.auditIds,
      containsAll(['w1.decision', 'w1.approval', 'w1.result']),
    );
  });

  test('declined write never executes', () async {
    final pending = harness.call('w1', 'set_positive_prompt');
    await pumpEventQueue();

    harness.coordinator.resolve('w1', false);

    final result = await pending;
    expect(result.isError, isTrue);
    expect(harness.executed, isEmpty);
  });

  test('expired approval declines instead of hanging', () async {
    final expiring = _Harness(timeout: const Duration(milliseconds: 40));
    addTearDown(expiring.dispose);

    final result = await expiring.call('w1', 'set_positive_prompt');

    expect(result.isError, isTrue);
    expect(expiring.executed, isEmpty);
    expect(expiring.coordinator.current, isNull);
  });

  test('client abort resolves the pending approval as declined', () async {
    final controller = AbortController();
    final pending = harness.call(
      'w1',
      'set_positive_prompt',
      signal: controller.signal,
    );
    await pumpEventQueue();
    expect(harness.coordinator.current?.toolCallId, 'w1');

    controller.abort();

    final result = await pending;
    expect(result.isError, isTrue);
    expect(harness.executed, isEmpty);
    expect(harness.coordinator.current, isNull);
  });

  test('a second write queues instead of cancelling the first', () async {
    final first = harness.call('w1', 'set_positive_prompt');
    await pumpEventQueue();
    final second = harness.call('w2', 'delete_fixed_tag');
    await pumpEventQueue();

    expect(harness.coordinator.current?.toolCallId, 'w1');

    harness.coordinator.resolve('w1', true);
    expect((await first).isError, isNot(isTrue));
    await pumpEventQueue();

    expect(harness.coordinator.current?.toolCallId, 'w2');
    harness.coordinator.resolve('w2', true);
    expect((await second).isError, isNot(isTrue));
    expect(harness.executed, ['set_positive_prompt', 'delete_fixed_tag']);
  });

  test('full access still confirms destructive and charged calls', () async {
    final full = _Harness(mode: AgentPermissionMode.fullAccess);
    addTearDown(full.dispose);

    final plain = await full.call('w1', 'set_positive_prompt');
    expect(plain.isError, isNot(isTrue));
    expect(full.coordinator.current, isNull);

    final destructive = full.call('w2', 'delete_fixed_tag');
    await pumpEventQueue();
    expect(full.coordinator.current?.toolCallId, 'w2');
    full.coordinator.resolve('w2', true);
    expect((await destructive).isError, isNot(isTrue));

    final charged = full.call(
      'w3',
      'generate_image',
      arguments: const {'preparation_id': 'prep-1'},
    );
    await pumpEventQueue();
    expect(full.coordinator.current?.toolCallId, 'w3');
    expect(full.coordinator.current?.request.estimatedAnlas, 24);
    full.coordinator.resolve('w3', false);
    expect((await charged).isError, isTrue);
  });

  test('tools reflect the currently built registry', () {
    expect(
      harness.executor.tools.map((tool) => tool.name),
      containsAll(['get_generation_settings', 'set_positive_prompt']),
    );
  });
}

String? _textOf(CallToolResult result) {
  final content = result.content;
  if (content.isEmpty || !content.first.isText) return null;
  return (content.first as TextContent).text;
}

class _Harness {
  _Harness({
    Duration timeout = const Duration(minutes: 5),
    AgentPermissionMode mode = AgentPermissionMode.askBeforeSensitiveActions,
  }) {
    tools = [
      FakeAgentTool(
        name: 'get_generation_settings',
        runner: _runner('get_generation_settings'),
      ),
      FakeAgentTool(
        name: 'set_positive_prompt',
        runner: _runner('set_positive_prompt'),
      ),
      FakeAgentTool(
        name: 'delete_fixed_tag',
        runner: _runner('delete_fixed_tag'),
      ),
      FakeAgentTool(
        name: 'generate_image',
        parameters: const {
          'type': 'object',
          'properties': {
            'preparation_id': {'type': 'string'},
          },
          'additionalProperties': false,
        },
        runner: _runner('generate_image'),
      ),
    ];
    coordinator = McpApprovalCoordinator(
      auditSink: audit,
      estimateAnlas: (_, args) async =>
          args['preparation_id'] is String ? 24 : null,
      isMounted: () => true,
      timeout: timeout,
    );
    coordinator.configure(fakeToolRegistry(tools, mode: mode));
    executor = LauncherMcpToolExecutor(
      registry: () => fakeToolRegistry(tools, mode: mode),
      approvals: coordinator,
      auditSink: audit,
    );
  }

  final MemoryAgentAuditSink audit = MemoryAgentAuditSink();
  final List<String> executed = [];
  late final List<AgentTool> tools;
  late final McpApprovalCoordinator coordinator;
  late final LauncherMcpToolExecutor executor;

  Iterable<String> get auditIds => audit.events.map((event) => event.id);

  FakeToolRunner _runner(String name) => (args, signal) async {
    executed.add(name);
    return AgentToolResult(
      content: [ToolResultTextContent('ok:$name')],
      details: null,
    );
  };

  Future<CallToolResult> call(
    String callId,
    String toolName, {
    Map<String, dynamic> arguments = const {},
    AbortSignal? signal,
  }) {
    return executor.call(
      McpToolCallRequest(
        sessionId: 'session-1',
        callId: callId,
        toolName: toolName,
        arguments: arguments,
        signal: signal ?? AbortController().signal,
        clientLabel: 'codex 1.0.0',
      ),
    );
  }

  void dispose() => coordinator.dispose();
}
