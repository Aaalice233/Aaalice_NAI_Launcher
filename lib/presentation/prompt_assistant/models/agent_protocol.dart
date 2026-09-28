import 'dart:typed_data';

import '../../../core/agent/agent_types.dart';
import 'prompt_assistant_models.dart';

/// Agent 线协议类型（应用层适配）。
///
/// 消息、工具、用量等核心类型已 1:1 移植到 `core/agent`（对齐
/// pi-agent-core / pi-ai），本文件只保留适配器所需的请求封装、
/// 线事件与应用自定义消息。

/// Compaction 产生的上下文摘要（对齐 pi 会话层 summary 消息；
/// 经 convertToLlm 映射为普通用户消息进入 LLM 上下文）。
class AgentSummaryMessage extends CustomMessage {
  const AgentSummaryMessage({required this.summary, required super.timestamp});

  final String summary;
}

enum AgentReasoningApi {
  openAiResponses,
  openAiCompletions,
  deepSeek,
  openRouter,
  qwen,
  anthropicBudget,
  anthropicAdaptive,
  geminiBudget,
  geminiLevel,
  mistralPromptMode,
  mistralEffort,
}

/// A fully resolved provider-native reasoning request.
class AgentReasoningRequest {
  const AgentReasoningRequest({
    required this.api,
    required this.enabled,
    this.effort,
    this.budgetTokens,
    this.sendWhenDisabled = true,
    this.preserveReasoningContent = false,
    this.allowEmptySignature = false,
    this.alwaysIncludeEncryptedReasoning = false,
  });

  final AgentReasoningApi api;
  final bool enabled;
  final String? effort;
  final int? budgetTokens;

  /// Whether Pi sends an explicit provider-native disabled value. An explicit
  /// `off: null` mapping means the field must be omitted instead.
  final bool sendWhenDisabled;
  final bool preserveReasoningContent;
  final bool allowEmptySignature;
  final bool alwaysIncludeEncryptedReasoning;
}

/// Agent 请求：完整消息历史 + 工具集 + 系统提示词。
class AgentChatRequest {
  const AgentChatRequest({
    required this.sessionId,
    required this.provider,
    required this.model,
    required this.systemPrompt,
    required this.messages,
    required this.tools,
    required this.apiKey,
    this.maxOutputTokens,
    this.modelMaxOutputTokens,
    this.reasoning,
    this.reasoningRequest,
  });

  final String sessionId;
  final ProviderConfig provider;
  final String model;
  final String systemPrompt;
  final List<Message> messages;
  final List<Tool> tools;
  final String? apiKey;
  final int? maxOutputTokens;
  final int? modelMaxOutputTokens;

  int? get effectiveMaxOutputTokens {
    final modelLimit = modelMaxOutputTokens;
    final requested = maxOutputTokens;
    if (modelLimit == null || modelLimit <= 0) return requested;
    if (requested == null) return modelLimit;
    return requested < modelLimit ? requested : modelLimit;
  }

  /// Selected UI reasoning level. Null is retained for backwards-compatible
  /// callers and represents Off before model-specific request resolution.
  final String? reasoning;

  /// Provider-native request resolved from Pi's model registry contract.
  final AgentReasoningRequest? reasoningRequest;
}

/// 适配器流式输出的线事件。非流式适配器把完整结果拆成
/// 一次性 textDelta / toolCallDone / finish 序列，保持统一消费方式。
sealed class AgentWireEvent {
  const AgentWireEvent();
}

class AgentWireTextDelta extends AgentWireEvent {
  const AgentWireTextDelta(this.delta);

  final String delta;
}

/// Provider-returned reasoning/thinking text. This is never synthesized from
/// model activity or hidden chain-of-thought.
class AgentWireThinkingDelta extends AgentWireEvent {
  const AgentWireThinkingDelta(this.delta, {this.itemId});

  final String delta;
  final String? itemId;
}

/// Provider metadata for the active thinking block. It is persisted but never
/// rendered as model-authored reasoning text.
class AgentWireThinkingSignature extends AgentWireEvent {
  const AgentWireThinkingSignature(
    this.signature, {
    this.itemId,
    this.replace = false,
  });

  final String signature;
  final String? itemId;
  final bool replace;
}

/// Provider proof attached to the active visible text block (Gemini).
class AgentWireTextSignature extends AgentWireEvent {
  const AgentWireTextSignature(this.signature);

  final String signature;
}

class AgentWireToolCallDone extends AgentWireEvent {
  const AgentWireToolCallDone({
    required this.id,
    required this.name,
    required this.arguments,
    this.thoughtSignature,
  });

  final String id;
  final String name;
  final Map<String, dynamic> arguments;
  final String? thoughtSignature;
}

class AgentWireFinish extends AgentWireEvent {
  const AgentWireFinish({required this.stopReason, this.usage});

  final StopReason stopReason;
  final Usage? usage;
}

class AgentWireError extends AgentWireEvent {
  const AgentWireError(this.message, {this.transient = false});

  final String message;

  /// 瞬时错误（429/5xx/超时/overloaded），可重试。
  final bool transient;
}

/// 用户消息内联图片的便捷提取（适配器构造 payload 用）。
List<({Uint8List bytes, String mimeType})> inlineImagesOf(Message message) {
  if (message is! UserMessage) {
    return const [];
  }
  final images = <({Uint8List bytes, String mimeType})>[];
  for (final content in message.content) {
    if (content is UserImageContent) {
      final bytes = content.image.source.bytes;
      final mime = content.image.source.mimeType;
      if (bytes != null && mime != null) {
        images.add((bytes: bytes, mimeType: mime));
      }
    }
  }
  return images;
}

List<ImageContent> toolResultImagesOf(Message message) => [
  if (message is ToolResultMessage)
    for (final content in message.content)
      if (content is ToolResultImageContent) content.image,
];

String userTextOf(Message message) {
  if (message is UserMessage) {
    return message.text;
  }
  if (message is AgentSummaryMessage) {
    return message.summary;
  }
  return '';
}
