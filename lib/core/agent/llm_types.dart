import 'dart:convert';
import 'dart:typed_data';

import 'event_stream.dart';

/// LLM 消息与流式协议类型定义。
///
/// 包含 agent loop 与 Agent 类实际引用的最小类型面：消息联合、内容块、
/// 用量统计、工具/上下文/模型描述，以及流式助手事件。

// ---------------------------------------------------------------------------
// Content blocks
// ---------------------------------------------------------------------------

/// 助手消息内容块（文本/思考/工具调用）。
sealed class AssistantContent {
  const AssistantContent();
}

class AssistantTextContent extends AssistantContent {
  const AssistantTextContent(this.text, {this.signature});

  final String text;

  /// Provider proof attached to a visible text part (Gemini).
  final String? signature;
}

class AssistantThinkingContent extends AssistantContent {
  const AssistantThinkingContent(this.thinking, {this.signature});

  final String thinking;

  /// Provider proof required to replay signed reasoning blocks (Anthropic).
  final String? signature;
}

/// 助手消息里的工具调用块（AgentToolCall；属于 AssistantContent 联合）。
class ToolCallContent extends AssistantContent {
  const ToolCallContent({
    required this.id,
    required this.name,
    required this.arguments,
    this.thoughtSignature,
  });

  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  /// Provider proof attached to a function-call part (Gemini).
  final String? thoughtSignature;

  Map<String, dynamic> toJson() => {
    'type': 'toolCall',
    'id': id,
    'name': name,
    'arguments': arguments,
    if (thoughtSignature != null) 'thoughtSignature': thoughtSignature,
  };
}

/// 图片内容（用户消息附件或工具结果图片）。
class ImageContent {
  const ImageContent({required this.source});

  final ImageSource source;

  Map<String, dynamic> toJson() => {
    'type': 'image',
    'source': {
      'type': 'base64',
      'mediaType': source.mimeType,
      'data': source.base64Data,
    },
  };
}

class ImageSource {
  const ImageSource.base64({required this.mimeType, required this.base64Data})
    : url = null;

  const ImageSource.url({required this.url})
    : mimeType = null,
      base64Data = null;

  final String? mimeType;
  final String? base64Data;
  final String? url;

  Uint8List? get bytes {
    final data = base64Data;
    if (data == null) {
      return null;
    }
    try {
      return base64Decode(data);
    } catch (_) {
      return null;
    }
  }
}

// ---------------------------------------------------------------------------
// Usage / Cost
// ---------------------------------------------------------------------------

class Cost {
  const Cost({
    this.input = 0,
    this.output = 0,
    this.cacheRead = 0,
    this.cacheWrite = 0,
    this.total = 0,
  });

  final double input;
  final double output;
  final double cacheRead;
  final double cacheWrite;
  final double total;

  Map<String, dynamic> toJson() => {
    'input': input,
    'output': output,
    'cacheRead': cacheRead,
    'cacheWrite': cacheWrite,
    'total': total,
  };
}

class Usage {
  const Usage({
    this.input = 0,
    this.output = 0,
    this.cacheRead = 0,
    this.cacheWrite = 0,
    this.totalTokens = 0,
    this.cost = const Cost(),
  });

  final int input;
  final int output;
  final int cacheRead;
  final int cacheWrite;
  final int totalTokens;
  final Cost cost;

  static const empty = Usage();

  Usage operator +(Usage other) => Usage(
    input: input + other.input,
    output: output + other.output,
    cacheRead: cacheRead + other.cacheRead,
    cacheWrite: cacheWrite + other.cacheWrite,
    totalTokens: totalTokens + other.totalTokens,
    cost: Cost(
      input: cost.input + other.cost.input,
      output: cost.output + other.cost.output,
      cacheRead: cost.cacheRead + other.cost.cacheRead,
      cacheWrite: cost.cacheWrite + other.cost.cacheWrite,
      total: cost.total + other.cost.total,
    ),
  );

  Map<String, dynamic> toJson() => {
    'input': input,
    'output': output,
    'cacheRead': cacheRead,
    'cacheWrite': cacheWrite,
    'totalTokens': totalTokens,
    'cost': cost.toJson(),
  };
}

// ---------------------------------------------------------------------------
// Messages
// ---------------------------------------------------------------------------

/// 停止原因。
enum StopReason { stop, length, toolUse, error, aborted, pending, deferred }

StopReason stopReasonFromName(String? name) {
  switch (name) {
    case 'length':
      return StopReason.length;
    case 'toolUse':
    case 'tool_calls':
    case 'tool_use':
    case 'function_call':
      return StopReason.toolUse;
    case 'error':
      return StopReason.error;
    case 'aborted':
      return StopReason.aborted;
    case 'pending':
      return StopReason.pending;
    case 'deferred':
      return StopReason.deferred;
    default:
      return StopReason.stop;
  }
}

/// 用户消息内容块：文本或图片。
sealed class UserContent {
  const UserContent();
}

class UserTextContent extends UserContent {
  const UserTextContent(this.text);

  final String text;
}

class UserImageContent extends UserContent {
  const UserImageContent(this.image);

  final ImageContent image;
}

/// 消息联合（UserMessage | AssistantMessage | ToolResultMessage | CustomMessage）。
///
/// CustomMessage 对应 LLM 类型层 的 CustomAgentMessages declaration merging：
/// 应用通过继承 CustomMessage 注入自有消息类型（如 compaction summary），
/// 在 convertToLlm 中决定如何映射或过滤。
sealed class Message {
  const Message({required this.timestamp});

  final int timestamp;

  String get role;
}

class UserMessage extends Message {
  UserMessage({required this.content, int? timestamp})
    : super(timestamp: timestamp ?? _nowMs());

  UserMessage.text(String text, {int? timestamp})
    : content = [UserTextContent(text)],
      super(timestamp: timestamp ?? _nowMs());

  final List<UserContent> content;

  @override
  String get role => 'user';

  String get text =>
      content.whereType<UserTextContent>().map((c) => c.text).join();

  List<ImageContent> get images =>
      content.whereType<UserImageContent>().map((c) => c.image).toList();
}

int _nowMs() => DateTime.now().millisecondsSinceEpoch;

class AssistantMessage extends Message {
  AssistantMessage({
    required this.content,
    required this.stopReason,
    this.errorMessage,
    this.usage,
    this.provider,
    this.model,
    int? timestamp,
  }) : super(timestamp: timestamp ?? _nowMs());

  @override
  String get role => 'assistant';

  List<AssistantContent> content;

  StopReason stopReason;

  String? errorMessage;

  Usage? usage;

  /// 产生该消息的供应商标识。
  String? provider;

  String? model;

  String get text =>
      content.whereType<AssistantTextContent>().map((c) => c.text).join();

  List<ToolCallContent> get toolCalls =>
      content.whereType<ToolCallContent>().toList();

  AssistantMessage copyWith({
    List<AssistantContent>? content,
    StopReason? stopReason,
    String? errorMessage,
    Usage? usage,
    String? provider,
    String? model,
  }) {
    return AssistantMessage(
      content: content ?? this.content,
      stopReason: stopReason ?? this.stopReason,
      errorMessage: errorMessage ?? this.errorMessage,
      usage: usage ?? this.usage,
      provider: provider ?? this.provider,
      model: model ?? this.model,
      timestamp: timestamp,
    );
  }
}

/// 工具结果内容块：文本或图片。
sealed class ToolResultContent {
  const ToolResultContent();
}

class ToolResultTextContent extends ToolResultContent {
  const ToolResultTextContent(this.text);

  final String text;
}

class ToolResultImageContent extends ToolResultContent {
  const ToolResultImageContent(this.image);

  final ImageContent image;
}

class ToolResultMessage extends Message {
  ToolResultMessage({
    required this.toolCallId,
    required this.toolName,
    required this.content,
    this.details,
    this.usage,
    this.addedToolNames,
    this.isError = false,
    int? timestamp,
  }) : super(timestamp: timestamp ?? _nowMs());

  @override
  String get role => 'toolResult';

  final String toolCallId;
  final String toolName;
  List<ToolResultContent> content;
  dynamic details;
  Usage? usage;
  List<String>? addedToolNames;
  bool isError;

  String get text =>
      content.whereType<ToolResultTextContent>().map((c) => c.text).join();
}

/// 应用自定义消息开放基类。
abstract class CustomMessage extends Message {
  const CustomMessage({required super.timestamp});

  @override
  String get role => 'custom';
}

// ---------------------------------------------------------------------------
// Tool / Context / Model
// ---------------------------------------------------------------------------

/// 工具的线协议描述。
class Tool {
  const Tool({
    required this.name,
    required this.description,
    required this.parameters,
  });

  final String name;
  final String description;

  /// JSON Schema（typebox 生成物的等价 JSON 形态）。
  final Map<String, dynamic> parameters;
}

class Context {
  const Context({
    required this.systemPrompt,
    required this.messages,
    this.tools,
  });

  final String systemPrompt;
  final List<Message> messages;
  final List<Tool>? tools;
}

/// 模型描述。
class Model {
  const Model({
    required this.id,
    required this.name,
    required this.api,
    required this.provider,
    this.baseUrl = '',
    this.contextWindow = 0,
    this.maxTokens = 0,
    this.reasoning = false,
  });

  final String id;
  final String name;

  /// 协议标识（openai-chat-completions / anthropic-messages / ...）。
  final String api;
  final String provider;
  final String baseUrl;
  final int contextWindow;
  final int maxTokens;
  final bool reasoning;
}

// ---------------------------------------------------------------------------
// AssistantMessageEvent（流式协议事件）
// ---------------------------------------------------------------------------

/// 助手流式事件，
/// start / text_start / text_delta / text_end / thinking_* / toolcall_* /
/// done / error，均携带 partial 快照。
sealed class AssistantMessageEvent {
  const AssistantMessageEvent({required this.partial});

  final AssistantMessage partial;
}

class AmStart extends AssistantMessageEvent {
  const AmStart({required super.partial});
}

class AmTextStart extends AssistantMessageEvent {
  const AmTextStart({required super.partial, required this.contentIndex});
  final int contentIndex;
}

class AmTextDelta extends AssistantMessageEvent {
  const AmTextDelta({
    required super.partial,
    required this.delta,
    required this.contentIndex,
  });
  final String delta;
  final int contentIndex;
}

class AmTextEnd extends AssistantMessageEvent {
  const AmTextEnd({
    required super.partial,
    required this.content,
    required this.contentIndex,
  });
  final String content;
  final int contentIndex;
}

class AmThinkingStart extends AssistantMessageEvent {
  const AmThinkingStart({required super.partial, required this.contentIndex});
  final int contentIndex;
}

class AmThinkingDelta extends AssistantMessageEvent {
  const AmThinkingDelta({
    required super.partial,
    required this.delta,
    required this.contentIndex,
  });
  final String delta;
  final int contentIndex;
}

class AmThinkingEnd extends AssistantMessageEvent {
  const AmThinkingEnd({
    required super.partial,
    required this.content,
    required this.contentIndex,
  });
  final String content;
  final int contentIndex;
}

class AmToolCallStart extends AssistantMessageEvent {
  const AmToolCallStart({
    required super.partial,
    required this.contentIndex,
    required this.id,
    required this.toolName,
  });
  final int contentIndex;
  final String id;
  final String toolName;
}

class AmToolCallDelta extends AssistantMessageEvent {
  const AmToolCallDelta({
    required super.partial,
    required this.delta,
    required this.contentIndex,
  });
  final String delta;
  final int contentIndex;
}

class AmToolCallEnd extends AssistantMessageEvent {
  const AmToolCallEnd({
    required super.partial,
    required this.toolCall,
    required this.contentIndex,
  });
  final ToolCallContent toolCall;
  final int contentIndex;
}

class AmDone extends AssistantMessageEvent {
  const AmDone({required super.partial});
}

class AmError extends AssistantMessageEvent {
  const AmError({required super.partial, this.error});
  final String? error;
}

/// AssistantMessageEventStream 的别名形态。
typedef AssistantMessageEventStream =
    EventStream<AssistantMessageEvent, AssistantMessage>;

// ---------------------------------------------------------------------------
// 简化流选项
// ---------------------------------------------------------------------------

class SimpleStreamOptions {
  const SimpleStreamOptions({
    this.apiKey,
    this.signal,
    this.sessionId,
    this.reasoning,
    this.maxRetryDelayMs,
    this.maxTokens,
  });

  final String? apiKey;
  final dynamic signal;
  final String? sessionId;
  final String? reasoning;
  final int? maxRetryDelayMs;

  /// 请求的最大输出 token（compaction 摘要等场景使用）。
  final int? maxTokens;

  SimpleStreamOptions copyWith({String? apiKey}) {
    return SimpleStreamOptions(
      apiKey: apiKey ?? this.apiKey,
      signal: signal,
      sessionId: sessionId,
      reasoning: reasoning,
      maxRetryDelayMs: maxRetryDelayMs,
      maxTokens: maxTokens,
    );
  }
}
