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
          {'role': 'user', 'parts': _parts(request.userParts)},
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
        '${_resolveStreamGenerateEndpoint(request.provider, request.model)}'
        '?alt=sse';
    final pending = <AgentWireEvent>[];

    var stopReason = StopReason.pending;
    Usage? usage;
    var sawError = false;
    var sawFinishReason = false;
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
              sawFinishReason = true;
              stopReason = switch (finishReason) {
                'MAX_TOKENS' => StopReason.length,
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

    if (sawError) return;
    if (!sawFinishReason) {
      yield const AgentWireError('Google stream ended without a finish reason');
      return;
    }
    yield AgentWireFinish(stopReason: stopReason, usage: usage);
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
                'text': block.text,
                if (sameProviderAndModel && block.signature?.isNotEmpty == true)
                  'thoughtSignature': block.signature,
              });
            case AssistantThinkingContent()
                when block.thinking.isNotEmpty ||
                    (sameProviderAndModel &&
                        block.signature?.isNotEmpty == true):
              appendTurn('model', {
                if (sameProviderAndModel) 'thought': true,
                'text': block.thinking,
                if (sameProviderAndModel && block.signature?.isNotEmpty == true)
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
        appendTurn('user', {
          'functionResponse': {
            'name': message.toolName,
            'response': message.isError
                ? {'error': message.text}
                : {'output': message.text},
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

    final reasoning = request.reasoningRequest;
    final thinkingConfig = switch (reasoning?.api) {
      AgentReasoningApi.geminiBudget =>
        reasoning!.enabled
            ? {
                'includeThoughts': true,
                'thinkingBudget': reasoning.budgetTokens,
              }
            : {'thinkingBudget': 0},
      AgentReasoningApi.geminiLevel =>
        reasoning!.enabled
            ? {'includeThoughts': true, 'thinkingLevel': reasoning.effort}
            : reasoning.sendWhenDisabled
            ? {'thinkingLevel': reasoning.effort}
            : null,
      _ => null,
    };
    return {
      'system_instruction': {
        'parts': [
          {'text': request.systemPrompt},
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
                  'parametersJsonSchema': tool.parameters,
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
    final normalizedModel = model.startsWith('models/')
        ? model
        : 'models/$model';
    return '$base/$normalizedModel:generateContent';
  }

  String _resolveStreamGenerateEndpoint(ProviderConfig provider, String model) {
    final base = _resolveGeminiRoot(provider);
    final normalizedModel = model.startsWith('models/')
        ? model
        : 'models/$model';
    return '$base/$normalizedModel:streamGenerateContent';
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
