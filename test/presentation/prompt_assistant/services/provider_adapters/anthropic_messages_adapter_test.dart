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

  test('agent payload maps reasoning effort to a valid thinking budget', () {
    const adapter = AnthropicMessagesAdapter();
    final request = AgentChatRequest(
      sessionId: 'session',
      provider: const ProviderConfig(
        id: 'anthropic',
        name: 'Anthropic',
        protocol: ProviderProtocol.anthropicMessages,
        baseUrl: 'https://api.anthropic.com',
      ),
      model: 'claude-sonnet-4-20250514',
      systemPrompt: 'system',
      messages: [
        UserMessage(content: const [UserTextContent('hello')]),
      ],
      tools: const [],
      apiKey: 'key',
      reasoning: 'high',
      maxOutputTokens: 2048,
      modelMaxOutputTokens: 128000,
    );

    final payload = adapter.buildAgentPayload(request);

    expect(payload['thinking'], {
      'type': 'enabled',
      'budget_tokens': 16384,
      'display': 'summarized',
    });
    expect(payload['max_tokens'], 18432);
  });

  test('agent payload replays signed thinking blocks in content order', () {
    const adapter = AnthropicMessagesAdapter();
    final request = AgentChatRequest(
      sessionId: 'session',
      provider: const ProviderConfig(
        id: 'anthropic',
        name: 'Anthropic',
        protocol: ProviderProtocol.anthropicMessages,
        baseUrl: 'https://api.anthropic.com',
      ),
      model: 'claude-sonnet-4-20250514',
      systemPrompt: 'system',
      messages: [
        AssistantMessage(
          content: const [
            AssistantThinkingContent('reason', signature: 'signed-reason'),
            AssistantTextContent('before'),
            ToolCallContent(id: 'call-1', name: 'read', arguments: {}),
            AssistantTextContent('after'),
          ],
          stopReason: StopReason.toolUse,
        ),
      ],
      tools: const [],
      apiKey: 'key',
    );

    final payload = adapter.buildAgentPayload(request);
    final content = ((payload['messages'] as List).single as Map)['content'];

    expect(content, [
      {'type': 'thinking', 'thinking': 'reason', 'signature': 'signed-reason'},
      {'type': 'text', 'text': 'before'},
      {'type': 'tool_use', 'id': 'call-1', 'name': 'read', 'input': {}},
      {'type': 'text', 'text': 'after'},
    ]);
  });

  test('agent payload handles provider-specific empty thinking signatures', () {
    const adapter = AnthropicMessagesAdapter();
    AgentChatRequest request({required bool allowEmptySignature}) =>
        AgentChatRequest(
          sessionId: 'session',
          provider: const ProviderConfig(
            id: 'provider',
            name: 'Provider',
            protocol: ProviderProtocol.anthropicMessages,
            baseUrl: 'https://example.test',
          ),
          model: 'model',
          systemPrompt: 'system',
          messages: [
            AssistantMessage(
              content: const [AssistantThinkingContent('unsigned')],
              stopReason: StopReason.stop,
            ),
          ],
          tools: const [],
          apiKey: 'key',
          reasoningRequest: AgentReasoningRequest(
            api: AgentReasoningApi.anthropicAdaptive,
            enabled: true,
            allowEmptySignature: allowEmptySignature,
          ),
        );

    final compatible =
        ((adapter.buildAgentPayload(
                      request(allowEmptySignature: true),
                    )['messages']
                    as List)
                .single
            as Map)['content'];
    final strict =
        ((adapter.buildAgentPayload(
                      request(allowEmptySignature: false),
                    )['messages']
                    as List)
                .single
            as Map)['content'];

    expect(compatible, [
      {'type': 'thinking', 'thinking': 'unsigned', 'signature': ''},
    ]);
    expect(strict, [
      {'type': 'text', 'text': 'unsigned'},
    ]);
  });

  test('agent payload sends tool-result images back to the model', () {
    const adapter = AnthropicMessagesAdapter();
    final encoded = base64Encode([1, 2, 3]);
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
        ToolResultMessage(
          toolCallId: 'call-1',
          toolName: 'generate_image',
          content: [
            const ToolResultTextContent('{"ok":true}'),
            ToolResultImageContent(
              ImageContent(
                source: ImageSource.base64(
                  mimeType: 'image/png',
                  base64Data: encoded,
                ),
              ),
            ),
          ],
          isError: false,
        ),
      ],
      tools: const [],
      apiKey: 'key',
    );

    final content =
        ((adapter.buildAgentPayload(request)['messages'] as List).single
                as Map)['content']
            as List;
    final toolResult = content.single as Map;

    expect(toolResult['type'], 'tool_result');
    expect(toolResult['content'], [
      {'type': 'text', 'text': '{"ok":true}'},
      {
        'type': 'image',
        'source': {
          'type': 'base64',
          'media_type': 'image/png',
          'data': encoded,
        },
      },
    ]);
  });
}
