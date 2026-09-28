import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/utils/app_logger.dart';
import '../models/prompt_assistant_models.dart';
import 'assistant_cancellation.dart';
import 'assistant_request_scheduler.dart';
import 'provider_adapters/anthropic_messages_adapter.dart';
import 'provider_adapters/gemini_generate_content_adapter.dart';
import 'provider_adapters/openai_chat_completions_adapter.dart';
import 'provider_adapters/openai_responses_adapter.dart';
import 'provider_adapters/prompt_assistant_adapter.dart';

class PromptAssistantApiClient {
  PromptAssistantApiClient({
    required Dio dio,
    this.imageUploadMaxBytes = promptAssistantImageUploadMaxBytes,
  }) : _dio = dio;

  final Dio _dio;
  final int imageUploadMaxBytes;
  final Map<String, Set<CancelToken>> _cancelTokens = {};
  final scheduler = AssistantRequestScheduler();

  void dispose() {
    cancelCurrentRequest();
    scheduler.dispose();
  }

  void cancelCurrentRequest({String? sessionId}) {
    if (sessionId == null || sessionId.isEmpty) {
      for (final tokens in _cancelTokens.values) {
        for (final token in tokens) {
          token.cancel('cancelled by user');
        }
      }
      _cancelTokens.clear();
      return;
    }

    final tokens = _cancelTokens.remove(sessionId);
    for (final token in tokens ?? <CancelToken>{}) {
      token.cancel('cancelled by user');
    }
  }

  Future<List<String>> fetchModels({
    required ProviderConfig provider,
    required String? apiKey,
  }) {
    final defaults = provider.preset?.defaultModelNames ?? const [];
    return _adapterFor(provider)
        .fetchModels(dio: _dio, provider: provider, apiKey: apiKey)
        .then((models) => models.isEmpty ? defaults : models);
  }

  Stream<StreamingChunk> complete({
    required PromptAssistantRequest request,
  }) async* {
    request.cancelToken?.throwIfCancelled();
    if (!request.allowConcurrentInSession) {
      cancelCurrentRequest(sessionId: request.sessionId);
    }
    final cancelToken = CancelToken();
    final tokens = _cancelTokens.putIfAbsent(request.sessionId, () => {});
    tokens.add(cancelToken);
    if (request.cancelToken case final operationToken?) {
      unawaited(
        operationToken.whenCancel.then((error) => cancelToken.cancel(error)),
      );
    }

    try {
      AppLogger.d(
        'request start provider=${request.provider.id} '
            'protocol=${request.provider.protocol.name} model=${request.model}',
        'PromptAssistant',
      );

      final uploadRequest = await optimizePromptAssistantRequestImagesForUpload(
        request,
        maxBytes: imageUploadMaxBytes,
      );
      final content = await scheduler.run(
        provider: uploadRequest.provider,
        cancelToken: cancelToken,
        request: () => _adapterFor(
          uploadRequest.provider,
        ).complete(dio: _dio, request: uploadRequest, cancelToken: cancelToken),
      );
      cancelToken.throwIfCancelled();
      final trimmed = content.trim();
      if (trimmed.isEmpty) {
        throw StateError(
          'LLM service returned empty content: provider=${request.provider.name}, model=${request.model}',
        );
      }

      AppLogger.d(
        'response done provider=${request.provider.id} '
            'model=${request.model} outputLen=${trimmed.length} '
            'output=${_previewBody(trimmed)}',
        'PromptAssistant',
      );
      yield StreamingChunk(delta: trimmed);
      yield const StreamingChunk(delta: '', done: true);
    } on DioException catch (e) {
      throw PromptAssistantRequestException(_formatDioException(e, request), e);
    } finally {
      tokens.remove(cancelToken);
      if (tokens.isEmpty &&
          identical(_cancelTokens[request.sessionId], tokens)) {
        _cancelTokens.remove(request.sessionId);
      }
    }
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

  String _previewBody(String raw) {
    final normalized = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 300) {
      return normalized;
    }
    return '${normalized.substring(0, 300)}...';
  }

  String _formatDioException(
    DioException error,
    PromptAssistantRequest request,
  ) {
    final response = error.response;
    final status = response?.statusCode;
    final target = _safeRequestTarget(response?.requestOptions);
    final detail =
        _extractDioErrorDetail(response?.data) ??
        error.message ??
        error.error?.toString();

    return [
      'LLM request failed',
      if (status != null) 'HTTP $status',
      'provider=${request.provider.name}',
      'model=${request.model}',
      if (error.type == DioExceptionType.receiveTimeout)
        'response wait timeout=${request.responseTimeout.inSeconds}s; '
            'adjust Settings > Prompt Assistant > Response wait timeout',
      if (target != null) 'endpoint=$target',
      if (detail != null && detail.trim().isNotEmpty) detail.trim(),
    ].join(': ');
  }

  String? _extractDioErrorDetail(dynamic data) {
    if (data == null) return null;
    if (data is Map<String, dynamic>) {
      final message = extractErrorMessage(data);
      if (message != null) return message;
      return _previewBody(_encodeErrorData(data));
    }
    if (data is Map) {
      final normalized = data.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final message = extractErrorMessage(normalized);
      if (message != null) return message;
      return _previewBody(_encodeErrorData(normalized));
    }
    if (data is String) {
      final trimmed = data.trim();
      return trimmed.isEmpty ? null : _previewBody(trimmed);
    }
    return _previewBody(_encodeErrorData(data));
  }

  String _encodeErrorData(dynamic data) {
    try {
      return jsonEncode(data);
    } catch (_) {
      return data.toString();
    }
  }

  String? _safeRequestTarget(RequestOptions? options) {
    if (options == null) return null;
    final uri = options.uri;
    if (uri.hasScheme && uri.host.isNotEmpty) {
      final port = uri.hasPort ? ':${uri.port}' : '';
      final query = uri.hasQuery ? '?<redacted>' : '';
      return '${uri.scheme}://${uri.host}$port${uri.path}$query';
    }
    final query = uri.hasQuery ? '?<redacted>' : '';
    return '${uri.path}$query';
  }
}

class PromptAssistantRequestException extends StateError {
  PromptAssistantRequestException(super.message, this.cause);
  final DioException cause;
}
