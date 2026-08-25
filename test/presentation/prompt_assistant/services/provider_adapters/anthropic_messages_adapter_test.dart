import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/agent_protocol.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/provider_adapters/anthropic_messages_adapter.dart';

void main() {
  test('agent payload includes every user image attachment', () {
    const adapter = AnthropicMessagesAdapter();
    final first = base64Encode([1, 2, 3]);
    final second = base64Encode([4, 5, 6]);
    final request = AgentChatRequest(
      sessionId: 'session',
      provider: const ProviderConfig(
        id: 'anthropic',
        name: 'Anthropic',
        protocol: ProviderProtocol.anthropicMessages,
        baseUrl: 'https://api.anthropic.com',
      ),
      model: 'claude-test',
      systemPrompt: 'system',
      messages: [
        UserMessage(
          content: [
            const UserTextContent('compare these'),
            UserImageContent(
              ImageContent(
                source: ImageSource.base64(
                  mimeType: 'image/png',
                  base64Data: first,
                ),
              ),
            ),
            UserImageContent(
              ImageContent(
                source: ImageSource.base64(
                  mimeType: 'image/jpeg',
                  base64Data: second,
                ),
              ),
            ),
          ],
        ),
      ],
      tools: const [],
      apiKey: 'key',
    );

    final payload = adapter.buildAgentPayload(request);
    final messages = payload['messages'] as List;
    final content = (messages.single as Map)['content'] as List;
    final images = content
        .cast<Map<String, dynamic>>()
        .where((block) => block['type'] == 'image')
        .toList();

    expect(images.length, 2);
    expect((images[0]['source'] as Map)['data'], first);
    expect((images[1]['source'] as Map)['data'], second);
    expect(content.last, {'type': 'text', 'text': 'compare these'});
  });
}
