import '../../../agent_types.dart';

/// Codec for message payloads nested in session entries and records.
abstract final class SessionJsonlCodec {
  static Map<String, dynamic> encode(AgentMessage message) {
    if (message is UserMessage) {
      return {
        'role': 'user',
        'text': message.text,
        'images': [
          for (final image in message.images)
            {
              'mimeType': image.source.mimeType,
              'base64': image.source.base64Data,
            },
        ],
        'timestamp': message.timestamp,
      };
    }
    if (message is AssistantMessage) {
      return {
        'role': 'assistant',
        'content': [
          for (final block in message.content)
            switch (block) {
              AssistantTextContent() => {'type': 'text', 'text': block.text},
              AssistantThinkingContent() => {
                'type': 'thinking',
                'thinking': block.thinking,
              },
              ToolCallContent() => {
                'type': 'toolCall',
                'id': block.id,
                'name': block.name,
                'arguments': block.arguments,
              },
            },
        ],
        // Retain legacy fields so older clients can still open new sessions.
        'text': message.text,
        'thinking': [
          for (final block in message.content)
            if (block is AssistantThinkingContent) block.thinking,
        ],
        'toolCalls': [
          for (final call in message.toolCalls)
            {'id': call.id, 'name': call.name, 'arguments': call.arguments},
        ],
        'stopReason': message.stopReason.name,
        'errorMessage': message.errorMessage,
        'usage': message.usage?.toJson(),
        'provider': message.provider,
        'model': message.model,
        'timestamp': message.timestamp,
      };
    }
    if (message is ToolResultMessage) {
      return {
        'role': 'toolResult',
        'toolCallId': message.toolCallId,
        'toolName': message.toolName,
        'content': message.text,
        'isError': message.isError,
        'timestamp': message.timestamp,
      };
    }
    return {'role': message.role, 'timestamp': message.timestamp};
  }

  static AgentMessage? decode(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final timestamp =
        (value['timestamp'] as num?)?.toInt() ??
        DateTime.now().millisecondsSinceEpoch;
    switch (value['role']) {
      case 'user':
        return UserMessage(
          content: [
            if (value['text'] case final String text when text.isNotEmpty)
              UserTextContent(text),
            for (final image in value['images'] as List? ?? const [])
              if (image is Map<String, dynamic> &&
                  image['mimeType'] is String &&
                  image['base64'] is String)
                UserImageContent(
                  ImageContent(
                    source: ImageSource.base64(
                      mimeType: image['mimeType'] as String,
                      base64Data: image['base64'] as String,
                    ),
                  ),
                ),
          ],
          timestamp: timestamp,
        );
      case 'assistant':
        return AssistantMessage(
          content: _decodeAssistantContent(value),
          stopReason: StopReason.values.firstWhere(
            (reason) => reason.name == value['stopReason'],
            orElse: () => StopReason.stop,
          ),
          errorMessage: value['errorMessage'] as String?,
          usage: decodeUsage(value['usage']),
          provider: value['provider'] as String?,
          model: value['model'] as String?,
          timestamp: timestamp,
        );
      case 'toolResult':
        return ToolResultMessage(
          toolCallId: value['toolCallId'] as String? ?? '',
          toolName: value['toolName'] as String? ?? '',
          content: [
            if (value['content'] case final String text when text.isNotEmpty)
              ToolResultTextContent(text),
          ],
          isError: value['isError'] as bool? ?? false,
          timestamp: timestamp,
        );
      default:
        return null;
    }
  }

  static List<AssistantContent> _decodeAssistantContent(
    Map<String, dynamic> value,
  ) {
    final content = value['content'];
    if (content is List) {
      return [
        for (final item in content)
          if (item is Map<String, dynamic>)
            switch (item['type']) {
              'text' => AssistantTextContent(item['text'] as String? ?? ''),
              'thinking' => AssistantThinkingContent(
                item['thinking'] as String? ?? '',
              ),
              'toolCall' => ToolCallContent(
                id: item['id'] as String? ?? '',
                name: item['name'] as String? ?? '',
                arguments:
                    (item['arguments'] as Map?)?.cast<String, dynamic>() ??
                    const {},
              ),
              _ => null,
            },
      ].whereType<AssistantContent>().toList();
    }
    return [
      if (value['text'] case final String text when text.isNotEmpty)
        AssistantTextContent(text),
      for (final thinking in value['thinking'] as List? ?? const [])
        if (thinking is String) AssistantThinkingContent(thinking),
      for (final call in value['toolCalls'] as List? ?? const [])
        if (call is Map<String, dynamic>)
          ToolCallContent(
            id: call['id'] as String? ?? '',
            name: call['name'] as String? ?? '',
            arguments:
                (call['arguments'] as Map?)?.cast<String, dynamic>() ??
                const {},
          ),
    ];
  }

  static Usage? decodeUsage(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final cost = value['cost'];
    return Usage(
      input: (value['input'] as num?)?.toInt() ?? 0,
      output: (value['output'] as num?)?.toInt() ?? 0,
      cacheRead: (value['cacheRead'] as num?)?.toInt() ?? 0,
      cacheWrite: (value['cacheWrite'] as num?)?.toInt() ?? 0,
      totalTokens: (value['totalTokens'] as num?)?.toInt() ?? 0,
      cost: cost is Map<String, dynamic>
          ? Cost(
              input: (cost['input'] as num?)?.toDouble() ?? 0,
              output: (cost['output'] as num?)?.toDouble() ?? 0,
              cacheRead: (cost['cacheRead'] as num?)?.toDouble() ?? 0,
              cacheWrite: (cost['cacheWrite'] as num?)?.toDouble() ?? 0,
              total: (cost['total'] as num?)?.toDouble() ?? 0,
            )
          : const Cost(),
    );
  }
}
