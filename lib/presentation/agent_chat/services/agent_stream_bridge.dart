import '../../../core/agent/agent_types.dart';
import '../../prompt_assistant/models/agent_protocol.dart' as wire;

/// 把适配器的线事件流（[wire.AgentWireEvent]）组装为 LLM 类型层 语义的
/// [AssistantMessageEventStream]——即 LLM 类型层 中 provider 流式实现
/// （如 stream-openai.ts）所做的工作：维护 partial 消息快照并发出
/// AssistantMessageEvent。
///
/// 契约：不抛出；失败编码为 stopReason=error/aborted
/// 且带 errorMessage 的最终 AssistantMessage。
AssistantMessageEventStream agentWireEventStream(
  Stream<wire.AgentWireEvent> wireEvents, {
  String? provider,
  String? model,
}) {
  final stream = EventStream<AssistantMessageEvent, AssistantMessage>();

  () async {
    final content = <AssistantContent>[];
    var stopReason = StopReason.stop;
    Usage? usage;
    String? errorMessage;
    var started = false;
    var sawFinish = false;
    final thinkingIndexes = <String, int>{};

    AssistantMessage finalMessage() {
      return _snapshot(
        content,
        stopReason,
        usage,
        errorMessage,
        provider: provider,
        model: model,
      );
    }

    void emitStart() {
      if (started) {
        return;
      }
      started = true;
      stream.push(AmStart(partial: finalMessage()));
    }

    try {
      await for (final event in wireEvents) {
        switch (event) {
          case wire.AgentWireThinkingDelta():
            emitStart();
            var index = event.itemId == null
                ? null
                : thinkingIndexes[event.itemId!];
            if (index != null && content[index] is AssistantThinkingContent) {
              final block = content[index] as AssistantThinkingContent;
              content[index] = AssistantThinkingContent(
                '${block.thinking}${event.delta}',
                signature: block.signature,
              );
            } else {
              if (event.itemId == null) {
                _appendThinking(content, event.delta);
              } else {
                content.add(AssistantThinkingContent(event.delta));
              }
              index = content.length - 1;
              if (event.itemId case final itemId?) {
                thinkingIndexes[itemId] = index;
              }
            }
            stream.push(
              AmThinkingDelta(
                partial: finalMessage(),
                delta: event.delta,
                contentIndex: index,
              ),
            );
          case wire.AgentWireThinkingSignature():
            if (event.signature.isEmpty) break;
            emitStart();
            var index = event.itemId == null
                ? null
                : thinkingIndexes[event.itemId!];
            if (index == null || content[index] is! AssistantThinkingContent) {
              final lastIndex = content.length - 1;
              if (event.itemId == null &&
                  lastIndex >= 0 &&
                  content[lastIndex] is AssistantThinkingContent) {
                index = lastIndex;
              } else {
                content.add(const AssistantThinkingContent(''));
                index = content.length - 1;
              }
              if (event.itemId case final itemId?) {
                thinkingIndexes[itemId] = index;
              }
            }
            final block = content[index] as AssistantThinkingContent;
            content[index] = AssistantThinkingContent(
              block.thinking,
              signature: event.replace
                  ? event.signature
                  : '${block.signature ?? ''}${event.signature}',
            );
          case wire.AgentWireTextSignature():
            final last = content.lastOrNull;
            if (last is AssistantTextContent && event.signature.isNotEmpty) {
              content[content.length - 1] = AssistantTextContent(
                last.text,
                signature: event.signature,
              );
            }
          case wire.AgentWireTextDelta():
            emitStart();
            _appendText(content, event.delta);
            stream.push(
              AmTextDelta(
                partial: finalMessage(),
                delta: event.delta,
                contentIndex: content.length - 1,
              ),
            );
          case wire.AgentWireToolCallDone():
            emitStart();
            final toolCall = ToolCallContent(
              id: event.id,
              name: event.name,
              arguments: event.arguments,
              thoughtSignature: event.thoughtSignature,
            );
            content.add(toolCall);
            stream.push(
              AmToolCallEnd(
                partial: finalMessage(),
                toolCall: toolCall,
                contentIndex: content.length - 1,
              ),
            );
          case wire.AgentWireFinish():
            sawFinish = true;
            stopReason = event.stopReason;
            usage = event.usage;
            emitStart();
            stream.push(AmDone(partial: finalMessage()));
          case wire.AgentWireError():
            sawFinish = true;
            if (event.message == 'aborted') {
              stopReason = StopReason.aborted;
            } else {
              stopReason = StopReason.error;
              errorMessage = event.message;
            }
            emitStart();
            stream.push(AmError(partial: finalMessage(), error: errorMessage));
        }
      }
      if (!sawFinish) {
        errorMessage = 'LLM stream ended before a terminal event.';
        stopReason = StopReason.error;
        emitStart();
        stream.push(AmError(partial: finalMessage(), error: errorMessage));
      }
      stream.end(finalMessage());
    } catch (error) {
      if (!started) {
        stream.push(
          AmStart(
            partial: AssistantMessage(
              content: const [],
              stopReason: StopReason.error,
              errorMessage: error.toString(),
              timestamp: DateTime.now().millisecondsSinceEpoch,
            ),
          ),
        );
      }
      errorMessage = error.toString();
      stopReason = StopReason.error;
      final failure = finalMessage();
      stream.push(AmError(partial: failure, error: errorMessage));
      stream.end(failure);
    }
  }();

  return stream;
}

AssistantMessage _snapshot(
  List<AssistantContent> content,
  StopReason stopReason,
  Usage? usage,
  String? errorMessage, {
  String? provider,
  String? model,
}) {
  return AssistantMessage(
    content: List.of(content),
    stopReason: stopReason,
    usage: usage,
    provider: provider,
    model: model,
    errorMessage: errorMessage,
    timestamp: DateTime.now().millisecondsSinceEpoch,
  );
}

void _appendThinking(List<AssistantContent> content, String delta) {
  final last = content.lastOrNull;
  if (last is AssistantThinkingContent) {
    content[content.length - 1] = AssistantThinkingContent(
      '${last.thinking}$delta',
      signature: last.signature,
    );
  } else {
    content.add(AssistantThinkingContent(delta));
  }
}

void _appendText(List<AssistantContent> content, String delta) {
  final last = content.lastOrNull;
  if (last is AssistantTextContent) {
    content[content.length - 1] = AssistantTextContent(
      '${last.text}$delta',
      signature: last.signature,
    );
  } else {
    content.add(AssistantTextContent(delta));
  }
}
