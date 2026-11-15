import 'dart:convert';
import 'dart:typed_data';

import '../../../core/agent/agent_types.dart';
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';

List<Uint8List> extractToolResultInlineImages(ToolResultMessage result) => [
  for (final content in result.content)
    if (content is ToolResultImageContent && content.image.source.bytes != null)
      content.image.source.bytes!,
];

List<String> extractToolResultRemoteImages(ToolResultMessage result) => [
  for (final content in result.content)
    if (content is ToolResultImageContent && content.image.source.url != null)
      content.image.source.url!,
];

List<AgentChatResourceReference> extractToolResultResourceReferences(
  ToolResultMessage result,
) {
  final references = <AgentChatResourceReference>[];
  final seen = <String>{};

  void collect(Object? value) {
    if (value is Map) {
      final resource = value['resource_ref'];
      if (resource is Map) {
        try {
          final encoded = Map<String, dynamic>.from(resource);
          final key = jsonEncode(encoded);
          if (seen.add(key)) {
            references.add(
              AgentChatResourceReferenceCodec.decodeJsonMap(encoded),
            );
          }
        } on FormatException {
          // Ignore malformed resource metadata from external tools.
        }
      }
      for (final child in value.values) {
        collect(child);
      }
    } else if (value is List) {
      for (final child in value) {
        collect(child);
      }
    }
  }

  collect(result.details);
  for (final content in result.content.whereType<ToolResultTextContent>()) {
    try {
      collect(jsonDecode(content.text));
    } on FormatException {
      // Tool output may be ordinary text.
    }
  }
  return references;
}

List<String> extractToolResultImageFiles(ToolResultMessage result) {
  final details = result.details;
  if (details is Map && details['files'] is List) {
    final files = [
      for (final file in details['files'] as List)
        if (file is String) file,
    ];
    if (files.isNotEmpty) return files;
  }
  for (final content in result.content) {
    if (content is! ToolResultTextContent) continue;
    final text = content.text.trim();
    if (!text.startsWith('{')) continue;
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map && decoded['images'] is List) {
        return [
          for (final image in decoded['images'] as List)
            if (image is Map && image['file'] is String)
              image['file'] as String,
        ];
      }
    } catch (_) {
      // Tool output may be ordinary text rather than a persisted JSON report.
    }
  }
  return const [];
}
