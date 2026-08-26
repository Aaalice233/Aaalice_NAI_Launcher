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
  Stream<wire.AgentWireEvent> wireEvents,
) {
  final stream = EventStream<AssistantMessageEvent, AssistantMessage>();

  () async {
    final text = StringBuffer();
    final toolCalls = <ToolCallContent>[];
    var stopReason = StopReason.stop;
    Usage? usage;
    String? errorMessage;
    var started = false;
    var sawFinish = false;

    void emitStart() {
      if (started) {
        return;
      }
      started = true;
      stream.push(
        AmStart(
          partial: _snapshot(text, toolCalls, stopReason, usage, errorMessage),
        ),
      );
    }

    AssistantMessage finalMessage() {
      return _snapshot(text, toolCalls, stopReason, usage, errorMessage);
    }

    try {
      await for (final event in wireEvents) {
        switch (event) {
          case wire.AgentWireTextDelta():
            emitStart();
            text.write(event.delta);
            stream.push(
              AmTextDelta(
                partial: _snapshot(
                  text,
                  toolCalls,
                  stopReason,
                  usage,
                  errorMessage,
                ),
                delta: event.delta,
                contentIndex: 0,
              ),
            );
          case wire.AgentWireToolCallDone():
            emitStart();
            toolCalls.add(
              ToolCallContent(
                id: event.id,
                name: event.name,
                arguments: event.arguments,
              ),
            );
            stream.push(
              AmToolCallEnd(
                partial: _snapshot(
                  text,
                  toolCalls,
                  stopReason,
                  usage,
                  errorMessage,
                ),
                toolCall: toolCalls.last,
                contentIndex: 1 + toolCalls.length,
              ),
            );
          case wire.AgentWireFinish():
            sawFinish = true;
            stopReason = event.stopReason;
            usage = event.usage;
            emitStart();
            stream.push(
              AmDone(
                partial: finalMessage(),
              ),
            );
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
        // 适配器未发 finish（异常截断）：按已有内容收尾。
        stopReason = errorMessage == null
            ? StopReason.stop
            : StopReason.error;
        emitStart();
        stream.push(AmDone(partial: finalMessage()));
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
  StringBuffer text,
  List<ToolCallContent> toolCalls,
  StopReason stopReason,
  Usage? usage,
  String? errorMessage,
) {
  return AssistantMessage(
    content: [
      if (text.isNotEmpty) AssistantTextContent(text.toString()),
      ...toolCalls,
    ],
    stopReason: stopReason,
    usage: usage,
    errorMessage: errorMessage,
    timestamp: DateTime.now().millisecondsSinceEpoch,
  );
}
