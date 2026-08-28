import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_stream_bridge.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/agent_protocol.dart';

void main() {
  test(
    'preserves provider content order and reports exact block indexes',
    () async {
      final stream = agentWireEventStream(
        Stream<AgentWireEvent>.fromIterable(const [
          AgentWireThinkingDelta('inspect'),
          AgentWireThinkingSignature('signed-'),
          AgentWireThinkingSignature('inspect'),
          AgentWireTextDelta('partial'),
          AgentWireThinkingDelta('verify'),
          AgentWireToolCallDone(
            id: '1',
            name: 'read',
            arguments: {'path': 'a'},
          ),
          AgentWireFinish(stopReason: StopReason.toolUse),
        ]),
        provider: 'anthropic',
        model: 'claude-sonnet-4',
      );

      final events = await stream.stream.toList();
      final result = await stream.result();

      expect(result.content, [
        isA<AssistantThinkingContent>()
            .having((block) => block.thinking, 'thinking', 'inspect')
            .having((block) => block.signature, 'signature', 'signed-inspect'),
        isA<AssistantTextContent>().having(
          (block) => block.text,
          'text',
          'partial',
        ),
        isA<AssistantThinkingContent>().having(
          (block) => block.thinking,
          'thinking',
          'verify',
        ),
        isA<ToolCallContent>().having((block) => block.name, 'name', 'read'),
      ]);
      expect(
        events.whereType<AmThinkingDelta>().map((event) => event.contentIndex),
        [0, 2],
      );
      expect(events.whereType<AmTextDelta>().single.contentIndex, 1);
      expect(events.whereType<AmToolCallEnd>().single.contentIndex, 3);
      expect(result.provider, 'anthropic');
      expect(result.model, 'claude-sonnet-4');
    },
  );

  test('a stream without a terminal event settles as an error', () async {
    final stream = agentWireEventStream(
      Stream<AgentWireEvent>.fromIterable(const [
        AgentWireTextDelta('partial response'),
      ]),
      provider: 'openai',
      model: 'model',
    );

    final events = await stream.stream.toList();
    final result = await stream.result();

    expect(events.whereType<AmError>(), hasLength(1));
    expect(events.whereType<AmDone>(), isEmpty);
    expect(result.text, 'partial response');
    expect(result.stopReason, StopReason.error);
    expect(result.errorMessage, contains('terminal event'));
  });
}
