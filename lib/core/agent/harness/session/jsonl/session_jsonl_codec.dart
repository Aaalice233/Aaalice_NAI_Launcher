import 'dart:convert';

import '../../../agent_types.dart';
import '../../harness_messages.dart';

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
              AssistantTextContent() => {
                'type': 'text',
                'text': block.text,
                if (block.signature != null) 'signature': block.signature,
              },
              AssistantThinkingContent() => {
                'type': 'thinking',
                'thinking': block.thinking,
                if (block.signature != null) 'signature': block.signature,
              },
              ToolCallContent() => {
                'type': 'toolCall',
                'id': block.id,
                'name': block.name,
                'arguments': block.arguments,
                if (block.thoughtSignature != null)
                  'thoughtSignature': block.thoughtSignature,
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
            {
              'id': call.id,
              'name': call.name,
              'arguments': call.arguments,
              if (call.thoughtSignature != null)
                'thoughtSignature': call.thoughtSignature,
            },
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
      final details = _jsonCompatibleValue(message.details);
      return {
        'role': 'toolResult',
        'toolCallId': message.toolCallId,
        'toolName': message.toolName,
        'contentBlocks': [
          for (final block in message.content)
            switch (block) {
              ToolResultTextContent() => {'type': 'text', 'text': block.text},
              ToolResultImageContent() => {
                'type': 'image',
                if (block.image.source.url case final url?) 'url': url,
                if (block.image.source.mimeType case final mimeType?)
                  'mimeType': mimeType,
                if (block.image.source.base64Data case final base64?)
                  'base64': base64,
              },
            },
        ],
        // Legacy readers only understand the flattened textual result.
        'content': message.text,
        if (details != null) 'details': details,
        if (message.usage != null) 'usage': message.usage!.toJson(),
        if (message.addedToolNames != null)
          'addedToolNames': message.addedToolNames,
        'isError': message.isError,
        'timestamp': message.timestamp,
      };
    }
    if (message is HarnessCustomMessage) {
      final details = _jsonCompatibleValue(message.details);
      return {
        'role': 'custom',
        'customType': message.customType,
        'display': message.display,
        if (message.textContent case final text?) 'textContent': text,
        if (message.blockContent case final blocks?)
          'contentBlocks': [
            for (final block in blocks) _encodeUserContent(block),
          ],
        if (details != null) 'details': details,
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
          content: _decodeToolResultContent(value),
          details: value['details'],
          usage: decodeUsage(value['usage']),
          addedToolNames: (value['addedToolNames'] as List?)
              ?.whereType<String>()
              .toList(growable: false),
          isError: value['isError'] as bool? ?? false,
          timestamp: timestamp,
        );
      case 'custom':
        final customType = value['customType'];
        if (customType is! String || customType.isEmpty) return null;
        return HarnessCustomMessage(
          customType: customType,
          display: value['display'] as bool? ?? false,
          textContent: value['textContent'] as String?,
          blockContent: _decodeUserContent(value['contentBlocks']),
          details: value['details'],
          timestamp: timestamp,
        );
      default:
        return null;
    }
  }

  static Map<String, dynamic> _encodeUserContent(UserContent block) =>
      switch (block) {
        UserTextContent() => {'type': 'text', 'text': block.text},
        UserImageContent() => {
          'type': 'image',
          if (block.image.source.url case final url?) 'url': url,
          if (block.image.source.mimeType case final mimeType?)
            'mimeType': mimeType,
          if (block.image.source.base64Data case final base64?)
            'base64': base64,
        },
      };

  static List<UserContent>? _decodeUserContent(Object? value) {
    if (value is! List) return null;
    return [
      for (final block in value)
        if (block is Map<String, dynamic>)
          switch (block['type']) {
            'text' => UserTextContent(block['text'] as String? ?? ''),
            'image' when block['url'] is String => UserImageContent(
              ImageContent(
                source: ImageSource.url(url: block['url'] as String),
              ),
            ),
            'image'
                when block['mimeType'] is String && block['base64'] is String =>
              UserImageContent(
                ImageContent(
                  source: ImageSource.base64(
                    mimeType: block['mimeType'] as String,
                    base64Data: block['base64'] as String,
                  ),
                ),
              ),
            _ => null,
          },
    ].whereType<UserContent>().toList(growable: false);
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
              'text' => AssistantTextContent(
                item['text'] as String? ?? '',
                signature: item['signature'] as String?,
              ),
              'thinking' => AssistantThinkingContent(
                item['thinking'] as String? ?? '',
                signature: item['signature'] as String?,
              ),
              'toolCall' => ToolCallContent(
                id: item['id'] as String? ?? '',
                name: item['name'] as String? ?? '',
                arguments:
                    (item['arguments'] as Map?)?.cast<String, dynamic>() ??
                    const {},
                thoughtSignature: item['thoughtSignature'] as String?,
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
            thoughtSignature: call['thoughtSignature'] as String?,
          ),
    ];
  }

  static List<ToolResultContent> _decodeToolResultContent(
    Map<String, dynamic> value,
  ) {
    final blocks = value['contentBlocks'];
    if (blocks is List) {
      return [
        for (final block in blocks)
          if (block is Map<String, dynamic>)
            switch (block['type']) {
              'text' => ToolResultTextContent(block['text'] as String? ?? ''),
              'image' when block['url'] is String => ToolResultImageContent(
                ImageContent(
                  source: ImageSource.url(url: block['url'] as String),
                ),
              ),
              'image'
                  when block['mimeType'] is String &&
                      block['base64'] is String =>
                ToolResultImageContent(
                  ImageContent(
                    source: ImageSource.base64(
                      mimeType: block['mimeType'] as String,
                      base64Data: block['base64'] as String,
                    ),
                  ),
                ),
              _ => null,
            },
      ].whereType<ToolResultContent>().toList(growable: false);
    }
    return [
      if (value['content'] case final String text when text.isNotEmpty)
        ToolResultTextContent(text),
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

  static Object? _jsonCompatibleValue(Object? value) {
    if (value == null) return null;
    try {
      return jsonDecode(jsonEncode(value));
    } catch (_) {
      return null;
    }
  }
}
