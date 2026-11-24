import 'package:dio/dio.dart';

import '../../prompt_assistant/models/agent_protocol.dart';
import '../../prompt_assistant/services/provider_adapters/provider_adapter_registry.dart';
import '../../prompt_assistant/services/provider_adapters/reasoning_rejection.dart';

/// Agent HTTP 请求分发。
class AgentApiClient {
  AgentApiClient(this._dio, {this.reasoningRejectionHint});

  final Dio _dio;
  final String Function()? reasoningRejectionHint;
  final Map<String, CancelToken> _cancelTokens = {};

  void cancel(String sessionId) {
    final token = _cancelTokens.remove(sessionId);
    token?.cancel('cancelled by user');
  }

  Stream<AgentWireEvent> complete(
    AgentChatRequest request, {
    String cancelSessionId = 'agent_chat',
  }) {
    _cancelTokens.remove(cancelSessionId)?.cancel('replaced by new request');
    final cancelToken = CancelToken();
    _cancelTokens[cancelSessionId] = cancelToken;
    return providerAdapterFor(request.provider)
        .completeAgent(dio: _dio, request: request, cancelToken: cancelToken)
        .map((event) {
          if (event case AgentWireError(
            :final message,
            rejectedReasoningField: final field?,
          )) {
            return AgentWireError(
              reasoningRejectionMessage(
                message,
                field,
                reasoningRejectionHint?.call(),
              ),
              retryMessage: event.retryMessage,
              rejectedReasoningField: field,
            );
          }
          return event;
        });
  }
}
