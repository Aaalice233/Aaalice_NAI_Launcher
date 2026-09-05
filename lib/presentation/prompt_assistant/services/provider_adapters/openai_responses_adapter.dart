import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/agent/agent_types.dart';
import '../../models/agent_protocol.dart';
import '../../models/prompt_assistant_models.dart';
import 'agent_wire_helpers.dart';
import 'openai_chat_completions_adapter.dart';
import 'prompt_assistant_adapter.dart';
import 'reasoning_payload.dart';

class OpenAiResponsesAdapter extends PromptAssistantProviderAdapter {
  const OpenAiResponsesAdapter();

  @override
  Future<List<String>> fetchModels({
    required Dio dio,
    required ProviderConfig provider,
    required String? apiKey,
  }) {
    return const OpenAiChatCompletionsAdapter().fetchModels(
      dio: dio,
      provider: provider,
      apiKey: apiKey,
    );
  }

  @override
  Future<String> complete({
    required Dio dio,
    required PromptAssistantRequest request,
    required CancelToken cancelToken,
  }) async {
    final headers = <String, dynamic>{'Content-Type': 'application/json'};
    if (request.apiKey != null && request.apiKey!.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${request.apiKey!.trim()}';
    }

    final response = await dio.post<dynamic>(
      _resolveEndpoint(request.provider),
      data: {
        'model': request.model,
        'stream': false,
        'instructions': request.systemPrompt,
        if (responsesReasoningEffort(request.reasoningRequest, null)
            case final effort?)
          'reasoning': {'effort': effort},
        if (request.maxOutputTokens case final count?)
          'max_output_tokens': count,
        if (request.responseFormat == PromptAssistantResponseFormat.jsonObject)
          'text': {
            'format': {'type': 'json_object'},
          },
        'input': [
          {'role': 'user', 'content': _inputParts(request.userParts)},
        ],
      },
      options: Options(
        headers: headers,
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: request.responseTimeout,
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
    final pending = <AgentWireEvent>[];
    var stopReason = StopReason.stop;
    Usage? usage;
    var sawError = false;
    var sawTerminalEvent = false;
    final emittedToolCalls = <String>{};
    final reasoningIdsByOutput = <int, String>{};
    final reasoningItems = <String, Map<String, dynamic>>{};
    final reasoningTextSeen = <String>{};
    String? activeReasoningId;

    final parser = AgentSseParser(
      onEvent: (event, data) {
        final json = parseSseJson(data);
        if (json == null) {
          return;
        }
        switch (event) {
          case 'response.output_text.delta':
            final delta = json['delta'];
            if (delta is String && delta.isNotEmpty) {
              pending.add(AgentWireTextDelta(delta));
            }
          case 'response.output_item.added':
            final item = json['item'];
            final outputIndex = (json['output_index'] as num?)?.toInt();
            if (item is Map<String, dynamic> &&
                item['type'] == 'reasoning' &&
                outputIndex != null &&
                item['id'] is String) {
              reasoningIdsByOutput[outputIndex] = item['id'] as String;
              activeReasoningId = item['id'] as String;
            }
          case 'response.reasoning_summary_text.delta':
          case 'response.reasoning_text.delta':
            final delta = json['delta'];
            final outputIndex = (json['output_index'] as num?)?.toInt();
            final itemId =
                json['item_id'] as String? ??
                (outputIndex == null
                    ? activeReasoningId
                    : reasoningIdsByOutput[outputIndex] ??
                          'reasoning-output-$outputIndex');
            if (delta is String && delta.isNotEmpty) {
              if (itemId != null) reasoningTextSeen.add(itemId);
              pending.add(AgentWireThinkingDelta(delta, itemId: itemId));
            }
          case 'response.output_item.done':
            final item = json['item'];
            if (item is Map<String, dynamic> && item['type'] == 'reasoning') {
              final itemId = item['id'] as String? ?? '';
              final outputIndex = (json['output_index'] as num?)?.toInt();
              if (outputIndex != null && itemId.isNotEmpty) {
                reasoningIdsByOutput[outputIndex] = itemId;
              }
              if (itemId.isNotEmpty) activeReasoningId = itemId;
              final summaryText = _responseReasoningText(item['summary']);
              final contentText = _responseReasoningText(item['content']);
              final completeText = summaryText.isNotEmpty
                  ? summaryText
                  : contentText;
              if (!reasoningTextSeen.contains(itemId)) {
                pending.add(
                  AgentWireThinkingDelta(completeText, itemId: itemId),
                );
                reasoningTextSeen.add(itemId);
              }
              reasoningItems[itemId] = Map<String, dynamic>.from(item);
              pending.add(
                AgentWireThinkingSignature(
                  jsonEncode(item),
                  itemId: itemId,
                  replace: true,
                ),
              );
            } else if (item is Map<String, dynamic> &&
                item['type'] == 'function_call') {
              final callId = item['call_id'] as String? ?? '';
              if (emittedToolCalls.add(callId)) {
                pending.add(
                  AgentWireToolCallDone(
                    id: callId,
                    name: item['name'] as String? ?? '',
                    arguments: parseToolArguments(item['arguments'] as String?),
                  ),
                );
                stopReason = StopReason.toolUse;
              }
            }
          case 'response.completed':
            sawTerminalEvent = true;
            final response = json['response'];
            if (response is Map<String, dynamic>) {
              final output = response['output'];
              if (output is List) {
                for (final rawItem in output) {
                  if (rawItem is! Map<String, dynamic> ||
                      rawItem['type'] != 'reasoning' ||
                      rawItem['id'] is! String) {
                    continue;
                  }
                  final itemId = rawItem['id'] as String;
                  final stored = reasoningItems[itemId];
                  final merged = <String, dynamic>{
                    if (stored != null) ...stored,
                    ...rawItem,
                  };
                  if (!reasoningTextSeen.contains(itemId)) {
                    final summaryText = _responseReasoningText(
                      merged['summary'],
                    );
                    final contentText = _responseReasoningText(
                      merged['content'],
                    );
                    pending.add(
                      AgentWireThinkingDelta(
                        summaryText.isNotEmpty ? summaryText : contentText,
                        itemId: itemId,
                      ),
                    );
                    reasoningTextSeen.add(itemId);
                  }
                  reasoningItems[itemId] = merged;
                  pending.add(
                    AgentWireThinkingSignature(
                      jsonEncode(merged),
                      itemId: itemId,
                      replace: true,
                    ),
                  );
                }
              }
              final usageRaw = response['usage'];
              if (usageRaw is Map<String, dynamic>) {
                usage = Usage(
                  input: (usageRaw['input_tokens'] as num?)?.toInt() ?? 0,
                  output: (usageRaw['output_tokens'] as num?)?.toInt() ?? 0,
                  totalTokens: (usageRaw['total_tokens'] as num?)?.toInt() ?? 0,
                );
              }
            }
          case 'response.incomplete':
            sawTerminalEvent = true;
            stopReason = StopReason.length;
          case 'response.failed':
          case 'error':
            sawTerminalEvent = true;
            sawError = true;
            final error = json;
            final response = error['response'];
            Map<String, dynamic>? errorBody;
            if (response is Map<String, dynamic>) {
              final inner = response['error'];
              if (inner is Map<String, dynamic>) {
                errorBody = inner;
              }
            }
            final direct = error['error'];
            if (errorBody == null && direct is Map<String, dynamic>) {
              errorBody = direct;
            }
            final message =
                errorBody?['message'] as String? ??
                'LLM stream failed with event $event';
            pending.add(
              AgentWireError('LLM service returned an error: $message'),
            );
          default:
            break;
        }
      },
    );

    try {
      final stream = agentStreamPost(
        dio,
        endpoint: _resolveEndpoint(request.provider),
        payload: _buildAgentPayload(request),
        headers: _agentHeaders(request.apiKey),
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
    if (!sawTerminalEvent) {
      yield const AgentWireError(
        'OpenAI Responses stream ended before its terminal event.',
      );
      return;
    }
    yield AgentWireFinish(stopReason: stopReason, usage: usage);
  }

  Map<String, dynamic> _buildAgentPayload(AgentChatRequest request) {
    final input = <Map<String, dynamic>>[];
    for (final message in request.messages) {
      if (message is UserMessage) {
        final images = inlineImagesOf(message);
        input.add({
          'type': 'message',
          'role': 'user',
          'content': [
            if (message.text.trim().isNotEmpty)
              {'type': 'input_text', 'text': message.text},
            for (final image in images)
              {
                'type': 'input_image',
                'image_url':
                    'data:${image.mimeType};base64,${base64Encode(image.bytes)}',
                'detail': 'auto',
              },
          ],
        });
      } else if (message is AssistantMessage) {
        for (final block in message.content) {
          switch (block) {
            case AssistantThinkingContent()
                when message.provider == request.provider.id &&
                    message.model == request.model &&
                    block.signature?.isNotEmpty == true:
              final item = _decodeReasoningItem(block.signature!);
              if (item != null) input.add(item);
            case AssistantTextContent() when block.text.isNotEmpty:
              input.add({
                'type': 'message',
                'role': 'assistant',
                'content': [
                  {'type': 'output_text', 'text': block.text},
                ],
              });
            case ToolCallContent():
              input.add({
                'type': 'function_call',
                'call_id': block.id,
                'name': block.name,
                'arguments': jsonEncode(block.arguments),
              });
            default:
              break;
          }
        }
      } else if (message is ToolResultMessage) {
        input.add({
          'type': 'function_call_output',
          'call_id': message.toolCallId,
          'output': message.text,
        });
        final images = toolResultImagesOf(message);
        if (images.isNotEmpty) {
          input.add({
            'type': 'message',
            'role': 'user',
            'content': [
              {
                'type': 'input_text',
                'text': 'Visual output returned by ${message.toolName}.',
              },
              for (final image in images)
                if (_openAiImageUrl(image) case final url?)
                  {'type': 'input_image', 'image_url': url, 'detail': 'auto'},
            ],
          });
        }
      }
    }

    final reasoning = request.reasoningRequest;
    final effort = responsesReasoningEffort(reasoning, request.reasoning);
    return {
      'model': request.model,
      'stream': true,
      'store': false,
      if (request.effectiveMaxOutputTokens case final maxTokens?)
        'max_output_tokens': maxTokens < 16 ? 16 : maxTokens,
      if (effort != null) 'reasoning': {'effort': effort, 'summary': 'auto'},
      if (reasoning?.api == AgentReasoningApi.openAiResponses &&
          (reasoning!.enabled || reasoning.alwaysIncludeEncryptedReasoning))
        'include': ['reasoning.encrypted_content'],
      if (request.systemPrompt.trim().isNotEmpty)
        'instructions': request.systemPrompt.trim(),
      'input': input,
      if (request.tools.isNotEmpty)
        'tools': [
          for (final tool in request.tools)
            {
              'type': 'function',
              'name': tool.name,
              'description': tool.description,
              'parameters': tool.parameters,
            },
        ],
    };
  }

  Map<String, dynamic>? _decodeReasoningItem(String signature) {
    try {
      final value = jsonDecode(signature);
      return value is Map<String, dynamic> ? value : null;
    } on FormatException {
      return null;
    }
  }

  static String _responseReasoningText(dynamic value) {
    if (value is! List) return '';
    return value
        .whereType<Map<String, dynamic>>()
        .map((item) => item['text'])
        .whereType<String>()
        .join('\n\n');
  }

  String? _openAiImageUrl(ImageContent image) {
    if (image.source.url case final url?) return url;
    final data = image.source.base64Data;
    final mimeType = image.source.mimeType;
    if (data == null || mimeType == null) return null;
    return 'data:$mimeType;base64,$data';
  }

  Map<String, dynamic> _agentHeaders(String? apiKey) {
    return {
      'Content-Type': 'application/json',
      if (apiKey != null && apiKey.trim().isNotEmpty)
        'Authorization': 'Bearer ${apiKey.trim()}',
    };
  }

  List<Map<String, dynamic>> _inputParts(
    List<PromptAssistantContentPart> parts,
  ) {
    return [
      for (final part in parts)
        if (part is PromptAssistantTextPart)
          {'type': 'input_text', 'text': part.text}
        else if (part is PromptAssistantImagePart)
          {
            'type': 'input_image',
            'image_url': imageDataUri(part),
            'detail': 'auto',
          },
    ];
  }

  String _resolveEndpoint(ProviderConfig provider) {
    final base = normalizedBaseUrl(provider.baseUrl);
    if (base.endsWith('/responses')) {
      return base;
    }
    if (base.endsWith('/v1')) {
      return '$base/responses';
    }
    return '$base/v1/responses';
  }

  String _extractResponseContent(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final error = extractErrorMessage(raw);
      if (error != null) {
        throw StateError('LLM service returned an error: $error');
      }
      final outputText = contentToText(raw['output_text']);
      if (outputText.isNotEmpty) return outputText;

      final output = raw['output'];
      if (output is List) {
        final parts = <String>[];
        for (final item in output) {
          if (item is Map<String, dynamic> && item['type'] == 'message') {
            final content = item['content'];
            if (content is List) {
              for (final part in content) {
                parts.add(contentToText(part));
              }
            } else {
              parts.add(contentToText(content));
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
