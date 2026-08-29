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

  test('targets replacement signatures and preserves Gemini proofs', () async {
    final stream = agentWireEventStream(
      Stream<AgentWireEvent>.fromIterable(const [
        AgentWireThinkingDelta('reason', itemId: 'rs_1'),
        AgentWireTextDelta('answer'),
        AgentWireThinkingSignature(
          '{"id":"rs_1","encrypted_content":"secret"}',
          itemId: 'rs_1',
          replace: true,
        ),
        AgentWireTextSignature('text-sig'),
        AgentWireToolCallDone(
          id: 'call-1',
          name: 'tool',
          arguments: {},
          thoughtSignature: 'tool-sig',
        ),
        AgentWireFinish(stopReason: StopReason.toolUse),
      ]),
    );

    await stream.stream.toList();
    final result = await stream.result();

    expect(
      (result.content[0] as AssistantThinkingContent).signature,
      contains('encrypted_content'),
    );
    expect((result.content[1] as AssistantTextContent).signature, 'text-sig');
    expect((result.content[2] as ToolCallContent).thoughtSignature, 'tool-sig');
  });

  test(
    'keeps interleaved provider reasoning items in separate blocks',
    () async {
      final stream = agentWireEventStream(
        Stream<AgentWireEvent>.fromIterable(const [
          AgentWireThinkingDelta('a', itemId: 'reason-1'),
          AgentWireThinkingDelta('b', itemId: 'reason-2'),
          AgentWireThinkingDelta('c', itemId: 'reason-1'),
          AgentWireFinish(stopReason: StopReason.stop),
        ]),
      );

      final result = await stream.result();

      expect(result.content, [
        isA<AssistantThinkingContent>().having(
          (block) => block.thinking,
          'thinking',
          'ac',
        ),
        isA<AssistantThinkingContent>().having(
          (block) => block.thinking,
          'thinking',
          'b',
        ),
      ]);
    },
  );

  test('binds an early reasoning signature to its own provider item', () async {
    final stream = agentWireEventStream(
      Stream<AgentWireEvent>.fromIterable(const [
        AgentWireThinkingDelta('a', itemId: 'reason-1'),
        AgentWireThinkingSignature(
          'proof-2',
          itemId: 'reason-2',
          replace: true,
        ),
        AgentWireThinkingDelta('b', itemId: 'reason-2'),
        AgentWireFinish(stopReason: StopReason.stop),
      ]),
    );

    final result = await stream.result();

    expect(result.content, [
      isA<AssistantThinkingContent>().having(
        (block) => block.thinking,
        'thinking',
        'a',
      ),
      isA<AssistantThinkingContent>()
          .having((block) => block.thinking, 'thinking', 'b')
          .having((block) => block.signature, 'signature', 'proof-2'),
    ]);
  });

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
