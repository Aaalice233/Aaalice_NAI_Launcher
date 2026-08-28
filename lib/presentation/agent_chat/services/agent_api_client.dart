import 'package:dio/dio.dart';

import '../../prompt_assistant/models/agent_protocol.dart';
import '../../prompt_assistant/models/prompt_assistant_models.dart';
import '../../prompt_assistant/services/provider_adapters/anthropic_messages_adapter.dart';
import '../../prompt_assistant/services/provider_adapters/gemini_generate_content_adapter.dart';
import '../../prompt_assistant/services/provider_adapters/openai_chat_completions_adapter.dart';
import '../../prompt_assistant/services/provider_adapters/openai_responses_adapter.dart';
import '../../prompt_assistant/services/provider_adapters/prompt_assistant_adapter.dart';

/// Agent HTTP 请求分发。
class AgentApiClient {
  AgentApiClient(this._dio);

  final Dio _dio;
  final Map<String, CancelToken> _cancelTokens = {};

  void cancel(String sessionId) {
    final token = _cancelTokens.remove(sessionId);
    token?.cancel('cancelled by user');
  }

  PromptAssistantProviderAdapter _adapterFor(ProviderConfig provider) {
    switch (provider.protocol) {
      case ProviderProtocol.openaiChatCompletions:
        return const OpenAiChatCompletionsAdapter();
      case ProviderProtocol.openaiResponses:
        return const OpenAiResponsesAdapter();
      case ProviderProtocol.anthropicMessages:
        return const AnthropicMessagesAdapter();
      case ProviderProtocol.geminiGenerateContent:
        return const GeminiGenerateContentAdapter();
      case ProviderProtocol.ollamaChatCompletions:
        return const OpenAiChatCompletionsAdapter(ollamaTagsFallback: true);
    }
  }

  Stream<AgentWireEvent> complete(
    AgentChatRequest request, {
    String cancelSessionId = 'agent_chat',
  }) {
    _cancelTokens.remove(cancelSessionId)?.cancel('replaced by new request');
    final cancelToken = CancelToken();
    _cancelTokens[cancelSessionId] = cancelToken;
    return _adapterFor(
      request.provider,
    ).completeAgent(dio: _dio, request: request, cancelToken: cancelToken);
  }
}
