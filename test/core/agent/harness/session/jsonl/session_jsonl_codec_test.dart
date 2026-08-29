import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/harness/session/jsonl/session_jsonl_codec.dart';

void main() {
  test('round-trips ordered assistant thinking and text blocks', () {
    final message = AssistantMessage(
      content: const [
        AssistantThinkingContent('inspect', signature: 'signed-inspect'),
        AssistantTextContent('answer', signature: 'text-sig'),
        AssistantThinkingContent('verify'),
        ToolCallContent(
          id: 'call-1',
          name: 'tool',
          arguments: {},
          thoughtSignature: 'tool-sig',
        ),
      ],
      stopReason: StopReason.stop,
      provider: 'provider',
      model: 'model',
    );

    final restored = SessionJsonlCodec.decode(
      SessionJsonlCodec.encode(message),
    );

    expect(restored, isA<AssistantMessage>());
    expect((restored as AssistantMessage).content, [
      isA<AssistantThinkingContent>()
          .having((block) => block.thinking, 'thinking', 'inspect')
          .having((block) => block.signature, 'signature', 'signed-inspect'),
      isA<AssistantTextContent>()
          .having((block) => block.text, 'text', 'answer')
          .having((block) => block.signature, 'signature', 'text-sig'),
      isA<AssistantThinkingContent>().having(
        (block) => block.thinking,
        'thinking',
        'verify',
      ),
      isA<ToolCallContent>()
          .having((block) => block.name, 'name', 'tool')
          .having(
            (block) => block.thoughtSignature,
            'thoughtSignature',
            'tool-sig',
          ),
    ]);
    expect(restored.provider, 'provider');
    expect(restored.model, 'model');
  });

  test('round-trips generated image tool results', () {
    final message = ToolResultMessage(
      toolCallId: 'generate-1',
      toolName: 'generate_image',
      content: [
        const ToolResultTextContent('Generated'),
        const ToolResultImageContent(
          ImageContent(
            source: ImageSource.base64(
              mimeType: 'image/png',
              base64Data: 'AQID',
            ),
          ),
        ),
        const ToolResultImageContent(
          ImageContent(source: ImageSource.url(url: 'https://example/image')),
        ),
      ],
    );

    final restored = SessionJsonlCodec.decode(
      SessionJsonlCodec.encode(message),
    );

    expect(restored, isA<ToolResultMessage>());
    final blocks = (restored as ToolResultMessage).content;
    expect(blocks.whereType<ToolResultImageContent>(), hasLength(2));
    expect(
      blocks.whereType<ToolResultImageContent>().first.image.source.base64Data,
      'AQID',
    );
    expect(
      blocks.whereType<ToolResultImageContent>().last.image.source.url,
      'https://example/image',
    );
  });
}
