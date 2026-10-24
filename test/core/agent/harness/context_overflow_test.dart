import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/harness/context_overflow.dart';

AssistantMessage _error(String errorMessage, {String? provider}) =>
    AssistantMessage(
      content: const [],
      stopReason: StopReason.error,
      errorMessage: errorMessage,
      provider: provider,
    );

void main() {
  for (final errorMessage in [
    'prompt is too long: 213462 tokens > 200000 maximum',
    '413 {"error":{"type":"request_too_large","message":"Request exceeds the '
        'maximum size"}}',
    'Your input exceeds the context window of this model',
    "Requested token count exceeds the model's maximum context length of "
        '131072 tokens',
    "Input length (265330) exceeds model's maximum context length (262144).",
    'The input token count (1196265) exceeds the maximum number of tokens '
        'allowed (1048575)',
    "This model's maximum prompt length is 131072 but the request contains "
        '537812 tokens',
    'Please reduce the length of the messages or completion',
    "This endpoint's maximum context length is 128000 tokens. However, you "
        'requested about 140000 tokens',
    "The input (300000 tokens) is longer than the model's context length "
        '(262144 tokens).',
    'the request exceeds the available context size, try increasing it',
    'invalid params, context window exceeds limit',
    'Range of input length should be [1, 98304]',
    'prompt too long; exceeded max context length by 1200 tokens',
    'github-copilot API error (413): {"message":"failed to parse request"}',
  ]) {
    test('detects provider overflow: $errorMessage', () {
      expect(isContextOverflow(_error(errorMessage)), isTrue);
    });
  }

  for (final errorMessage in [
    'Throttling error: Too many tokens, please wait before trying again.',
    'rate limit reached: too many tokens per minute',
    'LLM request failed: HTTP 503: provider=Gateway: overloaded',
    'upstream body mentioned status 413 somewhere',
  ]) {
    test('ignores non-overflow failure: $errorMessage', () {
      expect(isContextOverflow(_error(errorMessage)), isFalse);
    });
  }

  test('bodyless 400 counts as overflow only for Cerebras', () {
    expect(
      isContextOverflow(
        _error('400 status code (no body)', provider: 'cerebras'),
      ),
      isTrue,
    );
    expect(isContextOverflow(_error('400 status code (no body)')), isFalse);
  });

  test('silent overflow needs input beyond the context window', () {
    final message = AssistantMessage(
      content: const [AssistantTextContent('ok')],
      stopReason: StopReason.stop,
      usage: const Usage(input: 900, cacheRead: 200),
    );
    expect(isContextOverflow(message, 1000), isTrue);
    expect(isContextOverflow(message, 2000), isFalse);
    expect(isContextOverflow(message), isFalse);
  });

  test('a zero-output length stop at a full window is overflow', () {
    AssistantMessage lengthStop({required int input, int output = 0}) =>
        AssistantMessage(
          content: const [],
          stopReason: StopReason.length,
          usage: Usage(input: input, output: output),
        );
    expect(isContextOverflow(lengthStop(input: 995), 1000), isTrue);
    expect(isContextOverflow(lengthStop(input: 900), 1000), isFalse);
    expect(isContextOverflow(lengthStop(input: 995, output: 4), 1000), isFalse);
  });
}
