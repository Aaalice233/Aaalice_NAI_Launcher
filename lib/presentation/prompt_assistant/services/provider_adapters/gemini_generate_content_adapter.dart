import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/agent/agent_types.dart';
import '../../models/agent_protocol.dart';
import '../../models/prompt_assistant_models.dart';
import 'agent_wire_helpers.dart';
import 'prompt_assistant_adapter.dart';

class GeminiGenerateContentAdapter extends PromptAssistantProviderAdapter {
  const GeminiGenerateContentAdapter();

  @override
  Future<List<String>> fetchModels({
    required Dio dio,
    required ProviderConfig provider,
    required String? apiKey,
  }) async {
    final response = await dio.get<dynamic>(
      _resolveModelsEndpoint(provider),
      options: Options(
        headers: _headers(apiKey),
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    return extractModelNames(response.data);
  }

  @override
  Future<String> complete({
    required Dio dio,
    required PromptAssistantRequest request,
    required CancelToken cancelToken,
  }) async {
    final response = await dio.post<dynamic>(
      _resolveGenerateEndpoint(request.provider, request.model),
      data: {
        'system_instruction': {
          'parts': [
            {'text': request.systemPrompt},
          ],
        },
        'contents': [
          {
            'role': 'user',
            'parts': _parts(request.userParts),
          },
        ],
      },
      options: Options(
        headers: _headers(request.apiKey),
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 2),
      ),
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
    final endpoint =
        '${_resolveGenerateEndpoint(request.provider, request.model)}'
        '?alt=sse';
    final pending = <AgentWireEvent>[];

    var stopReason = StopReason.stop;
    Usage? usage;
    var sawError = false;

    final parser = AgentSseParser(
      onEvent: (_, data) {
        final json = parseSseJson(data);
        if (json == null) {
          return;
        }
        final error = extractErrorMessage(json);
        if (error != null) {
          sawError = true;
          pending.add(AgentWireError('LLM service returned an error: $error'));
          return;
        }
        final usageRaw = json['usageMetadata'];
        if (usageRaw is Map<String, dynamic>) {
          usage = Usage(
            input: (usageRaw['promptTokenCount'] as num?)?.toInt() ?? 0,
            output: (usageRaw['candidatesTokenCount'] as num?)?.toInt() ?? 0,
            totalTokens: (usageRaw['totalTokenCount'] as num?)?.toInt() ?? 0,
          );
        }
        final candidates = json['candidates'];
        if (candidates is List && candidates.isNotEmpty) {
          final first = candidates.first;
          if (first is Map<String, dynamic>) {
            final finishReason = first['finishReason'];
            if (finishReason is String) {
              stopReason = switch (finishReason) {
                'MAX_TOKENS' => StopReason.length,
                'STOP' => StopReason.stop,
                _ => StopReason.stop,
              };
            }
            final content = first['content'];
            if (content is Map<String, dynamic>) {
              final parts = content['parts'];
              if (parts is List) {
                for (final part in parts) {
                  if (part is! Map<String, dynamic>) {
                    continue;
                  }
                  final text = part['text'];
                  if (text is String && text.isNotEmpty) {
                    pending.add(AgentWireTextDelta(text));
                  }
                  final functionCall = part['functionCall'];
                  if (functionCall is Map<String, dynamic>) {
                    final args = functionCall['args'];
                    pending.add(
                      AgentWireToolCallDone(
                        id: 'gemini_${pending.length}_'
                            '${DateTime.now().microsecondsSinceEpoch}',
                        name: functionCall['name'] as String? ?? '',
                        arguments: args is Map<String, dynamic>
                            ? args
                            : const {},
                      ),
                    );
                  }
                }
              }
            }
          }
        }
      },
    );

    try {
      final stream = agentStreamPost(
        dio,
        endpoint: endpoint,
        payload: _buildAgentPayload(request),
        headers: _headers(request.apiKey),
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

    if (sawError) {
      return;
    }
    yield AgentWireFinish(
      stopReason: stopReason,
      usage: usage,
    );
  }

  Map<String, dynamic> _buildAgentPayload(AgentChatRequest request) {
    // Gemini 要求 user/model 交替；相邻同角色合并为一个 turn。
    final turns = <Map<String, dynamic>>[];
    void appendTurn(String role, Map<String, dynamic> part) {
      if (turns.isNotEmpty && turns.last['role'] == role) {
        (turns.last['parts'] as List<Map<String, dynamic>>).add(part);
      } else {
        turns.add({'role': role, 'parts': [part]});
      }
    }

    for (final message in request.messages) {
      if (message is UserMessage) {
        appendTurn('user', {'text': message.text});
        for (final image in inlineImagesOf(message)) {
          appendTurn('user', {
            'inline_data': {
              'mime_type': image.mimeType,
              'data': base64Encode(image.bytes),
            },
          });
        }
      } else if (message is AssistantMessage) {
        if (message.text.isNotEmpty) {
          appendTurn('model', {'text': message.text});
        }
        for (final call in message.toolCalls) {
          appendTurn('model', {
            'functionCall': {'name': call.name, 'args': call.arguments},
          });
        }
      } else if (message is ToolResultMessage) {
        appendTurn('user', {
          'functionResponse': {
            'name': message.toolName,
            'response': {'result': message.text},
          },
        });
      }
    }

    return {
      'system_instruction': {
        'parts': [
          {'text': request.systemPrompt},
        ],
      },
      'contents': turns,
      if (request.tools.isNotEmpty)
        'tools': [
          {
            'functionDeclarations': [
              for (final tool in request.tools)
                {
                  'name': tool.name,
                  'description': tool.description,
                  'parameters': sanitizeGeminiSchema(tool.parameters),
                },
            ],
          },
        ],
    };
  }

  Map<String, dynamic> _headers(String? apiKey) {
    return {
      'Content-Type': 'application/json',
      if (apiKey != null && apiKey.trim().isNotEmpty)
        'x-goog-api-key': apiKey.trim(),
    };
  }

  List<Map<String, dynamic>> _parts(List<PromptAssistantContentPart> parts) {
    return [
      for (final part in parts)
        if (part is PromptAssistantTextPart)
          {'text': part.text}
        else if (part is PromptAssistantImagePart)
          {
            'inline_data': {
              'mime_type': part.mimeType,
              'data': base64Encode(part.bytes),
            },
          },
    ];
  }

  String _resolveGenerateEndpoint(ProviderConfig provider, String model) {
    final base = _resolveGeminiRoot(provider);
    final normalizedModel =
        model.startsWith('models/') ? model : 'models/$model';
    return '$base/$normalizedModel:generateContent';
  }

  String _resolveModelsEndpoint(ProviderConfig provider) {
    return '${_resolveGeminiRoot(provider)}/models';
  }

  String _resolveGeminiRoot(ProviderConfig provider) {
    final base = normalizedBaseUrl(provider.baseUrl);
    if (base.endsWith('/v1beta') || base.endsWith('/v1')) {
      return base;
    }
    return '$base/v1beta';
  }

  String _extractResponseContent(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final error = extractErrorMessage(raw);
      if (error != null) {
        throw StateError('LLM service returned an error: $error');
      }
      final candidates = raw['candidates'];
      if (candidates is List) {
        final parts = <String>[];
        for (final candidate in candidates) {
          if (candidate is Map<String, dynamic>) {
            final content = candidate['content'];
            if (content is Map<String, dynamic>) {
              final rawParts = content['parts'];
              if (rawParts is List) {
                parts.addAll(rawParts.map(contentToText));
              }
            }
          }
        }
        final joined = parts.where((e) => e.isNotEmpty).join();
        if (joined.isNotEmpty) return joined;
      }
    }
    return contentToText(raw);
  }
}

/// Gemini 的 Schema 子集：类型名需大写枚举，忽略不支持的键。
Map<String, dynamic> sanitizeGeminiSchema(Map<String, dynamic> schema) {
  final type = _geminiTypeName(schema['type']);
  final result = <String, dynamic>{
    if (type != null) 'type': type,
    if (schema['description'] is String)
      'description': schema['description'] as String,
    if (schema['enum'] is List) 'enum': schema['enum'],
    if (schema['required'] is List) 'required': schema['required'],
    if (schema['properties'] is Map<String, dynamic>)
      'properties': {
        for (final entry in (schema['properties'] as Map<String, dynamic>)
            .entries)
          if (entry.value is Map<String, dynamic>)
            entry.key: sanitizeGeminiSchema(
              entry.value as Map<String, dynamic>,
            ),
      },
    if (schema['items'] is Map<String, dynamic>)
      'items': sanitizeGeminiSchema(schema['items'] as Map<String, dynamic>),
  };
  return result;
}

String? _geminiTypeName(dynamic type) {
  switch (type) {
    case 'string':
    case 'STRING':
      return 'STRING';
    case 'integer':
    case 'INT64':
      return 'INTEGER';
    case 'number':
    case 'DOUBLE':
      return 'NUMBER';
    case 'boolean':
    case 'BOOL':
      return 'BOOLEAN';
    case 'array':
    case 'ARRAY':
      return 'ARRAY';
    case 'object':
    case 'STRUCT':
      return 'OBJECT';
    default:
      return null;
  }
}
