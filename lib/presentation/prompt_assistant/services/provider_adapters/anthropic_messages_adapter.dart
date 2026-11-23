import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/agent/agent_types.dart';
import '../../models/agent_protocol.dart';
import '../../../../data/models/prompt_assistant/prompt_assistant_models.dart';
import 'agent_wire_helpers.dart';
import 'prompt_assistant_adapter.dart';
import 'reasoning_payload.dart';
import 'reasoning_rejection.dart';

class AnthropicMessagesAdapter extends PromptAssistantProviderAdapter {
  const AnthropicMessagesAdapter();

  @override
  Future<List<String>> fetchModels({
    required Dio dio,
    required ProviderConfig provider,
    required String? apiKey,
  }) async {
    final headers = _headers(apiKey);
    final response = await dio.get<dynamic>(
      _resolveModelsEndpoint(provider),
      options: Options(
        headers: headers,
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
      _resolveMessagesEndpoint(request.provider),
      data: {
        'model': request.model,
        ...anthropicReasoningPayload(
          reasoning: request.reasoningRequest,
          maxOutputTokens: request.maxOutputTokens ?? 2048,
          modelMaxOutputTokens: request.modelMaxOutputTokens,
        ),
        'system': request.systemPrompt,
        'messages': [
          {'role': 'user', 'content': _contentParts(request.userParts)},
        ],
      },
      options: Options(
        headers: _headers(request.apiKey),
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: request.responseTimeout,
      ),
      cancelToken: cancelToken,
    );
    return _extractResponseContent(checkedProviderResponse(response));
  }

  @override
  Stream<AgentWireEvent> completeAgent({
    required Dio dio,
    required AgentChatRequest request,
    required CancelToken cancelToken,
  }) async* {
    final payload = buildAgentPayload(request);
    final pending = <AgentWireEvent>[];

    // Anthropic SSE：content_block_start/delta/stop 组装内容块，
    // message_delta 携带 stop_reason 与输出用量。
    final blocks = <int, _AnthropicBlock>{};
    final blockOrder = <int>[];
    final emittedToolCallIds = <String>{};
    var stopReason = StopReason.stop;
    Usage? usage;
    var sawError = false;
    var sawMessageStop = false;

    final parser = AgentSseParser(
      onEvent: (event, data) {
        if (event == 'ping') {
          return;
        }
        final json = parseSseJson(data);
        if (json == null) {
          return;
        }
        switch (event) {
          case 'error':
            sawError = true;
            pending.add(
              agentWireErrorFrom(ProviderResponseError(json, payload), request),
            );
          case 'message_start':
            final message = json['message'];
            if (message is Map<String, dynamic>) {
              final usageRaw = message['usage'];
              if (usageRaw is Map<String, dynamic>) {
                final input = (usageRaw['input_tokens'] as num?)?.toInt() ?? 0;
                final output =
                    (usageRaw['output_tokens'] as num?)?.toInt() ?? 0;
                final cacheRead =
                    (usageRaw['cache_read_input_tokens'] as num?)?.toInt() ?? 0;
                final cacheWrite =
                    (usageRaw['cache_creation_input_tokens'] as num?)
                        ?.toInt() ??
                    0;
                usage = Usage(
                  input: input,
                  output: output,
                  cacheRead: cacheRead,
                  cacheWrite: cacheWrite,
                  totalTokens: input + output + cacheRead + cacheWrite,
                );
              }
            }
          case 'content_block_start':
            final index = (json['index'] as num?)?.toInt() ?? 0;
            final block = json['content_block'];
            if (block is Map<String, dynamic> && block['type'] == 'tool_use') {
              blockOrder.add(index);
              blocks[index] = _AnthropicBlock()
                ..id = block['id'] as String? ?? ''
                ..name = block['name'] as String? ?? '';
            }
          case 'content_block_delta':
            final index = (json['index'] as num?)?.toInt() ?? 0;
            final delta = json['delta'];
            if (delta is Map<String, dynamic>) {
              if (delta['type'] == 'text_delta') {
                final text = delta['text'];
                if (text is String && text.isNotEmpty) {
                  pending.add(AgentWireTextDelta(text));
                }
              } else if (delta['type'] == 'thinking_delta') {
                final thinking = delta['thinking'];
                if (thinking is String && thinking.isNotEmpty) {
                  pending.add(AgentWireThinkingDelta(thinking));
                }
              } else if (delta['type'] == 'signature_delta') {
                final signature = delta['signature'];
                if (signature is String && signature.isNotEmpty) {
                  pending.add(AgentWireThinkingSignature(signature));
                }
              } else if (delta['type'] == 'input_json_delta') {
                final partial = delta['partial_json'];
                final block = blocks[index];
                if (block != null && partial is String) {
                  block.args.write(partial);
                }
              }
            }
          case 'content_block_stop':
            final index = (json['index'] as num?)?.toInt() ?? 0;
            final block = blocks[index];
            if (block != null && !block.flushed) {
              block.flushed = true;
              // 同一 id 再次出现是渠道重放；放行会让工具执行两次。
              if (block.id.isEmpty || emittedToolCallIds.add(block.id)) {
                pending.add(
                  AgentWireToolCallDone(
                    id: block.id,
                    name: block.name,
                    arguments: parseToolArguments(block.args.toString()),
                  ),
                );
              }
            }
          case 'message_delta':
            final delta = json['delta'];
            if (delta is Map<String, dynamic>) {
              final reason = delta['stop_reason'];
              if (reason is String) {
                stopReason = switch (reason) {
                  'tool_use' => StopReason.toolUse,
                  'max_tokens' => StopReason.length,
                  'refusal' || 'sensitive' => StopReason.error,
                  _ => StopReason.stop,
                };
                if (stopReason == StopReason.error) {
                  sawError = true;
                  pending.add(
                    AgentWireError('Provider stopped with: $reason'),
                  );
                }
              }
            }
            final usageRaw = json['usage'];
            if (usageRaw is Map<String, dynamic>) {
              final input =
                  (usageRaw['input_tokens'] as num?)?.toInt() ??
                  usage?.input ??
                  0;
              final output =
                  (usageRaw['output_tokens'] as num?)?.toInt() ??
                  usage?.output ??
                  0;
              final cacheRead =
                  (usageRaw['cache_read_input_tokens'] as num?)?.toInt() ??
                  usage?.cacheRead ??
                  0;
              final cacheWrite =
                  (usageRaw['cache_creation_input_tokens'] as num?)?.toInt() ??
                  usage?.cacheWrite ??
                  0;
              usage = Usage(
                input: input,
                output: output,
                cacheRead: cacheRead,
                cacheWrite: cacheWrite,
                totalTokens: input + output + cacheRead + cacheWrite,
              );
            }
          case 'message_stop':
            sawMessageStop = true;
          default:
            break;
        }
      },
    );

    try {
      final stream = agentStreamPost(
        dio,
        endpoint: _resolveMessagesEndpoint(request.provider),
        payload: payload,
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
      yield agentWireErrorFrom(error, request);
      return;
    }

    if (sawError) {
      return;
    }

    if (!sawMessageStop) {
      yield const AgentWireError('Anthropic stream ended before message_stop.');
      return;
    }

    // 兜底：部分兼容实现不发 content_block_stop。
    for (final index in blockOrder) {
      final block = blocks[index];
      if (block != null &&
          !block.flushed &&
          (block.id.isEmpty || emittedToolCallIds.add(block.id))) {
        yield AgentWireToolCallDone(
          id: block.id,
          name: block.name,
          arguments: parseToolArguments(block.args.toString()),
        );
      }
    }
    yield AgentWireFinish(stopReason: stopReason, usage: usage);
  }

  /// Visible for payload regression tests.
  Map<String, dynamic> buildAgentPayload(AgentChatRequest request) {
    // Anthropic 要求 user/assistant 交替；把相邻同角色的消息合并成一个
    // content 数组（tool_result 也归入 user 侧内容块）。
    final turns = <Map<String, dynamic>>[];
    void appendTurn(String role, Map<String, dynamic> block) {
      if (turns.isNotEmpty && turns.last['role'] == role) {
        (turns.last['content'] as List<Map<String, dynamic>>).add(block);
      } else {
        turns.add({
          'role': role,
          'content': [block],
        });
      }
    }

    for (var i = 0; i < request.messages.length; i++) {
      final message = request.messages[i];
      if (message is UserMessage) {
        final images = inlineImagesOf(message);
        if (images.isEmpty) {
          appendTurn('user', {'type': 'text', 'text': message.text});
        } else {
          for (final image in images) {
            appendTurn('user', {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': image.mimeType,
                'data': base64Encode(image.bytes),
              },
            });
          }
          if (message.text.trim().isNotEmpty) {
            appendTurn('user', {'type': 'text', 'text': message.text});
          }
        }
      } else if (message is AssistantMessage) {
        final isDifferentModel =
            (message.provider != null || message.model != null) &&
            (message.provider != request.provider.id ||
                message.model != request.model);
        for (final block in message.content) {
          switch (block) {
            case AssistantThinkingContent() when isDifferentModel:
              break;
            case AssistantThinkingContent()
                when block.signature?.isNotEmpty == true:
              appendTurn('assistant', {
                'type': 'thinking',
                'thinking': block.thinking,
                'signature': block.signature,
              });
            case AssistantThinkingContent()
                when block.thinking.isNotEmpty &&
                    request.reasoningRequest?.allowEmptySignature == true:
              appendTurn('assistant', {
                'type': 'thinking',
                'thinking': block.thinking,
                'signature': '',
              });
            case AssistantThinkingContent() when block.thinking.isNotEmpty:
              appendTurn('assistant', {'type': 'text', 'text': block.thinking});
            case AssistantTextContent() when block.text.isNotEmpty:
              appendTurn('assistant', {'type': 'text', 'text': block.text});
            case ToolCallContent():
              appendTurn('assistant', {
                'type': 'tool_use',
                'id': block.id,
                'name': block.name,
                'input': block.arguments,
              });
            default:
              break;
          }
        }
      } else if (message is ToolResultMessage) {
        // Anthropic rejects images inside is_error tool_result blocks (#10794).
        // Collect consecutive tool_results first, then append any split error
        // images to the same user turn after all tool_result blocks.
        final errorImageBlocks = <Map<String, dynamic>>[];
        var j = i;
        while (j < request.messages.length &&
            request.messages[j] is ToolResultMessage) {
          final toolMsg = request.messages[j] as ToolResultMessage;
          final images = toolResultImagesOf(toolMsg);
          if (toolMsg.isError && images.isNotEmpty) {
            final sanitizedContent = _replaceErrorToolImagesWithPlaceholder(
              toolMsg.content,
            );
            appendTurn('user', {
              'type': 'tool_result',
              'tool_use_id': toolMsg.toolCallId,
              'content': sanitizedContent,
              'is_error': true,
            });
            errorImageBlocks.add({
              'type': 'text',
              'text':
                  'Images from the error result of tool call '
                  '${toolMsg.toolCallId} (${toolMsg.toolName}):',
            });
            for (final image in images) {
              final encoded = _encodeAnthropicImage(image);
              if (encoded != null) errorImageBlocks.add(encoded);
            }
          } else {
            appendTurn('user', {
              'type': 'tool_result',
              'tool_use_id': toolMsg.toolCallId,
              'content': images.isEmpty
                  ? toolMsg.text
                  : [
                      if (toolMsg.text.trim().isNotEmpty)
                        {'type': 'text', 'text': toolMsg.text},
                      for (final image in images)
                        if (_encodeAnthropicImage(image) case final encoded?)
                          encoded,
                    ],
              'is_error': toolMsg.isError,
            });
          }
          j++;
        }
        for (final block in errorImageBlocks) {
          appendTurn('user', block);
        }
        i = j - 1;
      }
    }

    return {
      'model': request.model,
      ...anthropicReasoningPayload(
        reasoning: request.reasoningRequest,
        legacyLevel: request.reasoning,
        maxOutputTokens: request.maxOutputTokens,
        modelMaxOutputTokens: request.modelMaxOutputTokens,
      ),
      if (request.systemPrompt.trim().isNotEmpty)
        'system': request.systemPrompt.trim(),
      'messages': turns,
      if (request.tools.isNotEmpty)
        'tools': [
          for (final tool in request.tools)
            {
              'name': tool.name,
              'description': tool.description,
              'input_schema': tool.parameters,
            },
        ],
      'stream': true,
    };
  }

  Map<String, dynamic> _headers(String? apiKey) {
    return {
      'Content-Type': 'application/json',
      'anthropic-version': '2023-06-01',
      if (apiKey != null && apiKey.trim().isNotEmpty)
        'x-api-key': apiKey.trim(),
    };
  }

  List<Map<String, dynamic>> _contentParts(
    List<PromptAssistantContentPart> parts,
  ) {
    return [
      for (final part in parts)
        if (part is PromptAssistantTextPart)
          {'type': 'text', 'text': part.text}
        else if (part is PromptAssistantImagePart)
          {
            'type': 'image',
            'source': {
              'type': 'base64',
              'media_type': part.mimeType,
              'data': base64Encode(part.bytes),
            },
          },
    ];
  }

  String _resolveMessagesEndpoint(ProviderConfig provider) {
    final base = normalizedBaseUrl(provider.baseUrl);
    if (base.endsWith('/messages')) {
      return base;
    }
    if (base.endsWith('/v1')) {
      return '$base/messages';
    }
    return '$base/v1/messages';
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

  String _extractResponseContent(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final content = raw['content'];
      if (content is List) {
        return content.map(contentToText).where((e) => e.isNotEmpty).join();
      }
    }
    return contentToText(raw);
  }

  static const _errorToolImagePlaceholder =
      '(image attached after the tool results)';

  static List<Map<String, dynamic>> _replaceErrorToolImagesWithPlaceholder(
    List<ToolResultContent> content,
  ) {
    final result = <Map<String, dynamic>>[];
    var previousWasPlaceholder = false;
    for (final block in content) {
      if (block is ToolResultImageContent) {
        if (!previousWasPlaceholder) {
          result.add({'type': 'text', 'text': _errorToolImagePlaceholder});
        }
        previousWasPlaceholder = true;
      } else if (block is ToolResultTextContent) {
        if (block.text.trim().isNotEmpty) {
          result.add({'type': 'text', 'text': block.text});
          previousWasPlaceholder = block.text == _errorToolImagePlaceholder;
        }
      }
    }
    return result;
  }

  static Map<String, dynamic>? _encodeAnthropicImage(ImageContent image) {
    if (image.source.base64Data case final data?) {
      return {
        'type': 'image',
        'source': {
          'type': 'base64',
          'media_type': image.source.mimeType,
          'data': data,
        },
      };
    }
    if (image.source.url case final url?) {
      return {
        'type': 'image',
        'source': {'type': 'url', 'url': url},
      };
    }
    return null;
  }
}

class _AnthropicBlock {
  String id = '';
  String name = '';
  final StringBuffer args = StringBuffer();
  bool flushed = false;
}
