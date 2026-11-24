import '../../../../data/models/prompt_assistant/prompt_assistant_models.dart';
import 'anthropic_messages_adapter.dart';
import 'gemini_generate_content_adapter.dart';
import 'openai_chat_completions_adapter.dart';
import 'openai_responses_adapter.dart';
import 'prompt_assistant_adapter.dart';
import 'vertex/vertex_access_tokens.dart';
import 'vertex/vertex_gemini_transport.dart';

final _vertexGeminiAdapter = GeminiGenerateContentAdapter(
  transport: VertexGeminiTransport(VertexAccessTokens.shared),
);

/// 单次补全与 Agent 两条请求路径共用的协议分发。
PromptAssistantProviderAdapter providerAdapterFor(ProviderConfig provider) {
  switch (provider.protocol) {
    case ProviderProtocol.openaiChatCompletions:
      return const OpenAiChatCompletionsAdapter();
    case ProviderProtocol.openaiResponses:
      return const OpenAiResponsesAdapter();
    case ProviderProtocol.anthropicMessages:
      return const AnthropicMessagesAdapter();
    case ProviderProtocol.geminiGenerateContent:
      return provider.isVertex
          ? _vertexGeminiAdapter
          : const GeminiGenerateContentAdapter();
    case ProviderProtocol.ollamaChatCompletions:
      return const OpenAiChatCompletionsAdapter(ollamaTagsFallback: true);
  }
}
