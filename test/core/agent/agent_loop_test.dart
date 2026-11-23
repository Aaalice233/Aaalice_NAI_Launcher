import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent.dart';
import 'package:nai_launcher/core/agent/agent_loop.dart';

/// 脚本化 StreamFn：按调用次序返回预置响应，记录收到的上下文。
class ScriptedStreamFn {
  ScriptedStreamFn(this._scripts);

  final List<ScriptedResponse> _scripts;
  final List<Context> receivedContexts = [];
  int callCount = 0;

  StreamFn get fn => (model, context, [options]) {
    receivedContexts.add(context);
    final index = callCount++;
    if (index >= _scripts.length) {
      return _messageStream(
        AssistantMessage(
          content: const [AssistantTextContent('out of script')],
          stopReason: StopReason.stop,
        ),
      );
    }
    return _scripts[index].emit();
  };
}

/// 一次脚本化响应：文本增量 + 可选工具调用 + 停止原因。
class ScriptedResponse {
  ScriptedResponse({
    this.textChunks = const [],
    this.toolCalls = const [],
    this.stopReason = StopReason.stop,
    this.usage,
  });

  final List<String> textChunks;
  final List<ToolCallContent> toolCalls;
  final StopReason stopReason;
  final Usage? usage;

  AssistantMessageEventStream emit() {
    final stream = EventStream<AssistantMessageEvent, AssistantMessage>();
    scheduleMicrotask(() {
      var partial = AssistantMessage(
        content: const [],
        stopReason: stopReason,
        usage: usage,
      );
      stream.push(AmStart(partial: partial));
      final contents = <AssistantContent>[];
      for (final chunk in textChunks) {
        contents.add(AssistantTextContent(chunk));
        partial = AssistantMessage(
          content: List.of(contents),
          stopReason: stopReason,
          usage: usage,
        );
        stream.push(
          AmTextDelta(partial: partial, delta: chunk, contentIndex: 0),
        );
      }
      for (final call in toolCalls) {
        contents.add(call);
        partial = AssistantMessage(
          content: List.of(contents),
          stopReason: stopReason,
          usage: usage,
        );
        stream.push(
          AmToolCallEnd(partial: partial, toolCall: call, contentIndex: 0),
        );
      }
      final finalMessage = AssistantMessage(
        content: List.of(contents),
        stopReason: stopReason,
        usage: usage,
      );
      stream.push(AmDone(partial: finalMessage));
      stream.end(finalMessage);
    });
    return stream;
  }
}

AssistantMessageEventStream _messageStream(AssistantMessage message) {
  final stream = EventStream<AssistantMessageEvent, AssistantMessage>();
  scheduleMicrotask(() {
    stream.push(AmStart(partial: message));
    stream.push(AmDone(partial: message));
    stream.end(message);
  });
  return stream;
}

/// 计数工具。
class CountingTool extends AgentTool {
  CountingTool(
    String name,
    this.results, {
    this.throwOnCall = false,
    this.returnIsError = false,
  }) : super(
         name: name,
         description: 'test tool',
         parameters: const {'type': 'object', 'properties': {}},
         label: name,
       );

  final List<String> results;
  final bool throwOnCall;
  final bool returnIsError;
  int calls = 0;

  @override
  Future<AgentToolResult> execute(
    String toolCallId,
    Map<String, dynamic> params, [
    AbortSignal? signal,
    AgentToolUpdateCallback? onUpdate,
  ]) async {
    calls++;
    if (throwOnCall) {
      throw StateError('tool $name exploded');
    }
    return AgentToolResult(
      content: [ToolResultTextContent(results[results.length - 1])],
      details: const {},
      isError: returnIsError,
    );
  }
}

const _testModel = Model(
  id: 'test-model',
  name: 'Test Model',
  api: 'test',
  provider: 'test',
);

void main() {
  group('agentLoop', () {
    test('forwards the live abort signal to the model transport', () async {
      final abort = AbortController();
      SimpleStreamOptions? received;
      final stream = agentLoop(
        [UserMessage.text('hi')],
        const AgentContext(systemPrompt: '', messages: [], tools: []),
        AgentLoopConfig(
          model: _testModel,
          convertToLlm: (messages) async => messages,
        ),
        abort.signal,
        (model, context, [options]) {
          received = options;
          abort.abort('transport cancellation');
          return _messageStream(
            AssistantMessage(content: const [], stopReason: StopReason.aborted),
          );
        },
      );
      await stream.stream.drain<void>();
      expect(received?.signal, same(abort.signal));
      expect(received?.signal?.aborted, isTrue);
      expect(
        (await stream.result()).last,
        isA<AssistantMessage>().having(
          (message) => message.stopReason,
          'stop reason',
          StopReason.aborted,
        ),
      );
    });

    test('simple text response: single turn, no tool calls', () async {
      final scripted = ScriptedStreamFn([
        ScriptedResponse(textChunks: ['hello', ' world']),
      ]);
      final events = <AgentEvent>[];

      final stream = agentLoop(
        [UserMessage.text('hi')],
        const AgentContext(systemPrompt: 'sys', messages: [], tools: []),
        AgentLoopConfig(
          model: _testModel,
          convertToLlm: (messages) async => messages,
        ),
        null,
        scripted.fn,
      );
      await for (final event in stream.stream) {
        events.add(event);
      }
      final result = await stream.result();

      expect(scripted.callCount, 1);
      expect(result.length, 2); // user + assistant
      expect(result.last, isA<AssistantMessage>());
      expect((result.last as AssistantMessage).text, 'hello world');

      final types = events.map((e) => e.runtimeType).toList();
      expect(types, contains(AgentEventAgentStart));
      expect(types, contains(AgentEventTurnStart));
      expect(types.where((t) => t == AgentEventTurnEnd).length, 1);
      expect(types.last, AgentEventAgentEnd);
    });

    test(
      'tool call round-trip: assistant calls tool, loop continues once',
      () async {
        final tool = CountingTool('get_state', ['{"ok":true}']);
        final scripted = ScriptedStreamFn([
          ScriptedResponse(
            textChunks: ['checking'],
            toolCalls: [
              const ToolCallContent(id: 'c1', name: 'get_state', arguments: {}),
            ],
            stopReason: StopReason.toolUse,
          ),
          ScriptedResponse(textChunks: ['done']),
        ]);

        final stream = agentLoop(
          [UserMessage.text('inspect')],
          AgentContext(systemPrompt: '', messages: const [], tools: [tool]),
          AgentLoopConfig(
            model: _testModel,
            convertToLlm: (messages) async => messages,
          ),
          null,
          scripted.fn,
        );
        await stream.stream.drain();
        final result = await stream.result();

        expect(tool.calls, 1);
        expect(scripted.callCount, 2);
        // 第二次调用时上下文应包含 toolResult
        final secondContext = scripted.receivedContexts[1];
        expect(secondContext.messages.whereType<ToolResultMessage>().length, 1);
        // 结果：user + assistant(toolCall) + toolResult + assistant
        expect(result.length, 4);
        expect((result.last as AssistantMessage).text, 'done');
      },
    );

    test('tool-returned failures remain error tool results', () async {
      final tool = CountingTool('validate', [
        'invalid input',
      ], returnIsError: true);
      final scripted = ScriptedStreamFn([
        ScriptedResponse(
          toolCalls: const [
            ToolCallContent(id: 'bad', name: 'validate', arguments: {}),
          ],
          stopReason: StopReason.toolUse,
        ),
        ScriptedResponse(textChunks: ['recovered']),
      ]);

      final stream = agentLoop(
        [UserMessage.text('go')],
        AgentContext(systemPrompt: '', messages: const [], tools: [tool]),
        AgentLoopConfig(
          model: _testModel,
          convertToLlm: (messages) async => messages,
        ),
        null,
        scripted.fn,
      );
      await stream.stream.drain();
      final result = await stream.result();

      final toolResult = result.whereType<ToolResultMessage>().single;
      expect(toolResult.isError, isTrue);
      expect(toolResult.text, 'invalid input');
    });

    test('length-truncated tool calls fail without executing', () async {
      final tool = CountingTool('never', ['']);
      final scripted = ScriptedStreamFn([
        ScriptedResponse(
          toolCalls: [
            const ToolCallContent(id: 'c1', name: 'never', arguments: {}),
          ],
          stopReason: StopReason.length,
        ),
        ScriptedResponse(textChunks: ['recovered']),
      ]);

      final stream = agentLoop(
        [UserMessage.text('go')],
        AgentContext(systemPrompt: '', messages: const [], tools: [tool]),
        AgentLoopConfig(
          model: _testModel,
          convertToLlm: (messages) async => messages,
        ),
        null,
        scripted.fn,
      );
      await stream.stream.drain();
      await stream.result();

      expect(tool.calls, 0, reason: 'truncated calls must not execute');
      // 下一轮上下文里 toolResult 是 isError=true
      final secondContext = scripted.receivedContexts[1];
      final results = secondContext.messages
          .whereType<ToolResultMessage>()
          .toList();
      expect(results.single.isError, true);
      expect(results.single.text, contains('not executed'));
    });

    test('unknown tool yields error tool result', () async {
      final scripted = ScriptedStreamFn([
        ScriptedResponse(
          toolCalls: [
            const ToolCallContent(id: 'c1', name: 'ghost', arguments: {}),
          ],
          stopReason: StopReason.toolUse,
        ),
        ScriptedResponse(textChunks: ['ok']),
      ]);

      final stream = agentLoop(
        [UserMessage.text('go')],
        const AgentContext(systemPrompt: '', messages: [], tools: []),
        AgentLoopConfig(
          model: _testModel,
          convertToLlm: (messages) async => messages,
        ),
        null,
        scripted.fn,
      );
      await stream.stream.drain();
      await stream.result();

      final secondContext = scripted.receivedContexts[1];
      final results = secondContext.messages
          .whereType<ToolResultMessage>()
          .toList();
      expect(results.single.isError, true);
      expect(results.single.text, contains('not found'));
    });

    test(
      'steering messages injected after tool batch, before next LLM call',
      () async {
        final tool = CountingTool('work', ['ok']);
        // drain 语义闭包（代理 契约：取走后清空）。
        var steeringQueue = <AgentMessage>[
          UserMessage.text('actually do it differently'),
        ];
        final scripted = ScriptedStreamFn([
          ScriptedResponse(
            toolCalls: [
              const ToolCallContent(id: 'c1', name: 'work', arguments: {}),
            ],
            stopReason: StopReason.toolUse,
          ),
          ScriptedResponse(textChunks: ['final']),
        ]);

        final stream = agentLoop(
          [UserMessage.text('start')],
          AgentContext(systemPrompt: '', messages: const [], tools: [tool]),
          AgentLoopConfig(
            model: _testModel,
            convertToLlm: (messages) async => messages,
            getSteeringMessages: () async {
              final drained = steeringQueue;
              steeringQueue = const [];
              return drained;
            },
          ),
          null,
          scripted.fn,
        );
        await stream.stream.drain();
        final result = await stream.result();

        // 第二次 LLM 调用的上下文：user + assistant + toolResult + steering
        final secondContext = scripted.receivedContexts[1];
        final users = secondContext.messages
            .whereType<UserMessage>()
            .map((m) => m.text)
            .toList();
        expect(users, ['start', 'actually do it differently']);
        // steering 消息计入 newMessages
        expect(
          result.whereType<UserMessage>().map((m) => m.text),
          contains('actually do it differently'),
        );
      },
    );

    test(
      'follow-up messages restart the loop after agent would stop',
      () async {
        var followUps = <AgentMessage>[UserMessage.text('and then?')];
        final scripted = ScriptedStreamFn([
          ScriptedResponse(textChunks: ['first']),
          ScriptedResponse(textChunks: ['second']),
        ]);

        final stream = agentLoop(
          [UserMessage.text('begin')],
          const AgentContext(systemPrompt: '', messages: [], tools: []),
          AgentLoopConfig(
            model: _testModel,
            convertToLlm: (messages) async => messages,
            getFollowUpMessages: () async {
              final drained = followUps;
              followUps = const [];
              return drained;
            },
          ),
          null,
          scripted.fn,
        );
        await stream.stream.drain();
        final result = await stream.result();

        expect(scripted.callCount, 2);
        expect(result.whereType<UserMessage>().length, 2);
        expect((result.last as AssistantMessage).text, 'second');
      },
    );

    test('error stopReason ends loop immediately', () async {
      final scripted = ScriptedStreamFn([
        ScriptedResponse(
          textChunks: [],
          stopReason: StopReason.error,
          usage: null,
        ),
      ]);
      var sawErrorMessage = false;

      final stream = agentLoop(
        [UserMessage.text('go')],
        const AgentContext(systemPrompt: '', messages: [], tools: []),
        AgentLoopConfig(
          model: _testModel,
          convertToLlm: (messages) async => messages,
        ),
        null,
        scripted.fn,
      );
      await for (final event in stream.stream) {
        if (event is AgentEventTurnEnd && event.message is AssistantMessage) {
          sawErrorMessage =
              (event.message as AssistantMessage).stopReason ==
              StopReason.error;
        }
      }
      final result = await stream.result();

      expect(scripted.callCount, 1);
      expect(sawErrorMessage, true);
      expect(result.length, 2);
    });
  });

  group('Agent', () {
    test('queued messages keep stable IDs when an earlier item is removed', () {
      final agent = Agent(
        AgentOptions(
          streamFn: ScriptedStreamFn([]).fn,
          initialModel: _testModel,
        ),
      );

      final firstId = agent.steer(UserMessage.text('first'));
      final secondId = agent.steer(UserMessage.text('second'));
      expect(firstId, isNot(secondId));

      expect(
        (agent.removeSteeringById(firstId) as UserMessage?)?.text,
        'first',
      );
      expect(agent.steeringQueue.single.id, secondId);
      expect(
        (agent.steeringQueue.single.message as UserMessage).text,
        'second',
      );
    });

    test('prompt streams events into state and transcript', () async {
      final scripted = ScriptedStreamFn([
        ScriptedResponse(textChunks: ['hi there']),
      ]);
      final agent = Agent(
        AgentOptions(
          streamFn: scripted.fn,
          initialSystemPrompt: 'sys',
          initialModel: _testModel,
        ),
      );

      await agent.prompt('hello');

      expect(agent.state.isStreaming, false);
      expect(agent.state.messages.length, 2);
      expect((agent.state.messages.last as AssistantMessage).text, 'hi there');
    });

    test(
      'steer queues message delivered mid-run; followUp after stop',
      () async {
        final tool = CountingTool('slow', ['ok']);
        final scripted = ScriptedStreamFn([
          ScriptedResponse(
            toolCalls: [
              const ToolCallContent(id: 'c1', name: 'slow', arguments: {}),
            ],
            stopReason: StopReason.toolUse,
          ),
          // steering 注入后的响应
          ScriptedResponse(textChunks: ['steered']),
        ]);
        final agent = Agent(
          AgentOptions(
            streamFn: scripted.fn,
            initialModel: _testModel,
            initialTools: [tool],
          ),
        );

        final running = agent.prompt('start');
        // prompt 已在运行：排队 steering。
        agent.steer(UserMessage.text('change direction'));
        await running;

        expect(scripted.callCount, 2);
        final texts = agent.state.messages
            .whereType<UserMessage>()
            .map((m) => m.text)
            .toList();
        expect(texts, ['start', 'change direction']);
        expect(agent.hasQueuedMessages(), false);
      },
    );

    test('prompt while running throws; steer is the escape hatch', () async {
      final scripted = ScriptedStreamFn([
        ScriptedResponse(textChunks: ['one']),
        ScriptedResponse(textChunks: ['two']),
      ]);
      final agent = Agent(
        AgentOptions(streamFn: scripted.fn, initialModel: _testModel),
      );

      final first = agent.prompt('a');
      expect(() => agent.prompt('b'), throwsStateError);
      await first;
    });

    test('abort mid-tool stops loop and keeps partial transcript', () async {
      final slowTool = DefinedSlowTool();
      final scripted = ScriptedStreamFn([
        ScriptedResponse(
          toolCalls: [
            const ToolCallContent(id: 'c1', name: 'slow', arguments: {}),
          ],
          stopReason: StopReason.toolUse,
        ),
      ]);
      final agent = Agent(
        AgentOptions(
          streamFn: scripted.fn,
          initialModel: _testModel,
          initialTools: [slowTool],
        ),
      );

      final running = agent.prompt('go');
      // 等工具真正开始执行再中止。
      await slowTool.startedCompleter.future;
      agent.abort();
      await running;

      expect(agent.state.isStreaming, false);
    });

    test('waitForIdle completes after an active run fully settles', () async {
      final slowTool = DefinedSlowTool();
      final scripted = ScriptedStreamFn([
        ScriptedResponse(
          toolCalls: const [
            ToolCallContent(id: 'c1', name: 'slow', arguments: {}),
          ],
          stopReason: StopReason.toolUse,
        ),
      ]);
      final agent = Agent(
        AgentOptions(
          streamFn: scripted.fn,
          initialModel: _testModel,
          initialTools: [slowTool],
        ),
      );

      final running = agent.prompt('go');
      await slowTool.startedCompleter.future;
      var becameIdle = false;
      final idle = agent.waitForIdle().then((_) => becameIdle = true);
      await Future<void>.delayed(Duration.zero);
      expect(becameIdle, isFalse);

      agent.abort();
      await idle.timeout(const Duration(seconds: 2));
      await running;
      expect(becameIdle, isTrue);
      expect(agent.state.isStreaming, isFalse);
    });

    test('turn update can explicitly clear reasoning', () {
      final config = AgentLoopConfig(
        model: _testModel,
        convertToLlm: (messages) async => messages,
        reasoning: 'high',
      );

      expect(config.copyWithWithTurnUpdate().reasoning, 'high');
      expect(
        config.copyWithWithTurnUpdate(clearReasoning: true).reasoning,
        isNull,
      );
    });

    test('continueRun rejects from assistant tail without queues', () async {
      final scripted = ScriptedStreamFn([
        ScriptedResponse(textChunks: ['answer']),
      ]);
      final agent = Agent(
        AgentOptions(streamFn: scripted.fn, initialModel: _testModel),
      );
      await agent.prompt('q');

      expect(agent.continueRun, throwsStateError);
    });

    test(
      'parallel tool batch executes all calls and emits results in order',
      () async {
        final toolA = CountingTool('tool_a', ['a']);
        final toolB = CountingTool('tool_b', ['b']);
        final scripted = ScriptedStreamFn([
          ScriptedResponse(
            toolCalls: [
              const ToolCallContent(id: 'c1', name: 'tool_a', arguments: {}),
              const ToolCallContent(id: 'c2', name: 'tool_b', arguments: {}),
            ],
            stopReason: StopReason.toolUse,
          ),
          ScriptedResponse(textChunks: ['both done']),
        ]);

        final stream = agentLoop(
          [UserMessage.text('go')],
          AgentContext(
            systemPrompt: '',
            messages: const [],
            tools: [toolA, toolB],
          ),
          AgentLoopConfig(
            model: _testModel,
            convertToLlm: (messages) async => messages,
          ),
          null,
          scripted.fn,
        );
        await stream.stream.drain();
        final result = await stream.result();

        expect(toolA.calls, 1);
        expect(toolB.calls, 1);
        final toolResults = result.whereType<ToolResultMessage>().toList();
        expect(toolResults.length, 2);
        expect(toolResults[0].toolName, 'tool_a');
        expect(toolResults[1].toolName, 'tool_b');
        expect(toolResults[0].durationMs, isNotNull);
        expect(toolResults[1].durationMs, isNotNull);
      },
    );

    test(
      'aborted sequential and parallel tool batches answer every tool call (#9986)',
      () async {
        for (final mode in ToolExecutionMode.values) {
          final abort = AbortController();
          var secondExecuted = false;
          final firstTool = _CallbackTool('first', (signal) async {
            abort.abort('cancelled');
            return AgentToolResult(
              content: const [ToolResultTextContent('first done')],
              details: const {},
            );
          });
          final secondTool = _CallbackTool('second', (signal) async {
            secondExecuted = true;
            return AgentToolResult(
              content: const [ToolResultTextContent('second done')],
              details: const {},
            );
          });
          final scripted = ScriptedStreamFn([
            ScriptedResponse(
              toolCalls: const [
                ToolCallContent(id: 'c1', name: 'first', arguments: {}),
                ToolCallContent(id: 'c2', name: 'second', arguments: {}),
              ],
              stopReason: StopReason.toolUse,
            ),
            ScriptedResponse(
              textChunks: const [],
              stopReason: StopReason.aborted,
            ),
          ]);

          final endEvents = <AgentEventToolExecutionEnd>[];
          final stream = agentLoop(
            [UserMessage.text('go')],
            AgentContext(
              systemPrompt: '',
              messages: const [],
              tools: [firstTool, secondTool],
            ),
            AgentLoopConfig(
              model: _testModel,
              convertToLlm: (messages) async => messages,
              toolExecution: mode,
            ),
            abort.signal,
            scripted.fn,
          );
          await for (final event in stream.stream) {
            if (event is AgentEventToolExecutionEnd) {
              endEvents.add(event);
            }
          }
          final result = await stream.result();
          final toolResults = result.whereType<ToolResultMessage>().toList();

          expect(toolResults.map((r) => r.toolCallId), ['c1', 'c2'], reason: mode.name);
          expect(endEvents.map((e) => e.toolCallId), containsAll(['c1', 'c2']));
          if (mode == ToolExecutionMode.sequential) {
            expect(secondExecuted, isFalse);
            expect(toolResults[1].isError, isTrue);
            expect(toolResults[1].text, 'Operation aborted');
            expect(toolResults[1].durationMs, isNull);
          }
          expect(toolResults[0].durationMs, isNotNull);
        }
      },
    );

    test(
      'stamps thinkingLevel on AssistantMessage and omits durationMs for unexecuted tools',
      () async {
        final scripted = ScriptedStreamFn([
          ScriptedResponse(
            toolCalls: const [
              ToolCallContent(id: 'missing', name: 'ghost', arguments: {}),
            ],
            stopReason: StopReason.toolUse,
          ),
          ScriptedResponse(textChunks: const ['done']),
        ]);

        final stream = agentLoop(
          [UserMessage.text('hi')],
          const AgentContext(systemPrompt: '', messages: [], tools: []),
          AgentLoopConfig(
            model: _testModel,
            convertToLlm: (messages) async => messages,
            reasoning: 'high',
          ),
          null,
          scripted.fn,
        );
        await stream.stream.drain<void>();
        final result = await stream.result();

        final assistants = result.whereType<AssistantMessage>().toList();
        expect(assistants, hasLength(2));
        expect(assistants.every((m) => m.thinkingLevel == 'high'), isTrue);

        final missingResult = result.whereType<ToolResultMessage>().single;
        expect(missingResult.isError, isTrue);
        expect(missingResult.durationMs, isNull);
      },
    );

    test(
      'finishTurn continue/end, prepareRequest, and prepareNextTurn follow Pi 1.6 lifecycle',
      () async {
        final order = <String>[];
        var turnNumber = 0;
        final scripted = ScriptedStreamFn([
          ScriptedResponse(textChunks: const ['first']),
          ScriptedResponse(textChunks: const ['second']),
          ScriptedResponse(textChunks: const ['never']),
        ]);

        final stream = agentLoop(
          [UserMessage.text('start')],
          const AgentContext(systemPrompt: '', messages: [], tools: []),
          AgentLoopConfig(
            model: _testModel,
            convertToLlm: (messages) async => messages,
            prepareRequest: (ctx, signal) async {
              order.add('prepareRequest:${ctx.thinkingLevel}');
              return null;
            },
            finishTurn: (ctx, signal) async {
              turnNumber++;
              order.add('finishTurn:$turnNumber');
              if (turnNumber == 1) {
                return const AgentTurnDecision.continueTurn();
              }
              return const AgentTurnDecision.end();
            },
            prepareNextTurn: (ctx) async {
              order.add('prepareNextTurn');
              return AgentLoopTurnUpdate(
                messages: [UserMessage.text('injected-by-prepare')],
                thinkingLevel: 'medium',
              );
            },
          ),
          null,
          scripted.fn,
        );
        await for (final event in stream.stream) {
          if (event is AgentEventTurnStart) order.add('turn_start');
          if (event is AgentEventTurnEnd) order.add('turn_end');
        }
        final result = await stream.result();

        expect(scripted.callCount, 2);
        expect(order, [
          'turn_start',
          'prepareRequest:off',
          'finishTurn:1',
          'turn_end',
          'prepareNextTurn',
          'turn_start',
          'prepareRequest:medium',
          'finishTurn:2',
          'turn_end',
        ]);
        expect(
          result.whereType<UserMessage>().map((m) => m.text),
          ['start', 'injected-by-prepare'],
        );
      },
    );

    test('Agent.peekQueuedMessages previews without draining queues', () {
      final agent = Agent(
        AgentOptions(
          streamFn: ScriptedStreamFn([]).fn,
          initialModel: _testModel,
        ),
      );
      expect(agent.peekQueuedMessages(), isEmpty);

      agent.followUp(UserMessage.text('follow'));
      expect(
        agent.peekQueuedMessages().whereType<UserMessage>().single.text,
        'follow',
      );
      expect(agent.hasQueuedMessages(), isTrue);

      agent.steer(UserMessage.text('steer'));
      expect(
        agent.peekQueuedMessages().whereType<UserMessage>().single.text,
        'steer',
      );
      expect(agent.queuedMessageCount, 2);
    });
  });
}

class _CallbackTool extends AgentTool {
  _CallbackTool(String name, this._run)
    : super(
        name: name,
        description: 'callback tool',
        parameters: const {'type': 'object', 'properties': {}},
        label: name,
      );

  final Future<AgentToolResult> Function(AbortSignal? signal) _run;

  @override
  Future<AgentToolResult> execute(
    String toolCallId,
    Map<String, dynamic> params, [
    AbortSignal? signal,
    AgentToolUpdateCallback? onUpdate,
  ]) => _run(signal);
}

/// 等待外部 abort 的慢工具。
class DefinedSlowTool extends AgentTool {
  DefinedSlowTool()
    : super(
        name: 'slow',
        description: 'waits for abort',
        parameters: const {'type': 'object', 'properties': {}},
        label: 'slow',
      );

  final Completer<void> startedCompleter = Completer<void>();

  @override
  Future<AgentToolResult> execute(
    String toolCallId,
    Map<String, dynamic> params, [
    AbortSignal? signal,
    AgentToolUpdateCallback? onUpdate,
  ]) async {
    if (!startedCompleter.isCompleted) {
      startedCompleter.complete();
    }
    // 模拟长任务：中止信号到达即抛出。
    final completer = Completer<void>();
    signal?.addListener((_) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Operation aborted'));
      }
    });
    await completer.future;
    return AgentToolResult(
      content: const [ToolResultTextContent('never')],
      details: const {},
    );
  }
}
