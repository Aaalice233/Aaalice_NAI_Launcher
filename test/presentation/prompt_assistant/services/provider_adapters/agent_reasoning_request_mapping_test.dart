import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/agent_protocol.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/provider_adapters/anthropic_messages_adapter.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/provider_adapters/gemini_generate_content_adapter.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/provider_adapters/openai_chat_completions_adapter.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/provider_adapters/openai_responses_adapter.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/provider_adapters/prompt_assistant_adapter.dart';

void main() {
  group('Pi provider-native reasoning request mapping', () {
    test('provider payloads use the effective Pi model output limit', () async {
      final responses = await _capture(
        const OpenAiResponsesAdapter(),
        _request(
          ProviderProtocol.openaiResponses,
          const AgentReasoningRequest(
            api: AgentReasoningApi.openAiResponses,
            enabled: true,
            effort: 'high',
          ),
          maxOutputTokens: 1,
          modelMaxOutputTokens: 8,
        ),
      );
      final chat = await _capture(
        const OpenAiChatCompletionsAdapter(),
        _request(
          ProviderProtocol.openaiChatCompletions,
          const AgentReasoningRequest(
            api: AgentReasoningApi.openAiCompletions,
            enabled: true,
            effort: 'high',
          ),
          modelMaxOutputTokens: 7000,
        ),
      );
      final gemini = await _capture(
        const GeminiGenerateContentAdapter(),
        _request(
          ProviderProtocol.geminiGenerateContent,
          const AgentReasoningRequest(
            api: AgentReasoningApi.geminiLevel,
            enabled: true,
            effort: 'HIGH',
          ),
          modelMaxOutputTokens: 6000,
        ),
      );

      expect(responses['max_output_tokens'], 16);
      expect(chat['max_completion_tokens'], 7000);
      expect((gemini['generationConfig'] as Map)['maxOutputTokens'], 6000);
    });

    test(
      'OpenAI and xAI Responses use nested effort and replay metadata',
      () async {
        final payload = await _capture(
          const OpenAiResponsesAdapter(),
          _request(
            ProviderProtocol.openaiResponses,
            const AgentReasoningRequest(
              api: AgentReasoningApi.openAiResponses,
              enabled: true,
              effort: 'xhigh',
            ),
          ),
        );

        expect(payload['reasoning'], {'effort': 'xhigh', 'summary': 'auto'});
        expect(payload['include'], ['reasoning.encrypted_content']);
      },
    );

    test(
      'xAI keeps encrypted reasoning replay enabled while effort is off',
      () async {
        final payload = await _capture(
          const OpenAiResponsesAdapter(),
          _request(
            ProviderProtocol.openaiResponses,
            const AgentReasoningRequest(
              api: AgentReasoningApi.openAiResponses,
              enabled: false,
              alwaysIncludeEncryptedReasoning: true,
            ),
          ),
        );

        expect(payload['reasoning'], {'effort': 'none', 'summary': 'auto'});
        expect(payload['include'], ['reasoning.encrypted_content']);
      },
    );

    test(
      'OpenRouter uses reasoning.effort instead of reasoning_effort',
      () async {
        final payload = await _capture(
          const OpenAiChatCompletionsAdapter(),
          _request(
            ProviderProtocol.openaiChatCompletions,
            const AgentReasoningRequest(
              api: AgentReasoningApi.openRouter,
              enabled: true,
              effort: 'high',
            ),
          ),
        );

        expect(payload['reasoning'], {'effort': 'high'});
        expect(payload, isNot(contains('reasoning_effort')));
      },
    );

    test(
      'DeepSeek toggles thinking without inventing unsupported effort',
      () async {
        final payload = await _capture(
          const OpenAiChatCompletionsAdapter(),
          _request(
            ProviderProtocol.openaiChatCompletions,
            const AgentReasoningRequest(
              api: AgentReasoningApi.deepSeek,
              enabled: true,
            ),
          ),
        );

        expect(payload['thinking'], {'type': 'enabled'});
        expect(payload['max_tokens'], 128000);
        expect(payload, isNot(contains('max_completion_tokens')));
        expect(payload, isNot(contains('reasoning_effort')));
      },
    );

    test('Qwen sends enable_thinking and its mapped effort', () async {
      final payload = await _capture(
        const OpenAiChatCompletionsAdapter(),
        _request(
          ProviderProtocol.openaiChatCompletions,
          const AgentReasoningRequest(
            api: AgentReasoningApi.qwen,
            enabled: true,
            effort: 'max',
          ),
        ),
      );

      expect(payload['enable_thinking'], isTrue);
      expect(payload['reasoning_effort'], 'max');
      expect(payload['max_completion_tokens'], 128000);
    });

    test('Groq Cerebras and Kimi K3 use OpenAI-compatible effort', () async {
      final payload = await _capture(
        const OpenAiChatCompletionsAdapter(),
        _request(
          ProviderProtocol.openaiChatCompletions,
          const AgentReasoningRequest(
            api: AgentReasoningApi.openAiCompletions,
            enabled: true,
            effort: 'high',
          ),
        ),
      );

      expect(payload['reasoning_effort'], 'high');
      expect(payload, isNot(contains('thinking')));
    });

    test('Mistral separates prompt mode from effort models', () async {
      final promptMode = await _capture(
        const OpenAiChatCompletionsAdapter(),
        _request(
          ProviderProtocol.openaiChatCompletions,
          const AgentReasoningRequest(
            api: AgentReasoningApi.mistralPromptMode,
            enabled: true,
          ),
        ),
      );
      final effort = await _capture(
        const OpenAiChatCompletionsAdapter(),
        _request(
          ProviderProtocol.openaiChatCompletions,
          const AgentReasoningRequest(
            api: AgentReasoningApi.mistralEffort,
            enabled: true,
            effort: 'high',
          ),
        ),
      );

      expect(promptMode['prompt_mode'], 'reasoning');
      expect(promptMode, isNot(contains('reasoning_effort')));
      expect(effort['reasoning_effort'], 'high');
      expect(effort, isNot(contains('prompt_mode')));

      final replay = await _capture(
        const OpenAiChatCompletionsAdapter(),
        _request(
          ProviderProtocol.openaiChatCompletions,
          const AgentReasoningRequest(
            api: AgentReasoningApi.mistralPromptMode,
            enabled: true,
          ),
          messages: [
            AssistantMessage(
              content: const [
                AssistantThinkingContent('reason'),
                AssistantTextContent('answer'),
              ],
              stopReason: StopReason.stop,
            ),
          ],
        ),
      );
      final assistant = (replay['messages'] as List).last as Map;
      expect(assistant['content'], [
        {
          'type': 'thinking',
          'thinking': [
            {'type': 'text', 'text': 'reason'},
          ],
        },
        {'type': 'text', 'text': 'answer'},
      ]);
    });

    test(
      'Anthropic and MiniMax budget thinking uses Pi token budgets',
      () async {
        final payload = await _capture(
          const AnthropicMessagesAdapter(),
          _request(
            ProviderProtocol.anthropicMessages,
            const AgentReasoningRequest(
              api: AgentReasoningApi.anthropicBudget,
              enabled: true,
              budgetTokens: 8192,
            ),
            maxOutputTokens: 4096,
          ),
        );

        expect(payload['thinking'], {
          'type': 'enabled',
          'budget_tokens': 8192,
          'display': 'summarized',
        });
        expect(payload['max_tokens'], 12288);
      },
    );

    test(
      'adaptive Anthropic and Kimi coding use output_config effort',
      () async {
        final payload = await _capture(
          const AnthropicMessagesAdapter(),
          _request(
            ProviderProtocol.anthropicMessages,
            const AgentReasoningRequest(
              api: AgentReasoningApi.anthropicAdaptive,
              enabled: true,
              effort: 'xhigh',
            ),
          ),
        );

        expect(payload['thinking'], {
          'type': 'adaptive',
          'display': 'summarized',
        });
        expect(payload['output_config'], {'effort': 'xhigh'});
      },
    );

    test('Gemini 2.5 uses thinkingBudget', () async {
      final payload = await _capture(
        const GeminiGenerateContentAdapter(),
        _request(
          ProviderProtocol.geminiGenerateContent,
          const AgentReasoningRequest(
            api: AgentReasoningApi.geminiBudget,
            enabled: true,
            budgetTokens: 2048,
          ),
        ),
      );

      expect((payload['generationConfig'] as Map)['thinkingConfig'], {
        'includeThoughts': true,
        'thinkingBudget': 2048,
      });
    });

    test('explicit off null omits provider reasoning fields', () async {
      final responses = await _capture(
        const OpenAiResponsesAdapter(),
        _request(
          ProviderProtocol.openaiResponses,
          const AgentReasoningRequest(
            api: AgentReasoningApi.openAiResponses,
            enabled: false,
            sendWhenDisabled: false,
          ),
        ),
      );
      final openRouter = await _capture(
        const OpenAiChatCompletionsAdapter(),
        _request(
          ProviderProtocol.openaiChatCompletions,
          const AgentReasoningRequest(
            api: AgentReasoningApi.openRouter,
            enabled: false,
            sendWhenDisabled: false,
          ),
        ),
      );
      final deepSeek = await _capture(
        const OpenAiChatCompletionsAdapter(),
        _request(
          ProviderProtocol.openaiChatCompletions,
          const AgentReasoningRequest(
            api: AgentReasoningApi.deepSeek,
            enabled: false,
            sendWhenDisabled: false,
          ),
        ),
      );
      final anthropic = await _capture(
        const AnthropicMessagesAdapter(),
        _request(
          ProviderProtocol.anthropicMessages,
          const AgentReasoningRequest(
            api: AgentReasoningApi.anthropicAdaptive,
            enabled: false,
            sendWhenDisabled: false,
          ),
        ),
      );

      expect(responses, isNot(contains('reasoning')));
      expect(responses, isNot(contains('include')));
      expect(openRouter, isNot(contains('reasoning')));
      expect(deepSeek, isNot(contains('thinking')));
      expect(anthropic, isNot(contains('thinking')));
    });

    test('Gemini 3 disabled reasoning uses its hidden minimum', () async {
      final payload = await _capture(
        const GeminiGenerateContentAdapter(),
        _request(
          ProviderProtocol.geminiGenerateContent,
          const AgentReasoningRequest(
            api: AgentReasoningApi.geminiLevel,
            enabled: false,
            effort: 'LOW',
            sendWhenDisabled: true,
          ),
        ),
      );

      expect((payload['generationConfig'] as Map)['thinkingConfig'], {
        'thinkingLevel': 'LOW',
      });
    });

    test('Gemini 3 and Gemma 4 use thinkingLevel', () async {
      final payload = await _capture(
        const GeminiGenerateContentAdapter(),
        _request(
          ProviderProtocol.geminiGenerateContent,
          const AgentReasoningRequest(
            api: AgentReasoningApi.geminiLevel,
            enabled: true,
            effort: 'HIGH',
          ),
        ),
      );

      expect((payload['generationConfig'] as Map)['thinkingConfig'], {
        'includeThoughts': true,
        'thinkingLevel': 'HIGH',
      });
    });
  });
}

Future<Map<String, dynamic>> _capture(
  PromptAssistantProviderAdapter adapter,
  AgentChatRequest request,
) async {
  final capture = _CaptureAdapter();
  final dio = Dio()..httpClientAdapter = capture;
  try {
    await adapter
        .completeAgent(dio: dio, request: request, cancelToken: CancelToken())
        .toList();
    return capture.options!.data as Map<String, dynamic>;
  } finally {
    dio.close(force: true);
  }
}

AgentChatRequest _request(
  ProviderProtocol protocol,
  AgentReasoningRequest reasoningRequest, {
  int? maxOutputTokens,
  int modelMaxOutputTokens = 128000,
  List<Message>? messages,
}) => AgentChatRequest(
  sessionId: 'session',
  provider: ProviderConfig(
    id: 'provider',
    name: 'Provider',
    protocol: protocol,
    baseUrl: 'https://example.test',
  ),
  model: 'model',
  systemPrompt: 'system',
  messages: messages ?? [UserMessage.text('hello')],
  tools: const [],
  apiKey: null,
  maxOutputTokens: maxOutputTokens,
  modelMaxOutputTokens: modelMaxOutputTokens,
  reasoning: reasoningRequest.enabled ? 'high' : null,
  reasoningRequest: reasoningRequest,
);

class _CaptureAdapter implements HttpClientAdapter {
  RequestOptions? options;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    this.options = options;
    return ResponseBody.fromString(
      '',
      200,
      headers: {
        Headers.contentTypeHeader: ['text/event-stream'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
