import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/agent/agent_types.dart';
import '../../models/agent_protocol.dart';
import '../../models/prompt_assistant_models.dart';
import 'agent_wire_helpers.dart';
import 'prompt_assistant_adapter.dart';

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
        'max_tokens': 2048,
        'system': request.systemPrompt,
        'messages': [
          {'role': 'user', 'content': _contentParts(request.userParts)},
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
    final payload = buildAgentPayload(request);
    final pending = <AgentWireEvent>[];

    // Anthropic SSE：content_block_start/delta/stop 组装内容块，
    // message_delta 携带 stop_reason 与输出用量。
    final blocks = <int, _AnthropicBlock>{};
    final blockOrder = <int>[];
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
            final error = json['error'];
            final message = error is Map<String, dynamic>
                ? error['message'] as String? ?? 'unknown error'
                : 'unknown error';
            pending.add(
              AgentWireError('LLM service returned an error: $message'),
            );
          case 'message_start':
            final message = json['message'];
            if (message is Map<String, dynamic>) {
              final usageRaw = message['usage'];
              if (usageRaw is Map<String, dynamic>) {
                usage = Usage(
                  input: (usageRaw['input_tokens'] as num?)?.toInt() ?? 0,
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
              pending.add(
                AgentWireToolCallDone(
                  id: block.id,
                  name: block.name,
                  arguments: parseToolArguments(block.args.toString()),
                ),
              );
            }
          case 'message_delta':
            final delta = json['delta'];
            if (delta is Map<String, dynamic>) {
              final reason = delta['stop_reason'];
              if (reason is String) {
                stopReason = switch (reason) {
                  'tool_use' => StopReason.toolUse,
                  'max_tokens' => StopReason.length,
                  _ => StopReason.stop,
                };
              }
            }
            final usageRaw = json['usage'];
            if (usageRaw is Map<String, dynamic>) {
              final output = (usageRaw['output_tokens'] as num?)?.toInt() ?? 0;
              usage = Usage(
                input: usage?.input ?? 0,
                output: output,
                totalTokens: (usage?.input ?? 0) + output,
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
      yield agentWireErrorFrom(error, request.provider);
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
      if (block != null && !block.flushed) {
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

    for (final message in request.messages) {
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
        for (final block in message.content) {
          switch (block) {
            case AssistantThinkingContent()
                when block.signature?.isNotEmpty == true:
              appendTurn('assistant', {
                'type': 'thinking',
                'thinking': block.thinking,
                'signature': block.signature,
              });
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
        final images = toolResultImagesOf(message);
        appendTurn('user', {
          'type': 'tool_result',
          'tool_use_id': message.toolCallId,
          'content': images.isEmpty
              ? message.text
              : [
                  if (message.text.trim().isNotEmpty)
                    {'type': 'text', 'text': message.text},
                  for (final image in images)
                    if (image.source.base64Data case final data?)
                      {
                        'type': 'image',
                        'source': {
                          'type': 'base64',
                          'media_type': image.source.mimeType,
                          'data': data,
                        },
                      }
                    else if (image.source.url case final url?)
                      {
                        'type': 'image',
                        'source': {'type': 'url', 'url': url},
                      },
                ],
          'is_error': message.isError,
        });
      }
    }

    final thinkingBudget = switch (request.reasoning) {
      'minimal' => 1024,
      'low' => 2048,
      'medium' => 4096,
      'high' => 8192,
      'xhigh' || 'max' => 16384,
      _ => null,
    };
    final maxTokens = request.maxOutputTokens ?? 4096;
    return {
      'model': request.model,
      'max_tokens': thinkingBudget == null
          ? maxTokens
          : maxTokens > thinkingBudget
          ? maxTokens
          : thinkingBudget + 4096,
      if (thinkingBudget != null)
        'thinking': {'type': 'enabled', 'budget_tokens': thinkingBudget},
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
      final error = extractErrorMessage(raw);
      if (error != null) {
        throw StateError('LLM service returned an error: $error');
      }
      final content = raw['content'];
      if (content is List) {
        return content.map(contentToText).where((e) => e.isNotEmpty).join();
      }
    }
    return contentToText(raw);
  }
}

class _AnthropicBlock {
  String id = '';
  String name = '';
  final StringBuffer args = StringBuffer();
  bool flushed = false;
}
