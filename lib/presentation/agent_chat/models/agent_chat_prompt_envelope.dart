import '../../../core/agent/harness/harness_messages.dart';
import '../../../core/agent/llm_types.dart';

/// 包裹用户消息的信封：前缀块只发给模型，界面与会话命名只看可见内容。
///
/// 常量值沿用最早的资源引用标签，改字符串会让已有会话丢失轮次边界。
const String agentPromptEnvelopeType = 'agentResourcePrompt';

/// 信封本体，用于读取 `details` 等只有信封才有的字段；其余消息返回 null。
HarnessCustomMessage? asAgentPromptEnvelope(Message message) =>
    message is HarnessCustomMessage &&
        message.customType == agentPromptEnvelopeType
    ? message
    : null;

bool isAgentPromptEnvelope(Message message) =>
    asAgentPromptEnvelope(message) != null;

/// 用户消息或信封，即时间线中占据一轮起点的消息。
bool isVisualUserMessage(Message message) =>
    message is UserMessage || isAgentPromptEnvelope(message);

/// 前缀块数量。早期信封只写了资源块且未持久化该字段，缺省按 1 读。
int agentPromptEnvelopeVisibleOffset(HarnessCustomMessage message) {
  final details = message.details;
  final raw = details is Map ? details['visibleContentOffset'] : null;
  final offset = raw is int ? raw : 1;
  if (offset < 0) return 0;
  final length = message.content.length;
  return offset > length ? length : offset;
}

/// 信封或用户消息 → 可见的用户消息；其余消息返回 null。
UserMessage? visibleUserMessage(Message message) {
  if (message is UserMessage) return message;
  if (message is! HarnessCustomMessage || !isAgentPromptEnvelope(message)) {
    return null;
  }
  return UserMessage(
    content: message.content
        .skip(agentPromptEnvelopeVisibleOffset(message))
        .toList(growable: false),
    timestamp: message.timestamp,
  );
}
