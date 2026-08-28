import 'dart:convert';

import 'agent_chat_resource_reference.dart';
import 'agent_chat_resource_reference_validator.dart';

/// A MIME body paired with the exact content type required by the protocol.
final class AgentChatResourceMimePayload {
  const AgentChatResourceMimePayload({
    required this.mimeType,
    required this.body,
  });

  final String mimeType;
  final String body;
}

/// Strict JSON, MIME, and URI encoding for [AgentChatResourceReference].
abstract final class AgentChatResourceReferenceCodec {
  static const String mediaType =
      'application/vnd.aaalice.agent-chat-resource+json';
  static const String mimeType = '$mediaType; version=1';
  static const String uriScheme = 'aaalice-agent-resource';

  static const Set<String> _topLevelFields = {
    'version',
    'kind',
    'source',
    'resourceId',
    'mediaId',
    'display',
    'provenance',
  };
  static const Set<String> _requiredFields = {
    'version',
    'kind',
    'source',
    'resourceId',
  };

  static Map<String, Object> encodeJsonMap(
    AgentChatResourceReference reference,
  ) {
    AgentChatResourceReferenceValidator.validate(reference);
    return {
      'version': reference.version,
      'kind': reference.kind.name,
      'source': reference.source,
      'resourceId': reference.resourceId,
      if (reference.mediaId case final mediaId?) 'mediaId': mediaId,
      if (reference.display.isNotEmpty) 'display': reference.display,
      if (reference.provenance.isNotEmpty) 'provenance': reference.provenance,
    };
  }

  static String encodeJson(AgentChatResourceReference reference) {
    final payload = jsonEncode(encodeJsonMap(reference));
    AgentChatResourceReferenceValidator.validatePayloadSize(payload);
    return payload;
  }

  static AgentChatResourceReference decodeJson(String payload) {
    AgentChatResourceReferenceValidator.validatePayloadSize(payload);
    final Object? decoded;
    try {
      decoded = jsonDecode(payload);
    } on FormatException catch (error) {
      throw FormatException('Invalid resource reference JSON: $error');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Resource reference must be a JSON object');
    }
    return decodeJsonMap(decoded);
  }

  static AgentChatResourceReference decodeJsonMap(Map<String, dynamic> json) {
    AgentChatResourceReferenceValidator.rejectUnsupportedJsonValue(json);
    final unknownFields = json.keys.toSet().difference(_topLevelFields);
    if (unknownFields.isNotEmpty) {
      throw FormatException(
        'Unknown resource reference fields: ${unknownFields.join(', ')}',
      );
    }
    final missingFields = _requiredFields.difference(json.keys.toSet());
    if (missingFields.isNotEmpty) {
      throw FormatException(
        'Missing resource reference fields: ${missingFields.join(', ')}',
      );
    }

    final version = _requireInt(json, 'version');
    if (version != AgentChatResourceReference.currentVersion) {
      throw FormatException('Unsupported resource reference version: $version');
    }
    final kindName = _requireString(json, 'kind');
    final kind = AgentChatResourceKind.values
        .where((candidate) => candidate.name == kindName)
        .firstOrNull;
    if (kind == null) {
      throw FormatException('Unsupported resource reference kind: $kindName');
    }

    final reference = AgentChatResourceReference(
      version: version,
      kind: kind,
      source: _requireString(json, 'source'),
      resourceId: _requireString(json, 'resourceId'),
      mediaId: _optionalString(json, 'mediaId'),
      display: _optionalStringMap(json, 'display'),
      provenance: _optionalStringMap(json, 'provenance'),
    );
    AgentChatResourceReferenceValidator.validate(reference);
    AgentChatResourceReferenceValidator.validatePayloadSize(
      jsonEncode(encodeJsonMap(reference)),
    );
    return reference;
  }

  static AgentChatResourceMimePayload encodeMime(
    AgentChatResourceReference reference,
  ) {
    return AgentChatResourceMimePayload(
      mimeType: mimeType,
      body: encodeJson(reference),
    );
  }

  static AgentChatResourceReference decodeMime({
    required String mimeType,
    required String body,
  }) {
    _validateMimeType(mimeType);
    return decodeJson(body);
  }

  static Uri encodeUri(AgentChatResourceReference reference) {
    final uri = Uri(
      scheme: uriScheme,
      host: 'v${reference.version}',
      queryParameters: {'payload': encodeJson(reference)},
    );
    if (uri.toString().length >
        AgentChatResourceReferenceValidator.maxPayloadBytes) {
      throw const FormatException('Resource reference URI is too large');
    }
    return uri;
  }

  static AgentChatResourceReference decodeUri(Object value) {
    final uri = switch (value) {
      Uri() => value,
      String() => Uri.tryParse(value),
      _ => null,
    };
    if (uri == null ||
        uri.scheme != uriScheme ||
        uri.host != 'v${AgentChatResourceReference.currentVersion}' ||
        uri.path.isNotEmpty ||
        uri.hasFragment ||
        uri.hasPort ||
        uri.userInfo.isNotEmpty ||
        uri.queryParametersAll.keys.length != 1 ||
        uri.queryParametersAll.keys.single != 'payload' ||
        uri.queryParametersAll['payload']?.length != 1) {
      throw const FormatException('Invalid resource reference URI');
    }
    if (uri.toString().length >
        AgentChatResourceReferenceValidator.maxPayloadBytes) {
      throw const FormatException('Resource reference URI is too large');
    }
    return decodeJson(uri.queryParameters['payload']!);
  }

  static void _validateMimeType(String value) {
    final parts = value.split(';').map((part) => part.trim()).toList();
    if (parts.length != 2 ||
        parts.first.toLowerCase() != mediaType ||
        !RegExp(
          r'^version\s*=\s*1$',
          caseSensitive: false,
        ).hasMatch(parts.last)) {
      throw const FormatException('Unsupported resource reference MIME type');
    }
  }

  static String _requireString(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value is! String) {
      throw FormatException('$field must be a string');
    }
    return value;
  }

  static String? _optionalString(Map<String, dynamic> json, String field) {
    if (!json.containsKey(field)) return null;
    return _requireString(json, field);
  }

  static int _requireInt(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value is! int) {
      throw FormatException('$field must be an integer');
    }
    return value;
  }

  static Map<String, String> _optionalStringMap(
    Map<String, dynamic> json,
    String field,
  ) {
    if (!json.containsKey(field)) return const {};
    final value = json[field];
    if (value is! Map<String, dynamic>) {
      throw FormatException('$field must be a JSON object');
    }
    final result = <String, String>{};
    for (final entry in value.entries) {
      if (entry.value is! String) {
        throw FormatException('$field.${entry.key} must be a string');
      }
      result[entry.key] = entry.value as String;
    }
    return result;
  }
}
