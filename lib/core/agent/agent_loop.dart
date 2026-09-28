import 'agent_types.dart';
import 'validate_tool_arguments.dart';

/// Agent 循环（agent loop）：驱动"LLM 响应 → 工具执行 → 回填 → 继续"
/// 的核心引擎。
///
/// ## 来源
///
/// 本文件移植自开源项目 pi-agent-core（github.com/badlogic/pi-mono，现
/// earendil-works/pi 仓库）的 `packages/agent/src/agent-loop.ts`，以
/// Dart 等价语义重写。消息在循环全程保持 `AgentMessage` 形态，仅在
/// LLM 调用边界经 [AgentLoopConfig.convertToLlm] 转换为供应商可理解的
/// `Message[]`——这一"边界转换"设计与上游一致。
///
/// ## 与上游的差异（舍弃项）
///
/// - `StreamFn` 默认实现（上游 `stream-fn.ts` 的全局模型注册表回退）：
///   本项目无全局模型目录，LLM 调用入口由应用显式注入；
/// - 上游依赖的 Node 平台设施（`proxy.ts` 的 HTTP 代理 agent、
///   `node.ts` 入口）不在本包范围内，网络层由应用自行提供；
/// - `EventStream` 的辅助构造糖未移植，保留 push/end/result 主契约；
/// - 其余逻辑——双层循环结构、steering/follow-up 队列投递时机、turn
///   生命周期事件序列、顺序/并行两种工具执行模式、截断消息的工具调用
///   失败策略、部分响应的中止保留——均与上游逐行对应。
///
/// ## 结构总览
///
/// ```
/// agentLoop(prompts)                    入口：新 prompt 启动，返回事件流
///   └─ runAgentLoop                     发出 agent_start/turn_start，
///      └─ _runLoop                      双层循环主体
///         ├─ 内层 while                 工具调用 + steering 注入
///         │  ├─ _streamAssistantResponse 流式取一条助手消息
///         │  ├─ stopReason==error/aborted → 结束
///         │  ├─ 有工具调用 → _executeToolCalls（顺序或并行）
///         │  │  └─ stopReason==length → 全部置失败（参数可能被截断）
///         │  ├─ 发出 turn_end
///         │  └─ 轮询 getSteeringMessages → 有则注入后继续内层
///         └─ 外层 while                  agent 将停止时轮询
///            getFollowUpMessages → 非空则注入并续跑
/// ```

/// 事件汇：loop 产生的每个 [AgentEvent] 经此交付。
typedef AgentEventSink = Future<void> Function(AgentEvent event);

/// 以一批新的 prompt 消息启动 agent 循环。
///
/// prompt 会并入上下文并各自发出 `message_start`/`message_end` 事件。
/// 返回的事件流以 `agent_end` 收尾，其最终结果为本轮新增的全部消息。
EventStream<AgentEvent, List<AgentMessage>> agentLoop(
  List<AgentMessage> prompts,
  AgentContext context,
  AgentLoopConfig config,
  AbortSignal? signal,
  StreamFn streamFn,
) {
  final stream = createAgentStream();

  // 后台驱动完整循环；结束时把新增消息作为流的最终结果交付。
  runAgentLoop(
        prompts,
        context,
        config,
        (event) async {
          stream.push(event);
        },
        signal,
        streamFn,
      )
      .then((messages) {
        stream.end(messages);
      })
      .catchError((Object error) {
        stream.endError(error);
      });

  return stream;
}

/// 不添加新消息、直接从当前上下文继续 agent 循环。
///
/// 典型用途是重试：上下文中已有 user 消息或工具结果等待模型处理。
///
/// **重要**：上下文最后一条消息必须能经 `convertToLlm` 转换为 `user` 或
/// `toolResult` 消息，否则 LLM 供应商会拒绝请求。此处无法校验——
/// `convertToLlm` 每 turn 只会执行一次。
EventStream<AgentEvent, List<AgentMessage>> agentLoopContinue(
  AgentContext context,
  AgentLoopConfig config,
  AbortSignal? signal,
  StreamFn streamFn,
) {
  if (context.messages.isEmpty) {
    throw StateError('Cannot continue: no messages in context');
  }

  if (context.messages.last.role == 'assistant') {
    throw StateError('Cannot continue from message role: assistant');
  }

  final stream = createAgentStream();

  runAgentLoopContinue(
        context,
        config,
        (event) async {
          stream.push(event);
        },
        signal,
        streamFn,
      )
      .then((messages) {
        stream.end(messages);
      })
      .catchError((Object error) {
        stream.endError(error);
      });

  return stream;
}

/// 驱动一次完整运行（带新 prompt 的形态）。
///
/// 事件序列：agent_start → turn_start → 每条 prompt 的
/// message_start/message_end → 进入主循环。返回值 [newMessages]
/// 为本次运行新增的全部消息（prompt、助手响应、工具结果）。
Future<List<AgentMessage>> runAgentLoop(
  List<AgentMessage> prompts,
  AgentContext context,
  AgentLoopConfig config,
  AgentEventSink emit,
  AbortSignal? signal,
  StreamFn? streamFn,
) async {
  final newMessages = [...prompts];
  final currentContext = AgentContext(
    systemPrompt: context.systemPrompt,
    messages: [...context.messages, ...prompts],
    tools: context.tools,
  );

  await emit(const AgentEventAgentStart());
  await emit(const AgentEventTurnStart());
  for (final prompt in prompts) {
    await emit(AgentEventMessageStart(message: prompt));
    await emit(AgentEventMessageEnd(message: prompt));
  }

  await _runLoop(currentContext, newMessages, config, signal, emit, streamFn);
  return newMessages;
}

/// 驱动一次完整运行（从既有转录继续的形态），不追加 prompt。
///
/// 与 [runAgentLoop] 共享 [_runLoop]；区别仅在于不发出 prompt 的
/// message 事件、且 newMessages 只含循环新产生的消息。
Future<List<AgentMessage>> runAgentLoopContinue(
  AgentContext context,
  AgentLoopConfig config,
  AgentEventSink emit,
  AbortSignal? signal,
  StreamFn? streamFn,
) async {
  if (context.messages.isEmpty) {
    throw StateError('Cannot continue: no messages in context');
  }

  if (context.messages.last.role == 'assistant') {
    throw StateError('Cannot continue from message role: assistant');
  }

  final newMessages = <AgentMessage>[];
  final currentContext = AgentContext(
    systemPrompt: context.systemPrompt,
    messages: [...context.messages],
    tools: context.tools,
  );

  await emit(const AgentEventAgentStart());
  await emit(const AgentEventTurnStart());

  await _runLoop(currentContext, newMessages, config, signal, emit, streamFn);
  return newMessages;
}

/// 创建以 agent_end 为终止事件、新增消息列表为最终结果的事件流。
EventStream<AgentEvent, List<AgentMessage>> createAgentStream() {
  return EventStream<AgentEvent, List<AgentMessage>>();
}

/// agentLoop 与 agentLoopContinue 共享的主循环逻辑。
Future<void> _runLoop(
  AgentContext initialContext,
  List<AgentMessage> newMessages,
  AgentLoopConfig initialConfig,
  AbortSignal? signal,
  AgentEventSink emit,
  StreamFn? streamFunction,
) async {
  var currentContext = initialContext;
  var config = initialConfig;
  var firstTurn = true;
  // 起始即检查 steering（用户可能在等待期间输入）
  var pendingMessages =
      await config.getSteeringMessages?.call() ?? <AgentMessage>[];

  // 外层循环：agent 将停止时若有排队的 follow-up 消息则继续
  while (true) {
    var hasMoreToolCalls = true;

    // 内层循环：处理工具调用与 steering 消息
    while (hasMoreToolCalls || pendingMessages.isNotEmpty) {
      if (!firstTurn) {
        await emit(const AgentEventTurnStart());
      } else {
        firstTurn = false;
      }

      // 处理待注入消息（在下一次助手响应前插入）
      if (pendingMessages.isNotEmpty) {
        for (final message in pendingMessages) {
          await emit(AgentEventMessageStart(message: message));
          await emit(AgentEventMessageEnd(message: message));
          currentContext.messages.add(message);
          newMessages.add(message);
        }
        pendingMessages = [];
      }

      // 流式获取助手响应
      final message = await _streamAssistantResponse(
        currentContext,
        config,
        signal,
        emit,
        streamFunction ?? _defaultStreamFn,
      );
      newMessages.add(message);

      if (message.stopReason == StopReason.error ||
          message.stopReason == StopReason.aborted) {
        await emit(AgentEventTurnEnd(message: message, toolResults: const []));
        await emit(AgentEventAgentEnd(messages: newMessages));
        return;
      }

      // 检查工具调用
      final toolCalls = message.content.whereType<ToolCallContent>().toList();

      final toolResults = <ToolResultMessage>[];
      hasMoreToolCalls = false;
      if (toolCalls.isNotEmpty) {
        // "length" 停止意味着输出被 token 上限截断，消息中的每个工具调用
        // 都可能带被截断的参数。全部置为失败而不是执行可能损坏的调用。
        final executedToolBatch = message.stopReason == StopReason.length
            ? await _failToolCallsFromTruncatedMessage(toolCalls, emit)
            : await _executeToolCalls(
                currentContext,
                message,
                config,
                signal,
                emit,
              );
        toolResults.addAll(executedToolBatch.messages);
        hasMoreToolCalls = !executedToolBatch.terminate;

        for (final result in toolResults) {
          currentContext.messages.add(result);
          newMessages.add(result);
        }
      }

      await emit(AgentEventTurnEnd(message: message, toolResults: toolResults));

      final nextTurnContext = _PrepareNextTurnArgs(
        message: message,
        toolResults: toolResults,
        context: currentContext,
        newMessages: newMessages,
      );
      final nextTurnSnapshot = await config.prepareNextTurn?.call(
        nextTurnContext,
      );
      if (nextTurnSnapshot != null) {
        currentContext = nextTurnSnapshot.context ?? currentContext;
        config = config.copyWithWithTurnUpdate(
          model: nextTurnSnapshot.model ?? config.model,
          reasoning: nextTurnSnapshot.thinkingLevel == null
              ? config.reasoning
              : nextTurnSnapshot.thinkingLevel == 'off'
              ? null
              : nextTurnSnapshot.thinkingLevel,
          clearReasoning: nextTurnSnapshot.thinkingLevel == 'off',
        );
      }

      final shouldStop = await config.shouldStopAfterTurn?.call(
        _ShouldStopAfterTurnArgs(
          message: message,
          toolResults: toolResults,
          context: currentContext,
          newMessages: newMessages,
        ),
      );
      if (shouldStop == true) {
        await emit(AgentEventAgentEnd(messages: newMessages));
        return;
      }

      pendingMessages =
          await config.getSteeringMessages?.call() ?? <AgentMessage>[];
    }

    // Agent 将在此停止。检查 follow-up 消息。
    final followUpMessages =
        await config.getFollowUpMessages?.call() ?? <AgentMessage>[];
    if (followUpMessages.isNotEmpty) {
      // 设为 pending 交由内层循环处理
      pendingMessages = followUpMessages;
      continue;
    }

    // 没有更多消息，退出
    break;
  }

  await emit(AgentEventAgentEnd(messages: newMessages));
}

Never _defaultStreamFn(
  Model model,
  Context context, [
  SimpleStreamOptions? options,
]) {
  throw UnsupportedError('No stream function provided');
}

/// 从 LLM 流式获取一条助手响应。
/// 这里把 AgentMessage[] 转换为 LLM 的 Message[]。
Future<AssistantMessage> _streamAssistantResponse(
  AgentContext context,
  AgentLoopConfig config,
  AbortSignal? signal,
  AgentEventSink emit,
  StreamFn streamFunction,
) async {
  // 可选的上下文变换（AgentMessage[] → AgentMessage[]）
  var messages = context.messages;
  if (config.transformContext != null) {
    messages = await config.transformContext!(messages, signal);
  }

  // 转换为 LLM 兼容消息（AgentMessage[] → Message[]）
  final llmMessages = await config.convertToLlm(messages);

  // 构建 LLM 上下文
  final llmContext = Context(
    systemPrompt: context.systemPrompt,
    messages: llmMessages,
    tools: context.tools == null
        ? null
        : [
            for (final tool in context.tools!)
              Tool(
                name: tool.name,
                description: tool.description,
                parameters: tool.parameters,
              ),
          ],
  );

  // 解析 API Key（对会过期的 token 很重要）
  String? resolvedApiKey;
  if (config.getApiKey != null) {
    resolvedApiKey = await config.getApiKey!(config.model.provider);
  }
  resolvedApiKey = resolvedApiKey ?? config.apiKey;

  final response = streamFunction(
    config.model,
    llmContext,
    config.copyWith(apiKey: resolvedApiKey, signal: signal),
  );

  AssistantMessage? partialMessage;
  var addedPartial = false;

  await for (final event in response.stream) {
    if (event is AmStart) {
      partialMessage = event.partial;
      context.messages.add(partialMessage);
      addedPartial = true;
      await emit(AgentEventMessageStart(message: partialMessage.copyWith()));
    } else if (event is AmTextStart ||
        event is AmTextDelta ||
        event is AmTextEnd ||
        event is AmThinkingStart ||
        event is AmThinkingDelta ||
        event is AmThinkingEnd ||
        event is AmToolCallStart ||
        event is AmToolCallDelta ||
        event is AmToolCallEnd) {
      if (partialMessage != null) {
        partialMessage = event.partial;
        context.messages[context.messages.length - 1] = partialMessage;
        await emit(
          AgentEventMessageUpdate(
            message: partialMessage.copyWith(),
            assistantMessageEvent: event,
          ),
        );
      }
    } else if (event is AmDone || event is AmError) {
      final finalMessage = await response.result();
      if (addedPartial) {
        context.messages[context.messages.length - 1] = finalMessage;
      } else {
        context.messages.add(finalMessage);
      }
      if (!addedPartial) {
        await emit(AgentEventMessageStart(message: finalMessage));
      }
      await emit(AgentEventMessageEnd(message: finalMessage));
      return finalMessage;
    }
  }

  final finalMessage = await response.result();
  if (addedPartial) {
    context.messages[context.messages.length - 1] = finalMessage;
  } else {
    context.messages.add(finalMessage);
    await emit(AgentEventMessageStart(message: finalMessage));
  }
  await emit(AgentEventMessageEnd(message: finalMessage));
  return finalMessage;
}

/// 输出被 token 上限截断时，消息中的工具调用参数可能不完整：
/// 流式参数经尽力恢复的 JSON 解析后可能"看似合法但内容缺失"，
/// 全部报告为错误让模型重新发起，而不是执行。
Future<_ExecutedToolCallBatch> _failToolCallsFromTruncatedMessage(
  List<ToolCallContent> toolCalls,
  AgentEventSink emit,
) async {
  final messages = <ToolResultMessage>[];
  for (final toolCall in toolCalls) {
    await emit(
      AgentEventToolExecutionStart(
        toolCallId: toolCall.id,
        toolName: toolCall.name,
        args: toolCall.arguments,
      ),
    );
    final finalized = _FinalizedToolCallOutcome(
      toolCall: toolCall,
      result: _createErrorToolResult(
        'Tool call "${toolCall.name}" was not executed: the response hit the '
        'output token limit, so its arguments may be truncated. Re-issue the '
        'tool call with complete arguments.',
      ),
      isError: true,
    );
    await _emitToolExecutionEnd(finalized, emit);
    final toolResultMessage = _createToolResultMessage(finalized);
    await _emitToolResultMessage(toolResultMessage, emit);
    messages.add(toolResultMessage);
  }
  return _ExecutedToolCallBatch(messages: messages, terminate: false);
}

/// 执行一条助手消息中的工具调用。
Future<_ExecutedToolCallBatch> _executeToolCalls(
  AgentContext currentContext,
  AssistantMessage assistantMessage,
  AgentLoopConfig config,
  AbortSignal? signal,
  AgentEventSink emit,
) async {
  final toolCalls = assistantMessage.content
      .whereType<ToolCallContent>()
      .toList();
  final hasSequentialToolCall = toolCalls.any((tc) {
    final tool = currentContext.tools
        ?.where((t) => t.name == tc.name)
        .firstOrNull;
    return tool?.executionMode == ToolExecutionMode.sequential;
  });
  if (config.toolExecution == ToolExecutionMode.sequential ||
      hasSequentialToolCall) {
    return _executeToolCallsSequential(
      currentContext,
      assistantMessage,
      toolCalls,
      config,
      signal,
      emit,
    );
  }
  return _executeToolCallsParallel(
    currentContext,
    assistantMessage,
    toolCalls,
    config,
    signal,
    emit,
  );
}

class _ExecutedToolCallBatch {
  const _ExecutedToolCallBatch({
    required this.messages,
    required this.terminate,
  });

  final List<ToolResultMessage> messages;
  final bool terminate;
}

Future<_ExecutedToolCallBatch> _executeToolCallsSequential(
  AgentContext currentContext,
  AssistantMessage assistantMessage,
  List<ToolCallContent> toolCalls,
  AgentLoopConfig config,
  AbortSignal? signal,
  AgentEventSink emit,
) async {
  final finalizedCalls = <_FinalizedToolCallOutcome>[];
  final messages = <ToolResultMessage>[];

  for (final toolCall in toolCalls) {
    await emit(
      AgentEventToolExecutionStart(
        toolCallId: toolCall.id,
        toolName: toolCall.name,
        args: toolCall.arguments,
      ),
    );

    final preparation = await _prepareToolCall(
      currentContext,
      assistantMessage,
      toolCall,
      config,
      signal,
    );
    _FinalizedToolCallOutcome finalized;
    if (preparation is _ImmediateToolCallOutcome) {
      finalized = _FinalizedToolCallOutcome(
        toolCall: toolCall,
        result: preparation.result,
        isError: preparation.isError,
      );
    } else {
      final prepared = preparation as _PreparedToolCall;
      final executed = await _executePreparedToolCall(prepared, signal, emit);
      finalized = await _finalizeExecutedToolCall(
        currentContext,
        assistantMessage,
        prepared,
        executed,
        config,
        signal,
      );
    }

    await _emitToolExecutionEnd(finalized, emit);
    final toolResultMessage = _createToolResultMessage(finalized);
    await _emitToolResultMessage(toolResultMessage, emit);
    finalizedCalls.add(finalized);
    messages.add(toolResultMessage);

    if (signal?.aborted == true) {
      break;
    }
  }
  return _ExecutedToolCallBatch(
    messages: messages,
    terminate: _shouldTerminateToolBatch(finalizedCalls),
  );
}

Future<_ExecutedToolCallBatch> _executeToolCallsParallel(
  AgentContext currentContext,
  AssistantMessage assistantMessage,
  List<ToolCallContent> toolCalls,
  AgentLoopConfig config,
  AbortSignal? signal,
  AgentEventSink emit,
) async {
  final finalizedCalls = <_ParallelEntry>[];

  for (final toolCall in toolCalls) {
    await emit(
      AgentEventToolExecutionStart(
        toolCallId: toolCall.id,
        toolName: toolCall.name,
        args: toolCall.arguments,
      ),
    );

    final preparation = await _prepareToolCall(
      currentContext,
      assistantMessage,
      toolCall,
      config,
      signal,
    );
    if (preparation is _ImmediateToolCallOutcome) {
      final finalized = _FinalizedToolCallOutcome(
        toolCall: toolCall,
        result: preparation.result,
        isError: preparation.isError,
      );
      await _emitToolExecutionEnd(finalized, emit);
      finalizedCalls.add(_ParallelEntry.immediate(finalized));
      if (signal?.aborted == true) {
        break;
      }
      continue;
    }

    final prepared = preparation as _PreparedToolCall;
    finalizedCalls.add(
      _ParallelEntry.lazy(() async {
        final executed = await _executePreparedToolCall(prepared, signal, emit);
        final finalized = await _finalizeExecutedToolCall(
          currentContext,
          assistantMessage,
          prepared,
          executed,
          config,
          signal,
        );
        await _emitToolExecutionEnd(finalized, emit);
        return finalized;
      }),
    );
    if (signal?.aborted == true) {
      break;
    }
  }

  final orderedFinalizedCalls = await Future.wait(
    finalizedCalls.map((entry) => entry.resolve()),
  );
  final messages = <ToolResultMessage>[];
  for (final finalized in orderedFinalizedCalls) {
    final toolResultMessage = _createToolResultMessage(finalized);
    await _emitToolResultMessage(toolResultMessage, emit);
    messages.add(toolResultMessage);
  }

  return _ExecutedToolCallBatch(
    messages: messages,
    terminate: _shouldTerminateToolBatch(orderedFinalizedCalls),
  );
}

sealed class _ToolCallPreparation {
  const _ToolCallPreparation();
}

class _PreparedToolCall extends _ToolCallPreparation {
  const _PreparedToolCall({
    required this.toolCall,
    required this.tool,
    required this.args,
  });

  final ToolCallContent toolCall;
  final AgentTool tool;
  final Map<String, dynamic> args;
}

class _ImmediateToolCallOutcome extends _ToolCallPreparation {
  const _ImmediateToolCallOutcome({
    required this.result,
    required this.isError,
  });

  final AgentToolResult result;
  final bool isError;
}

class _ExecutedToolCallOutcome {
  const _ExecutedToolCallOutcome({required this.result, required this.isError});

  final AgentToolResult result;
  final bool isError;
}

class _FinalizedToolCallOutcome {
  const _FinalizedToolCallOutcome({
    required this.toolCall,
    required this.result,
    required this.isError,
  });

  final ToolCallContent toolCall;
  final AgentToolResult result;
  final bool isError;
}

sealed class _ParallelEntry {
  const _ParallelEntry();

  factory _ParallelEntry.immediate(_FinalizedToolCallOutcome outcome) =
      _ImmediateEntry;
  factory _ParallelEntry.lazy(
    Future<_FinalizedToolCallOutcome> Function() resolver,
  ) = _LazyEntry;

  Future<_FinalizedToolCallOutcome> resolve();
}

class _ImmediateEntry extends _ParallelEntry {
  const _ImmediateEntry(this.outcome);

  final _FinalizedToolCallOutcome outcome;

  @override
  Future<_FinalizedToolCallOutcome> resolve() async => outcome;
}

class _LazyEntry extends _ParallelEntry {
  const _LazyEntry(this.resolver);

  final Future<_FinalizedToolCallOutcome> Function() resolver;

  @override
  Future<_FinalizedToolCallOutcome> resolve() => resolver();
}

bool _shouldTerminateToolBatch(List<_FinalizedToolCallOutcome> finalizedCalls) {
  return finalizedCalls.isNotEmpty &&
      finalizedCalls.every((finalized) => finalized.result.terminate == true);
}

Future<_ToolCallPreparation> _prepareToolCall(
  AgentContext currentContext,
  AssistantMessage assistantMessage,
  ToolCallContent toolCall,
  AgentLoopConfig config,
  AbortSignal? signal,
) async {
  final tool = currentContext.tools
      ?.where((t) => t.name == toolCall.name)
      .firstOrNull;
  if (tool == null) {
    return _ImmediateToolCallOutcome(
      result: _createErrorToolResult('Tool ${toolCall.name} not found'),
      isError: true,
    );
  }

  try {
    final validatedArgs = validateToolArguments(tool, toolCall);
    if (config.beforeToolCall != null) {
      final beforeResult = await config.beforeToolCall!(
        BeforeToolCallContext(
          assistantMessage: assistantMessage,
          toolCall: toolCall,
          args: validatedArgs,
          context: currentContext,
        ),
        signal,
      );
      if (signal?.aborted == true) {
        return _ImmediateToolCallOutcome(
          result: _createErrorToolResult('Operation aborted'),
          isError: true,
        );
      }
      if (beforeResult?.block == true) {
        final result = _createErrorToolResult(
          beforeResult?.reason ?? 'Tool execution was blocked',
        );
        if (beforeResult?.terminate == true) {
          result.terminate = true;
        }
        return _ImmediateToolCallOutcome(result: result, isError: true);
      }
    }
    if (signal?.aborted == true) {
      return _ImmediateToolCallOutcome(
        result: _createErrorToolResult('Operation aborted'),
        isError: true,
      );
    }
    return _PreparedToolCall(
      toolCall: toolCall,
      tool: tool,
      args: validatedArgs,
    );
  } catch (error) {
    return _ImmediateToolCallOutcome(
      result: _createErrorToolResult(error.toString()),
      isError: true,
    );
  }
}

Future<_ExecutedToolCallOutcome> _executePreparedToolCall(
  _PreparedToolCall prepared,
  AbortSignal? signal,
  AgentEventSink emit,
) async {
  final updateEvents = <Future<void>>[];
  var acceptingUpdates = true;

  try {
    final result = await prepared.tool.execute(
      prepared.toolCall.id,
      prepared.args,
      signal,
      (partialResult) {
        if (!acceptingUpdates) return;
        updateEvents.add(() async {
          await emit(
            AgentEventToolExecutionUpdate(
              toolCallId: prepared.toolCall.id,
              toolName: prepared.toolCall.name,
              args: prepared.toolCall.arguments,
              partialResult: partialResult,
            ),
          );
        }());
      },
    );
    acceptingUpdates = false;
    await Future.wait(updateEvents);
    return _ExecutedToolCallOutcome(result: result, isError: result.isError);
  } catch (error) {
    acceptingUpdates = false;
    await Future.wait(updateEvents);
    return _ExecutedToolCallOutcome(
      result: _createErrorToolResult(error.toString()),
      isError: true,
    );
  } finally {
    acceptingUpdates = false;
  }
}

Future<_FinalizedToolCallOutcome> _finalizeExecutedToolCall(
  AgentContext currentContext,
  AssistantMessage assistantMessage,
  _PreparedToolCall prepared,
  _ExecutedToolCallOutcome executed,
  AgentLoopConfig config,
  AbortSignal? signal,
) async {
  var result = executed.result;
  var isError = executed.isError;

  if (config.afterToolCall != null) {
    try {
      final afterResult = await config.afterToolCall!(
        AfterToolCallContext(
          assistantMessage: assistantMessage,
          toolCall: prepared.toolCall,
          args: prepared.args,
          result: result,
          isError: isError,
          context: currentContext,
        ),
        signal,
      );
      if (afterResult != null) {
        isError = afterResult.isError ?? isError;
        result = AgentToolResult(
          content: afterResult.content ?? result.content,
          details: afterResult.details ?? result.details,
          isError: isError,
          usage: afterResult.usage ?? result.usage,
          terminate: afterResult.terminate ?? result.terminate,
          addedToolNames: result.addedToolNames,
        );
      }
    } catch (error) {
      result = _createErrorToolResult(error.toString());
      isError = true;
    }
  }

  return _FinalizedToolCallOutcome(
    toolCall: prepared.toolCall,
    result: result,
    isError: isError,
  );
}

AgentToolResult _createErrorToolResult(String message) {
  return AgentToolResult(
    content: [ToolResultTextContent(message)],
    details: <String, dynamic>{},
    isError: true,
  );
}

Future<void> _emitToolExecutionEnd(
  _FinalizedToolCallOutcome finalized,
  AgentEventSink emit,
) async {
  await emit(
    AgentEventToolExecutionEnd(
      toolCallId: finalized.toolCall.id,
      toolName: finalized.toolCall.name,
      result: finalized.result,
      isError: finalized.isError,
    ),
  );
}

ToolResultMessage _createToolResultMessage(
  _FinalizedToolCallOutcome finalized,
) {
  return ToolResultMessage(
    toolCallId: finalized.toolCall.id,
    toolName: finalized.toolCall.name,
    // 未类型化工具可能返回没有 content 的结果；归一化，避免 null 进入
    // 会话历史或 provider payload。
    content: finalized.result.content,
    details: finalized.result.details,
    usage: finalized.result.usage,
    addedToolNames: finalized.result.addedToolNames?.isNotEmpty == true
        ? finalized.result.addedToolNames
        : null,
    isError: finalized.isError,
    timestamp: DateTime.now().millisecondsSinceEpoch,
  );
}

Future<void> _emitToolResultMessage(
  ToolResultMessage toolResultMessage,
  AgentEventSink emit,
) async {
  await emit(AgentEventMessageStart(message: toolResultMessage));
  await emit(AgentEventMessageEnd(message: toolResultMessage));
}

class _PrepareNextTurnArgs extends PrepareNextTurnContext {
  const _PrepareNextTurnArgs({
    required super.message,
    required super.toolResults,
    required super.context,
    required super.newMessages,
  });
}

class _ShouldStopAfterTurnArgs extends ShouldStopAfterTurnContext {
  const _ShouldStopAfterTurnArgs({
    required super.message,
    required super.toolResults,
    required super.context,
    required super.newMessages,
  });
}
