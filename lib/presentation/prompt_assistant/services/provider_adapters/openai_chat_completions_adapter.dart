import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/agent/agent_types.dart';
import '../../models/agent_protocol.dart';
import '../../models/prompt_assistant_models.dart';
import 'agent_wire_helpers.dart';
import 'prompt_assistant_adapter.dart';

class OpenAiChatCompletionsAdapter extends PromptAssistantProviderAdapter {
  const OpenAiChatCompletionsAdapter({this.ollamaTagsFallback = false});

  final bool ollamaTagsFallback;

  @override
  Future<List<String>> fetchModels({
    required Dio dio,
    required ProviderConfig provider,
    required String? apiKey,
  }) async {
    if (provider.preset == ProviderPreset.pollinations ||
        provider.type == ProviderType.pollinations) {
      return const ['openai-large'];
    }

    final headers = <String, dynamic>{};
    if (apiKey != null && apiKey.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${apiKey.trim()}';
    }

    final endpoints = <String>[
      _resolveModelsEndpoint(provider),
      if (ollamaTagsFallback ||
          provider.protocol == ProviderProtocol.ollamaChatCompletions)
        _resolveOllamaTagsEndpoint(provider),
    ];

    DioException? lastError;
    for (final endpoint in endpoints.toSet()) {
      try {
        final response = await dio.get<dynamic>(
          endpoint,
          options: Options(
            headers: headers,
            sendTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 30),
          ),
        );
        final names = extractModelNames(response.data);
        if (names.isNotEmpty) {
          return names;
        }
      } on DioException catch (e) {
        lastError = e;
      }
    }

    if (lastError != null) {
      throw lastError;
    }
    return provider.preset?.defaultModelNames ?? const [];
  }

  @override
  Future<String> complete({
    required Dio dio,
    required PromptAssistantRequest request,
    required CancelToken cancelToken,
  }) async {
    final endpoint = _resolveEndpoint(request.provider);
    final payload = <String, dynamic>{
      'model': request.model,
      'stream': false,
      'messages': _buildMessages(request),
    };

    final response = await _postWithFallback(
      dio: dio,
      request: request,
      endpoint: endpoint,
      payload: payload,
      cancelToken: cancelToken,
    );
    return _extractResponseContent(response.data);
  }

  @override
  Stream<AgentWireEvent> completeAgent({
    required Dio dio,
    required AgentChatRequest request,
    required CancelToken cancelToken,
  }) async* {
    if (request.provider.preset == ProviderPreset.pollinations ||
        request.provider.type == ProviderType.pollinations) {
      yield const AgentWireError(
        'Pollinations does not support tool calling. Switch the chat task '
        'routing to a provider with function calling support.',
      );
      return;
    }

    final isOllama =
        request.provider.protocol == ProviderProtocol.ollamaChatCompletions ||
            ollamaTagsFallback;
    if (isOllama) {
      yield* _completeAgentNonStream(
        dio: dio,
        request: request,
        cancelToken: cancelToken,
      );
      return;
    }

    final payload = _buildAgentPayload(request, stream: true);
    final headers = _agentHeaders(request.apiKey);
    final toolBuffers = <int, _OpenAiToolBuffer>{};
    final toolOrder = <int>[];
    var finishReason = 'stop';
    Usage? usage;
    final pending = <AgentWireEvent>[];

    final parser = AgentSseParser(
      onEvent: (_, data) {
        if (data.trim() == '[DONE]') {
          return;
        }
        final json = parseSseJson(data);
        if (json == null) {
          return;
        }
        final error = extractErrorMessage(json);
        if (error != null) {
          pending.add(AgentWireError('LLM service returned an error: $error'));
          return;
        }
        final usageRaw = json['usage'];
        if (usageRaw is Map<String, dynamic>) {
          final input = (usageRaw['prompt_tokens'] as num?)?.toInt() ?? 0;
          final output = (usageRaw['completion_tokens'] as num?)?.toInt() ?? 0;
          usage = Usage(
            input: input,
            output: output,
            totalTokens: (usageRaw['total_tokens'] as num?)?.toInt() ?? 0,
          );
        }
        final choices = json['choices'];
        if (choices is List && choices.isNotEmpty) {
          final first = choices.first;
          if (first is Map<String, dynamic>) {
            final delta = first['delta'];
            if (delta is Map<String, dynamic>) {
              final content = delta['content'];
              if (content is String && content.isNotEmpty) {
                pending.add(AgentWireTextDelta(content));
              }
              final calls = delta['tool_calls'];
              if (calls is List) {
                for (final call in calls) {
                  if (call is! Map) {
                    continue;
                  }
                  final index = (call['index'] as num?)?.toInt() ?? 0;
                  final buffer = toolBuffers.putIfAbsent(index, () {
                    toolOrder.add(index);
                    return _OpenAiToolBuffer();
                  });
                  final id = call['id'];
                  if (id is String && id.isNotEmpty) {
                    buffer.id = id;
                  }
                  final function = call['function'];
                  if (function is Map) {
                    final name = function['name'];
                    if (name is String && name.isNotEmpty) {
                      buffer.name = name;
                    }
                    final args = function['arguments'];
                    if (args is String) {
                      buffer.args.write(args);
                    }
                  }
                }
              }
            }
            final fr = first['finish_reason'];
            if (fr is String && fr.isNotEmpty) {
              finishReason = fr;
            }
          }
        }
      },
    );

    try {
      final stream = agentStreamPost(
        dio,
        endpoint: _resolveEndpoint(request.provider),
        payload: payload,
        headers: headers,
        cancelToken: cancelToken,
      );
      await for (final chunk in stream) {
        parser.push(chunk);
        if (pending.isNotEmpty) {
          yield* Stream.fromIterable(List.of(pending));
          pending.clear();
        }
      }
      parser.close();
      if (pending.isNotEmpty) {
        yield* Stream.fromIterable(List.of(pending));
        pending.clear();
      }
    } on Object catch (error) {
      if (pending.isNotEmpty) {
        yield* Stream.fromIterable(List.of(pending));
      }
      yield agentWireErrorFrom(error, request.provider);
      return;
    }

    final orderedIndexes = [...toolOrder]..sort();
    for (final index in orderedIndexes) {
      final buffer = toolBuffers[index]!;
      if (buffer.name.isEmpty) {
        continue;
      }
      yield AgentWireToolCallDone(
        id: buffer.id,
        name: buffer.name,
        arguments: parseToolArguments(buffer.args.toString()),
      );
    }
    yield AgentWireFinish(
      stopReason: stopReasonFromName(finishReason),
      usage: usage,
    );
  }

  Stream<AgentWireEvent> _completeAgentNonStream({
    required Dio dio,
    required AgentChatRequest request,
    required CancelToken cancelToken,
  }) async* {
    final payload = _buildAgentPayload(request, stream: false);
    try {
      final response = await dio.post<dynamic>(
        _resolveEndpoint(request.provider),
        data: payload,
        options: Options(
          headers: _agentHeaders(request.apiKey),
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 5),
        ),
        cancelToken: cancelToken,
      );
      final raw = response.data;
      if (raw is Map<String, dynamic>) {
        final error = extractErrorMessage(raw);
        if (error != null) {
          yield AgentWireError('LLM service returned an error: $error');
          return;
        }
        final choices = raw['choices'];
        if (choices is List && choices.isNotEmpty) {
          final first = choices.first;
          if (first is Map<String, dynamic>) {
            final message = first['message'];
            var text = '';
            if (message is Map<String, dynamic>) {
              text = contentToText(message['content']);
              final calls = message['tool_calls'];
              if (calls is List) {
                for (final call in calls) {
                  if (call is Map<String, dynamic>) {
                    final function = call['function'];
                    final name = function is Map<String, dynamic>
                        ? function['name'] as String? ?? ''
                        : '';
                    final rawArgs = function is Map<String, dynamic>
                        ? function['arguments'] as String?
                        : null;
                    yield AgentWireToolCallDone(
                      id: call['id'] as String? ?? '',
                      name: name,
                      arguments: parseToolArguments(rawArgs),
                    );
                  }
                }
              }
            }
            if (text.isNotEmpty) {
              yield AgentWireTextDelta(text);
            }
            final usageRaw = raw['usage'];
            Usage? usage;
            if (usageRaw is Map<String, dynamic>) {
              usage = Usage(
                input: (usageRaw['prompt_tokens'] as num?)?.toInt() ?? 0,
                output: (usageRaw['completion_tokens'] as num?)?.toInt() ?? 0,
                totalTokens: (usageRaw['total_tokens'] as num?)?.toInt() ?? 0,
              );
            }
            yield AgentWireFinish(
              stopReason: stopReasonFromName(first['finish_reason'] as String?),
              usage: usage,
            );
            return;
          }
        }
      }
      yield const AgentWireError('LLM service returned an unexpected response');
    } on Object catch (error) {
      yield agentWireErrorFrom(error, request.provider);
    }
  }

  Map<String, dynamic> _buildAgentPayload(
    AgentChatRequest request, {
    required bool stream,
  }) {
    return {
      'model': request.model,
      if (stream) 'stream': true,
      if (stream) 'stream_options': {'include_usage': true},
      'messages': _buildAgentMessages(request),
      if (request.tools.isNotEmpty) ...{
        'tools': [
          for (final tool in request.tools)
            {
              'type': 'function',
              'function': {
                'name': tool.name,
                'description': tool.description,
                'parameters': tool.parameters,
              },
            },
        ],
        'tool_choice': 'auto',
      },
    };
  }

  List<Map<String, dynamic>> _buildAgentMessages(AgentChatRequest request) {
    return [
      if (request.systemPrompt.trim().isNotEmpty)
        {'role': 'system', 'content': request.systemPrompt.trim()},
      for (final message in request.messages) ..._mapAgentMessage(message),
    ];
  }

  List<Map<String, dynamic>> _mapAgentMessage(Message message) {
    if (message is UserMessage) {
      final images = inlineImagesOf(message);
      final text = message.text;
      if (images.isEmpty) {
        return [
          {'role': 'user', 'content': text},
        ];
      }
      return [
        {
          'role': 'user',
          'content': [
            if (text.trim().isNotEmpty) {'type': 'text', 'text': text},
            for (final image in images)
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:${image.mimeType};base64,'
                      '${base64Encode(image.bytes)}',
                },
              },
          ],
        },
      ];
    }
    if (message is AssistantMessage) {
      return [
        {
          'role': 'assistant',
          if (message.text.isNotEmpty) 'content': message.text,
          if (message.toolCalls.isNotEmpty)
            'tool_calls': [
              for (final call in message.toolCalls)
                {
                  'id': call.id,
                  'type': 'function',
                  'function': {
                    'name': call.name,
                    'arguments': jsonEncode(call.arguments),
                  },
                },
            ],
        },
      ];
    }
    if (message is ToolResultMessage) {
      return [
        {
          'role': 'tool',
          'tool_call_id': message.toolCallId,
          'content': message.text,
        },
      ];
    }
    return const [];
  }

  Map<String, dynamic> _agentHeaders(String? apiKey) {
    return {
      'Content-Type': 'application/json',
      if (apiKey != null && apiKey.trim().isNotEmpty)
        'Authorization': 'Bearer ${apiKey.trim()}',
    };
  }

  Future<Response<dynamic>> _postWithFallback({
    required Dio dio,
    required PromptAssistantRequest request,
    required String endpoint,
    required Map<String, dynamic> payload,
    required CancelToken cancelToken,
  }) async {
    final headers = <String, dynamic>{
      'Content-Type': 'application/json',
    };
    if (request.apiKey != null && request.apiKey!.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${request.apiKey!.trim()}';
    }

    try {
      return await dio.post<dynamic>(
        endpoint,
        data: payload,
        options: Options(
          headers: headers,
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 2),
        ),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final shouldRetryDeepSeek =
          request.provider.preset == ProviderPreset.deepseek &&
              (status == 400 || status == 404) &&
              endpoint.endsWith('/v1/chat/completions');
      if (shouldRetryDeepSeek) {
        return dio.post<dynamic>(
          endpoint.replaceFirst('/v1/chat/completions', '/chat/completions'),
          data: payload,
          options: Options(
            headers: headers,
            sendTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(minutes: 2),
          ),
          cancelToken: cancelToken,
        );
      }
      if (status == 400) {
        return dio.post<dynamic>(
          endpoint,
          data: {
            'model': payload['model'],
            'stream': false,
            'messages': payload['messages'],
          },
          options: Options(
            headers: headers,
            sendTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(minutes: 2),
          ),
          cancelToken: cancelToken,
        );
      }
      rethrow;
    }
  }

  List<Map<String, dynamic>> _buildMessages(PromptAssistantRequest request) {
    return [
      if (request.systemPrompt.trim().isNotEmpty)
        {'role': 'system', 'content': request.systemPrompt.trim()},
      {
        'role': 'user',
        'content': _buildUserContent(request.userParts),
      },
    ];
  }

  Object _buildUserContent(List<PromptAssistantContentPart> parts) {
    final hasImage = parts.any((part) => part is PromptAssistantImagePart);
    if (!hasImage) {
      return parts.map(_partText).where((e) => e.isNotEmpty).join('\n');
    }

    return [
      for (final part in parts)
        if (part is PromptAssistantTextPart)
          {'type': 'text', 'text': part.text}
        else if (part is PromptAssistantImagePart)
          {
            'type': 'image_url',
            'image_url': {'url': imageDataUri(part)},
          },
    ];
  }

  String _partText(PromptAssistantContentPart part) {
    if (part is PromptAssistantTextPart) {
      return part.text;
    }
    return '';
  }

  String _resolveEndpoint(ProviderConfig provider) {
    if (provider.preset == ProviderPreset.pollinations ||
        provider.type == ProviderType.pollinations) {
      return 'https://gen.pollinations.ai/v1/chat/completions';
    }

    final base = normalizedBaseUrl(provider.baseUrl);
    if (base.endsWith('/chat/completions')) {
      return base;
    }
    if (base.endsWith('/v1')) {
      return '$base/chat/completions';
    }
    return '$base/v1/chat/completions';
  }

  String _resolveModelsEndpoint(ProviderConfig provider) {
    final base = normalizedBaseUrl(provider.baseUrl);
    if (base.endsWith('/models')) {
      return base;
    }
    if (base.endsWith('/v1')) {
      return '$base/models';
    }
    return '$base/v1/models';
  }

  String _resolveOllamaTagsEndpoint(ProviderConfig provider) {
    final base = normalizedBaseUrl(provider.baseUrl);
    if (base.endsWith('/v1')) {
      return '${base.substring(0, base.length - 3)}/api/tags';
    }
    return '$base/api/tags';
  }

  String _extractResponseContent(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final error = extractErrorMessage(raw);
      if (error != null) {
        throw StateError('LLM service returned an error: $error');
      }
      final choices = raw['choices'];
      if (choices is List && choices.isNotEmpty) {
        final first = choices.first;
        if (first is Map<String, dynamic>) {
          final delta = first['delta'];
          if (delta is Map<String, dynamic>) {
            return contentToText(delta['content']);
          }
          final message = first['message'];
          if (message is Map<String, dynamic>) {
            return contentToText(message['content']);
          }
          return contentToText(first['text']);
        }
      }
      final outputText = contentToText(raw['output_text']);
      if (outputText.isNotEmpty) return outputText;
      final message = raw['message'];
      if (message is Map<String, dynamic>) {
        return contentToText(message['content']);
      }
      final text = contentToText(raw['text']);
      if (text.isNotEmpty) return text;
      final response = contentToText(raw['response']);
      if (response.isNotEmpty) return response;
    }
    return contentToText(raw);
  }
}

class _OpenAiToolBuffer {
  String id = '';
  String name = '';
  final StringBuffer args = StringBuffer();
}
