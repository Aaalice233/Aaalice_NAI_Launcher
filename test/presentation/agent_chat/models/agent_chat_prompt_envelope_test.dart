import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/harness/harness_messages.dart';
import 'package:nai_launcher/core/agent/llm_types.dart';
import 'package:nai_launcher/presentation/agent_chat/models/agent_chat_prompt_envelope.dart';

HarnessCustomMessage _envelope({
  required List<String> prefix,
  required String visible,
  Object? details,
}) => HarnessCustomMessage(
  customType: agentPromptEnvelopeType,
  display: true,
  blockContent: [
    for (final block in prefix) UserTextContent(block),
    UserTextContent(visible),
  ],
  details: details ?? {'visibleContentOffset': prefix.length},
  timestamp: 42,
);

void main() {
  test('a plain user message is visible as itself', () {
    final message = UserMessage.text('hello');
    expect(visibleUserMessage(message), same(message));
    expect(isVisualUserMessage(message), isTrue);
    expect(isAgentPromptEnvelope(message), isFalse);
  });

  test('hides one prefix block', () {
    final message = _envelope(prefix: ['resources'], visible: 'draw a cat');
    expect(visibleUserMessage(message)!.text, 'draw a cat');
    expect(isVisualUserMessage(message), isTrue);
  });

  test('hides a skill block stacked on top of resources', () {
    final message = _envelope(
      prefix: ['<skill>…</skill>', 'resources'],
      visible: '/art-prompt draw a cat',
    );
    expect(visibleUserMessage(message)!.text, '/art-prompt draw a cat');
  });

  test('falls back to one block for envelopes written before the field', () {
    final legacy = _envelope(
      prefix: ['resources'],
      visible: 'draw a cat',
      details: const {'references': <dynamic>[]},
    );
    expect(visibleUserMessage(legacy)!.text, 'draw a cat');
  });

  test('keeps the timestamp so turns stay ordered', () {
    final message = _envelope(prefix: ['resources'], visible: 'hi');
    expect(visibleUserMessage(message)!.timestamp, 42);
  });

  test('clamps an offset that outruns the content', () {
    const broken = HarnessCustomMessage(
      customType: agentPromptEnvelopeType,
      display: true,
      blockContent: [UserTextContent('only block')],
      details: {'visibleContentOffset': 9},
      timestamp: 1,
    );
    expect(visibleUserMessage(broken)!.content, isEmpty);
  });

  test('other custom messages are not user messages', () {
    const other = HarnessCustomMessage(
      customType: 'somethingElse',
      display: true,
      textContent: 'x',
      timestamp: 1,
    );
    expect(isVisualUserMessage(other), isFalse);
    expect(visibleUserMessage(other), isNull);
  });
}
