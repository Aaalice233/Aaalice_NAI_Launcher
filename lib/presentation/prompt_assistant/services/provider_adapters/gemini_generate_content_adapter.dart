import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/agent/agent_types.dart';
import '../../models/agent_protocol.dart';
import '../../../../data/models/prompt_assistant/prompt_assistant_models.dart';
import 'agent_wire_helpers.dart';
import 'gemini_transport.dart';
import 'prompt_assistant_adapter.dart';
import 'reasoning_payload.dart';
import 'reasoning_rejection.dart';

class GeminiGenerateContentAdapter extends PromptAssistantProviderAdapter {
  const GeminiGenerateContentAdapter({
    this.transport = const GoogleAiStudioTransport(),
  });

  final GeminiTransport transport;

  @override
  Future<List<String>> fetchModels({
    required Dio dio,
    required ProviderConfig provider,
    required String? apiKey,
  }) => _guardUnauthorized(
    apiKey,
    () => transport.fetchModels(
      dio: dio,
      provider: provider,
      credential: apiKey,
    ),
  );

  @override
  Future<String> complete({
    required Dio dio,
    required PromptAssistantRequest request,
    required CancelToken cancelToken,
  }) => _guardUnauthorized(
    request.apiKey,
    () => _complete(dio: dio, request: request, cancelToken: cancelToken),
  );

  Future<String> _complete({
    required Dio dio,
    required PromptAssistantRequest request,
    required CancelToken cancelToken,
  }) async {
    final target = await transport.resolve(
      dio: dio,
      provider: request.provider,
      credential: request.apiKey,
      model: request.model,
      method: GeminiMethod.generateContent,
    );
    final response = await dio.post<dynamic>(
      target.endpoint,
      data: {
        if (request.systemPrompt.isNotEmpty)
          'systemInstruction': {
            'parts': [
              {'text': _sanitizeSurrogates(request.systemPrompt)},
            ],
          },
        'contents': [
          {'role': 'user', 'parts': _parts(request.userParts)},
        ],
        'generationConfig': {
          if (geminiThinkingConfig(request.reasoningRequest)
              case final thinking?)
            'thinkingConfig': thinking,
          if (request.maxOutputTokens case final count?)
            'maxOutputTokens': count,
          if (request.responseFormat ==
              PromptAssistantResponseFormat.jsonObject)
            'responseMimeType': 'application/json',
        },
      },
      options: Options(
        headers: target.headers,
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: request.responseTimeout,
      ),
      cancelToken: cancelToken,
    );
    return _extractResponseContent(checkedProviderResponse(response));
  }

  Future<T> _guardUnauthorized<T>(
    String? credential,
    Future<T> Function() request,
  ) async {
    try {
      return await request();
    } on DioException catch (error) {
      _forgetSessionOnUnauthorized(error, credential);
      rethrow;
    }
  }

  void _forgetSessionOnUnauthorized(Object error, String? credential) {
    if (error is DioException && error.response?.statusCode == 401) {
      transport.onUnauthorized(credential);
    }
  }

  @override
  Stream<AgentWireEvent> completeAgent({
    required Dio dio,
    required AgentChatRequest request,
    required CancelToken cancelToken,
  }) async* {
    final pending = <AgentWireEvent>[];
    final payload = _buildAgentPayload(request);

    var stopReason = StopReason.pending;
    Usage? usage;
    var sawError = false;
    var sawFinishReason = false;
    var hasToolCalls = false;
    var generatedToolCallCounter = 0;
    final seenToolCallIds = <String>{};

    String resolveToolCallId(Map<String, dynamic> functionCall) {
      final providedId = functionCall['id'];
      if (providedId is String &&
          providedId.isNotEmpty &&
          seenToolCallIds.add(providedId)) {
        return providedId;
      }
      final name = functionCall['name'] as String? ?? 'tool';
      while (true) {
        final generated =
            '${name}_${DateTime.now().millisecondsSinceEpoch}_'
            '${++generatedToolCallCounter}';
        if (seenToolCallIds.add(generated)) return generated;
      }
    }

    final parser = AgentSseParser(
      onEvent: (_, data) {
        final json = parseSseJson(data);
        if (json == null) {
          if (data.trim() == '[DONE]') return;
          throw const FormatException('Google stream returned invalid JSON');
        }
        if (ProviderResponseError.fromResponse(json, payload)
            case final error?) {
          sawError = true;
          pending.add(agentWireErrorFrom(error, request));
          return;
        }
        final usageRaw = json['usageMetadata'];
        if (usageRaw is Map<String, dynamic>) {
          final promptTokens =
              (usageRaw['promptTokenCount'] as num?)?.toInt() ?? 0;
          final cachedTokens =
              (usageRaw['cachedContentTokenCount'] as num?)?.toInt() ?? 0;
          final candidateTokens =
              (usageRaw['candidatesTokenCount'] as num?)?.toInt() ?? 0;
          final thoughtTokens =
              (usageRaw['thoughtsTokenCount'] as num?)?.toInt() ?? 0;
          usage = Usage(
            input: promptTokens - cachedTokens,
            output: candidateTokens + thoughtTokens,
            cacheRead: cachedTokens,
            totalTokens: (usageRaw['totalTokenCount'] as num?)?.toInt() ?? 0,
          );
        }
        final candidates = json['candidates'];
        if (candidates is List && candidates.isNotEmpty) {
          final first = candidates.first;
          if (first is Map<String, dynamic>) {
            final finishReason = first['finishReason'];
            if (finishReason is String) {
              sawFinishReason = true;
              stopReason = switch (finishReason) {
                'MAX_TOKENS' || 'CONTINUATION' => StopReason.length,
                'STOP' => StopReason.stop,
                _ => StopReason.error,
              };
              if (stopReason == StopReason.error) {
                sawError = true;
                pending.add(
                  AgentWireError('Provider stopped with: $finishReason'),
                );
              }
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
                  final signature = part['thoughtSignature'];
                  final isThinking = part['thought'] == true;
                  final functionCall = part['functionCall'];
                  if (text is String &&
                      (text.isNotEmpty || signature is String)) {
                    pending.add(
                      isThinking
                          ? AgentWireThinkingDelta(text)
                          : AgentWireTextDelta(text),
                    );
                    if (signature is String && signature.isNotEmpty) {
                      pending.add(
                        isThinking
                            ? AgentWireThinkingSignature(
                                signature,
                                replace: true,
                              )
                            : AgentWireTextSignature(signature),
                      );
                    }
                  } else if (signature is String &&
                      signature.isNotEmpty &&
                      functionCall is! Map<String, dynamic>) {
                    pending.add(
                      isThinking
                          ? const AgentWireThinkingDelta('')
                          : const AgentWireTextDelta(''),
                    );
                    pending.add(
                      isThinking
                          ? AgentWireThinkingSignature(signature, replace: true)
                          : AgentWireTextSignature(signature),
                    );
                  }
                  if (functionCall is Map<String, dynamic>) {
                    hasToolCalls = true;
                    stopReason = StopReason.toolUse;
                    final args = functionCall['args'];
                    pending.add(
                      AgentWireToolCallDone(
                        id: resolveToolCallId(functionCall),
                        name: functionCall['name'] as String? ?? '',
                        arguments: args is Map<String, dynamic>
                            ? args
                            : const {},
                        thoughtSignature: signature is String
                            ? signature
                            : null,
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
      final target = await transport.resolve(
        dio: dio,
        provider: request.provider,
        credential: request.apiKey,
        model: request.model,
        method: GeminiMethod.streamGenerateContent,
      );
      final stream = agentStreamPost(
        dio,
        endpoint: '${target.endpoint}?alt=sse',
        payload: payload,
        headers: target.headers,
        cancelToken: cancelToken,
        // Duration.zero overrides Dio's BaseOptions deadline instead of
        // inheriting it. Reasoning models can take minutes before first bytes.
        receiveTimeout: Duration.zero,
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
      _forgetSessionOnUnauthorized(error, request.apiKey);
      if (pending.isNotEmpty) {
        yield* Stream.fromIterable(List.of(pending));
      }
      yield agentWireErrorFrom(error, request);
      return;
    }

    if (sawError) return;
    if (!sawFinishReason) {
      yield const AgentWireError('Google stream ended without a finish reason');
      return;
    }
    final effectiveStopReason = stopReason == StopReason.stop && hasToolCalls
        ? StopReason.toolUse
        : stopReason;
    yield AgentWireFinish(stopReason: effectiveStopReason, usage: usage);
  }

  Map<String, dynamic> _buildAgentPayload(AgentChatRequest request) {
    // Gemini 要求 user/model 交替；相邻同角色合并为一个 turn。
    final turns = <Map<String, dynamic>>[];
    final requiresToolCallId = _requiresToolCallId(request.model);
    final supportsMultimodalFunctionResponse =
        _supportsMultimodalFunctionResponse(request.model);
    void appendTurn(String role, Map<String, dynamic> part) {
      if (turns.isNotEmpty && turns.last['role'] == role) {
        (turns.last['parts'] as List<Map<String, dynamic>>).add(part);
      } else {
        turns.add({
          'role': role,
          'parts': [part],
        });
      }
    }

    for (final message in request.messages) {
      if (message is UserMessage) {
        appendTurn('user', {'text': _sanitizeSurrogates(message.text)});
        for (final image in inlineImagesOf(message)) {
          appendTurn('user', {
            'inlineData': {
              'mimeType': image.mimeType,
              'data': base64Encode(image.bytes),
            },
          });
        }
      } else if (message is AssistantMessage) {
        final sameProviderAndModel =
            message.provider == request.provider.id &&
            message.model == request.model;
        for (final block in message.content) {
          switch (block) {
            case AssistantTextContent()
                when block.text.isNotEmpty ||
                    (sameProviderAndModel &&
                        block.signature?.isNotEmpty == true):
              appendTurn('model', {
                'text': _sanitizeSurrogates(block.text),
                if (sameProviderAndModel && block.signature?.isNotEmpty == true)
                  'thoughtSignature': block.signature,
              });
            case AssistantThinkingContent()
                when sameProviderAndModel &&
                    (block.thinking.isNotEmpty ||
                        block.signature?.isNotEmpty == true):
              appendTurn('model', {
                'thought': true,
                'text': _sanitizeSurrogates(block.thinking),
                if (block.signature?.isNotEmpty == true)
                  'thoughtSignature': block.signature,
              });
            case ToolCallContent():
              appendTurn('model', {
                'functionCall': {
                  'name': block.name,
                  'args': block.arguments,
                  if (requiresToolCallId) 'id': _normalizeToolCallId(block.id),
                },
                if (sameProviderAndModel &&
                    block.thoughtSignature?.isNotEmpty == true)
                  'thoughtSignature': block.thoughtSignature,
              });
            default:
              break;
          }
        }
      } else if (message is ToolResultMessage) {
        final imageParts = <Map<String, dynamic>>[
          for (final image in toolResultImagesOf(message))
            if (image.source.base64Data case final data?)
              {
                'inlineData': {'mimeType': image.source.mimeType, 'data': data},
              },
        ];
        final hasText = message.text.trim().isNotEmpty;
        final responseText = hasText
            ? message.text
            : (imageParts.isNotEmpty ? '(see attached image)' : '');
        appendTurn('user', {
          'functionResponse': {
            'name': message.toolName,
            'response': message.isError
                ? {'error': _sanitizeSurrogates(responseText)}
                : {'output': _sanitizeSurrogates(responseText)},
            if (requiresToolCallId)
              'id': _normalizeToolCallId(message.toolCallId),
            if (supportsMultimodalFunctionResponse && imageParts.isNotEmpty)
              'parts': imageParts,
          },
        });
        if (!supportsMultimodalFunctionResponse && imageParts.isNotEmpty) {
          appendTurn('user', {'text': 'Tool result image:'});
          for (final imagePart in imageParts) {
            appendTurn('user', imagePart);
          }
        }
      }
    }

    final thinkingConfig = geminiThinkingConfig(request.reasoningRequest);
    return {
      if (request.systemPrompt.isNotEmpty)
        'systemInstruction': {
          'parts': [
            {'text': _sanitizeSurrogates(request.systemPrompt)},
          ],
        },
      'contents': turns,
      if (thinkingConfig != null || request.effectiveMaxOutputTokens != null)
        'generationConfig': {
          if (thinkingConfig != null) 'thinkingConfig': thinkingConfig,
          if (request.effectiveMaxOutputTokens case final maxTokens?)
            'maxOutputTokens': maxTokens,
        },
      if (request.tools.isNotEmpty)
        'tools': [
          {
            'functionDeclarations': [
              for (final tool in request.tools)
                {
                  'name': tool.name,
                  'description': tool.description,
                  // Gemini 原生 API 支持完整 JSON Schema；使用旧 parameters
                  // 会把 enum 限定成字符串，导致整数枚举在请求校验阶段失败。
                  // Gemini ignores `const` in `parametersJsonSchema` but honors
                  // single-value `enum` (Pi google-shared.ts rewriteConstAsEnum).
                  'parametersJsonSchema': _rewriteConstAsEnum(tool.parameters),
                },
            ],
          },
        ],
    };
  }

  List<Map<String, dynamic>> _parts(List<PromptAssistantContentPart> parts) {
    return [
      for (final part in parts)
        if (part is PromptAssistantTextPart)
          {'text': _sanitizeSurrogates(part.text)}
        else if (part is PromptAssistantImagePart)
          {
            'inlineData': {
              'mimeType': part.mimeType,
              'data': base64Encode(part.bytes),
            },
          },
    ];
  }

  String _extractResponseContent(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final candidates = raw['candidates'];
      if (candidates is List) {
        final parts = <String>[];
        for (final candidate in candidates) {
          if (candidate is Map<String, dynamic>) {
            final content = candidate['content'];
            if (content is Map<String, dynamic>) {
              final rawParts = content['parts'];
              if (rawParts is List) {
                parts.addAll(
                  rawParts
                      .where((part) => part is! Map || part['thought'] != true)
                      .map(contentToText),
                );
              }
            }
          }
        }
        final joined = parts.where((e) => e.isNotEmpty).join();
        return joined;
      }
    }
    return contentToText(raw);
  }
}

bool _requiresToolCallId(String modelId) {
  final normalized = modelId.startsWith('models/')
      ? modelId.substring('models/'.length)
      : modelId;
  final majorVersion = _geminiMajorVersion(normalized);
  return normalized.startsWith('claude-') ||
      normalized.startsWith('gpt-oss-') ||
      (majorVersion != null && majorVersion >= 3);
}

bool _supportsMultimodalFunctionResponse(String modelId) {
  final normalized = modelId.startsWith('models/')
      ? modelId.substring('models/'.length)
      : modelId;
  final majorVersion = _geminiMajorVersion(normalized);
  return majorVersion == null || majorVersion >= 3;
}

int? _geminiMajorVersion(String modelId) {
  final match = RegExp(
    r'^gemini(?:-live)?-(\d+)',
    caseSensitive: false,
  ).firstMatch(modelId);
  return int.tryParse(match?.group(1) ?? '');
}

String _normalizeToolCallId(String id) => id
    .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
    .substring(0, id.length > 64 ? 64 : id.length);

const _jsonSchemaNameMaps = <String>{
  'properties',
  'patternProperties',
  r'$defs',
  'definitions',
  'dependentSchemas',
  'dependencies',
};

const _jsonSchemaSubschemas = <String>{
  'additionalProperties',
  'unevaluatedProperties',
  'propertyNames',
  'items',
  'prefixItems',
  'additionalItems',
  'unevaluatedItems',
  'contains',
  'allOf',
  'anyOf',
  'oneOf',
  'not',
  'if',
  'then',
  'else',
  'contentSchema',
};

Object? _rewriteConstAsEnum(Object? schema, {bool isNameMap = false}) {
  if (schema is List) {
    return [for (final item in schema) _rewriteConstAsEnum(item)];
  }
  if (schema is! Map) {
    return schema;
  }
  final result = <String, dynamic>{};
  for (final entry in schema.entries) {
    final key = entry.key.toString();
    final value = entry.value;
    if (isNameMap || _jsonSchemaSubschemas.contains(key)) {
      result[key] = _rewriteConstAsEnum(value);
    } else if (_jsonSchemaNameMaps.contains(key)) {
      result[key] = _rewriteConstAsEnum(value, isNameMap: true);
    } else {
      result[key] = value;
    }
  }
  if (!isNameMap &&
      result.containsKey('const') &&
      !result.containsKey('enum')) {
    final value = result['const'];
    if (value is String || value is num) {
      result.remove('const');
      result['enum'] = [value];
    }
  }
  return result;
}

String _sanitizeSurrogates(String value) {
  final units = value.codeUnits;
  final sanitized = <int>[];
  for (var index = 0; index < units.length; index++) {
    final unit = units[index];
    if (unit >= 0xD800 && unit <= 0xDBFF) {
      if (index + 1 < units.length) {
        final next = units[index + 1];
        if (next >= 0xDC00 && next <= 0xDFFF) {
          sanitized
            ..add(unit)
            ..add(next);
          index++;
          continue;
        }
      }
      sanitized.add(0xFFFD);
    } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
      sanitized.add(0xFFFD);
    } else {
      sanitized.add(unit);
    }
  }
  return String.fromCharCodes(sanitized);
}
