import 'abort_signal.dart';
import 'llm_types.dart';

export 'abort_signal.dart';
export 'event_stream.dart';
export 'llm_types.dart';

/// StreamFn：loop 调用 LLM 的唯一入口。
///
/// 契约：请求/模型/运行期失败不得抛出，必须以协议事件编码失败、并以
/// stopReason 为 error/aborted（含 errorMessage）的最终 AssistantMessage 结束。
typedef StreamFn =
    AssistantMessageEventStream Function(
      Model model,
      Context context, [
      SimpleStreamOptions? options,
    ]);

/// 单条助手消息内多个工具调用的执行模式。
enum ToolExecutionMode { sequential, parallel }

/// 队列消息在 drain 点的注入模式。
enum QueueMode { all, oneAtATime }

/// beforeToolCall 的返回：block 阻止执行，loop 发出错误工具结果代替。
class BeforeToolCallResult {
  const BeforeToolCallResult({this.block, this.reason, this.terminate});

  final bool? block;
  final String? reason;

  /// 批次内所有结果都 terminate=true 时提前结束本次运行。
  final bool? terminate;
}

/// afterToolCall 的部分覆盖：字段级整体替换，省略字段保留原值。
class AfterToolCallResult {
  const AfterToolCallResult({
    this.content,
    this.details,
    this.isError,
    this.usage,
    this.terminate,
  });

  final List<ToolResultContent>? content;
  final dynamic details;
  final bool? isError;
  final Usage? usage;
  final bool? terminate;
}

class BeforeToolCallContext {
  const BeforeToolCallContext({
    required this.assistantMessage,
    required this.toolCall,
    required this.args,
    required this.context,
  });

  final AssistantMessage assistantMessage;
  final ToolCallContent toolCall;
  final dynamic args;
  final AgentContext context;
}

class AfterToolCallContext {
  const AfterToolCallContext({
    required this.assistantMessage,
    required this.toolCall,
    required this.args,
    required this.result,
    required this.isError,
    required this.context,
  });

  final AssistantMessage assistantMessage;
  final ToolCallContent toolCall;
  final dynamic args;
  final AgentToolResult result;
  final bool isError;
  final AgentContext context;
}

class ShouldStopAfterTurnContext {
  const ShouldStopAfterTurnContext({
    required this.message,
    required this.toolResults,
    required this.context,
    required this.newMessages,
  });

  final AssistantMessage message;
  final List<ToolResultMessage> toolResults;
  final AgentContext context;
  final List<Message> newMessages;
}

typedef PrepareNextTurnContext = ShouldStopAfterTurnContext;

/// turn 间替换的运行时状态。
class AgentLoopTurnUpdate {
  const AgentLoopTurnUpdate({this.context, this.model, this.thinkingLevel});

  final AgentContext? context;
  final Model? model;
  final String? thinkingLevel;
}

/// Agent 消息（Message 联合的别名，含应用自定义 CustomMessage 子类）。
typedef AgentMessage = Message;

/// Loop 配置。
class AgentLoopConfig extends SimpleStreamOptions {
  const AgentLoopConfig({
    required this.model,
    required this.convertToLlm,
    super.apiKey,
    super.signal,
    super.sessionId,
    super.reasoning,
    super.maxRetryDelayMs,
    this.transformContext,
    this.getApiKey,
    this.shouldStopAfterTurn,
    this.prepareNextTurn,
    this.getSteeringMessages,
    this.getFollowUpMessages,
    this.toolExecution,
    this.beforeToolCall,
    this.afterToolCall,
  });

  final Model model;

  /// AgentMessage[] → LLM Message[]（每次 LLM 调用前执行；不得抛出）。
  final Future<List<Message>> Function(List<AgentMessage> messages)
  convertToLlm;

  /// convertToLlm 之前的 AgentMessage 级变换（裁剪/注入上下文；不得抛出）。
  final Future<List<AgentMessage>> Function(
    List<AgentMessage> messages,
    AbortSignal? signal,
  )?
  transformContext;

  /// 每次 LLM 调用前动态解析 API Key（短期 OAuth token 场景）。
  final Future<String?> Function(String provider)? getApiKey;

  /// turn_end 之后决定是否优雅停止（true → agent_end 并退出）。
  final Future<bool> Function(ShouldStopAfterTurnContext context)?
  shouldStopAfterTurn;

  /// turn_end 后、下一次请求前替换 context/model/thinking。
  final Future<AgentLoopTurnUpdate?> Function(PrepareNextTurnContext context)?
  prepareNextTurn;

  /// 当前助手 turn 的工具执行完毕后注入 steering 消息。
  final Future<List<AgentMessage>> Function()? getSteeringMessages;

  /// agent 即将停止时取 follow-up 消息继续。
  final Future<List<AgentMessage>> Function()? getFollowUpMessages;

  /// 工具执行模式，默认 parallel。
  final ToolExecutionMode? toolExecution;

  final Future<BeforeToolCallResult?> Function(
    BeforeToolCallContext context,
    AbortSignal? signal,
  )?
  beforeToolCall;

  final Future<AfterToolCallResult?> Function(
    AfterToolCallContext context,
    AbortSignal? signal,
  )?
  afterToolCall;

  @override
  AgentLoopConfig copyWith({String? apiKey, AbortSignal? signal}) {
    return AgentLoopConfig(
      model: model,
      convertToLlm: convertToLlm,
      apiKey: apiKey ?? this.apiKey,
      signal: signal ?? this.signal,
      sessionId: sessionId,
      reasoning: reasoning,
      maxRetryDelayMs: maxRetryDelayMs,
      transformContext: transformContext,
      getApiKey: getApiKey,
      shouldStopAfterTurn: shouldStopAfterTurn,
      prepareNextTurn: prepareNextTurn,
      getSteeringMessages: getSteeringMessages,
      getFollowUpMessages: getFollowUpMessages,
      toolExecution: toolExecution,
      beforeToolCall: beforeToolCall,
      afterToolCall: afterToolCall,
    );
  }

  /// prepareNextTurn 快照的合并。
  AgentLoopConfig copyWithWithTurnUpdate({
    Model? model,
    String? reasoning,
    bool clearReasoning = false,
  }) {
    return AgentLoopConfig(
      model: model ?? this.model,
      convertToLlm: convertToLlm,
      apiKey: apiKey,
      signal: signal,
      sessionId: sessionId,
      reasoning: clearReasoning ? null : reasoning ?? this.reasoning,
      maxRetryDelayMs: maxRetryDelayMs,
      transformContext: transformContext,
      getApiKey: getApiKey,
      shouldStopAfterTurn: shouldStopAfterTurn,
      prepareNextTurn: prepareNextTurn,
      getSteeringMessages: getSteeringMessages,
      getFollowUpMessages: getFollowUpMessages,
      toolExecution: toolExecution,
      beforeToolCall: beforeToolCall,
      afterToolCall: afterToolCall,
    );
  }
}

/// 思考级别。
enum ThinkingLevel { off, minimal, low, medium, high, xhigh, max }

/// 公开 agent 状态。
class AgentState {
  AgentState({
    required this.systemPrompt,
    required this.model,
    required this.thinkingLevel,
    required List<AgentTool> tools,
    required List<AgentMessage> messages,
  }) : _tools = List.of(tools),
       _messages = List.of(messages);

  String systemPrompt;
  Model model;
  ThinkingLevel thinkingLevel;

  final List<AgentTool> _tools;
  List<AgentTool> get tools => _tools;
  set tools(List<AgentTool> next) {
    _tools
      ..clear()
      ..addAll(next);
  }

  final List<AgentMessage> _messages;
  List<AgentMessage> get messages => _messages;
  set messages(List<AgentMessage> next) {
    _messages
      ..clear()
      ..addAll(next);
  }

  bool isStreaming = false;
  AgentMessage? streamingMessage;
  final Set<String> pendingToolCalls = {};
  String? errorMessage;
}

/// 工具执行结果。
class AgentToolResult {
  AgentToolResult({
    required this.content,
    required this.details,
    this.isError = false,
    this.usage,
    this.addedToolNames,
    this.terminate,
  });

  List<ToolResultContent> content;
  dynamic details;
  bool isError;
  Usage? usage;
  List<String>? addedToolNames;
  bool? terminate;
}

/// 工具流式更新回调（仅当前 execute 调用周期内有效）。
typedef AgentToolUpdateCallback = void Function(AgentToolResult partialResult);

/// Agent 运行时工具定义。
abstract class AgentTool extends Tool {
  const AgentTool({
    required super.name,
    required super.description,
    required super.parameters,
    required this.label,
  });

  /// UI 显示名。
  final String label;

  /// 参数校验前的兼容整流（必须返回符合 schema 的对象）。
  Map<String, dynamic> prepareArguments(Map<String, dynamic> args) => args;

  /// 执行工具调用；失败时抛出而非编码进 content。
  Future<AgentToolResult> execute(
    String toolCallId,
    Map<String, dynamic> params, [
    AbortSignal? signal,
    AgentToolUpdateCallback? onUpdate,
  ]);

  /// 单工具执行模式覆盖；省略时沿用 loop 默认。
  ToolExecutionMode? get executionMode => null;
}

/// 传给底层 loop 的上下文快照。
class AgentContext {
  const AgentContext({
    required this.systemPrompt,
    required this.messages,
    this.tools,
  });

  final String systemPrompt;
  final List<AgentMessage> messages;
  final List<AgentTool>? tools;
}

/// Agent 事件。
sealed class AgentEvent {
  const AgentEvent();
}

class AgentEventAgentStart extends AgentEvent {
  const AgentEventAgentStart();
}

class AgentEventAgentEnd extends AgentEvent {
  const AgentEventAgentEnd({required this.messages});

  final List<AgentMessage> messages;
}

class AgentEventTurnStart extends AgentEvent {
  const AgentEventTurnStart();
}

class AgentEventTurnEnd extends AgentEvent {
  const AgentEventTurnEnd({required this.message, required this.toolResults});

  final AgentMessage message;
  final List<ToolResultMessage> toolResults;
}

class AgentEventMessageStart extends AgentEvent {
  const AgentEventMessageStart({required this.message});

  final AgentMessage message;
}

class AgentEventMessageUpdate extends AgentEvent {
  const AgentEventMessageUpdate({
    required this.message,
    required this.assistantMessageEvent,
  });

  final AgentMessage message;
  final AssistantMessageEvent assistantMessageEvent;
}

class AgentEventMessageEnd extends AgentEvent {
  const AgentEventMessageEnd({required this.message});

  final AgentMessage message;
}

class AgentEventToolExecutionStart extends AgentEvent {
  const AgentEventToolExecutionStart({
    required this.toolCallId,
    required this.toolName,
    required this.args,
  });

  final String toolCallId;
  final String toolName;
  final dynamic args;
}

class AgentEventToolExecutionUpdate extends AgentEvent {
  const AgentEventToolExecutionUpdate({
    required this.toolCallId,
    required this.toolName,
    required this.args,
    required this.partialResult,
  });

  final String toolCallId;
  final String toolName;
  final dynamic args;
  final AgentToolResult partialResult;
}

class AgentEventToolExecutionEnd extends AgentEvent {
  const AgentEventToolExecutionEnd({
    required this.toolCallId,
    required this.toolName,
    required this.result,
    required this.isError,
  });

  final String toolCallId;
  final String toolName;
  final AgentToolResult result;
  final bool isError;
}
