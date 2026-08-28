import 'dart:convert';
import 'dart:typed_data';

import 'agent_chat_resource_reference.dart';

/// Applies the size and safety boundary for Agent chat resource references.
abstract final class AgentChatResourceReferenceValidator {
  static const int maxPayloadBytes = 8 * 1024;
  static const int maxSourceLength = 64;
  static const int maxIdentifierLength = 256;
  static const int maxMetadataEntries = 8;
  static const int maxMetadataKeyLength = 32;
  static const int maxMetadataValueLength = 256;

  static final RegExp _sourcePattern = RegExp(
    r'^[A-Za-z][A-Za-z0-9._-]{0,63}$',
  );
  static final RegExp _identifierPattern = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9._:@+-]{0,255}$',
  );
  static final RegExp _metadataKeyPattern = RegExp(
    r'^[A-Za-z][A-Za-z0-9._-]{0,31}$',
  );
  static final RegExp _windowsAbsolutePath = RegExp(r'^[A-Za-z]:[\\/]');
  static final RegExp _longBase64 = RegExp(
    r'^(?:[A-Za-z0-9+/]{4}){16,}(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$',
  );

  static void validate(AgentChatResourceReference reference) {
    if (reference.version != AgentChatResourceReference.currentVersion) {
      throw FormatException(
        'Unsupported resource reference version: ${reference.version}',
      );
    }
    _validateSource(reference.source);
    _validateIdentifier('resourceId', reference.resourceId);
    if (reference.mediaId case final mediaId?) {
      _validateIdentifier('mediaId', mediaId);
    }
    _validateMetadata('display', reference.display);
    _validateMetadata('provenance', reference.provenance);
  }

  static void validatePayloadSize(String payload) {
    final byteLength = utf8.encode(payload).length;
    if (byteLength > maxPayloadBytes) {
      throw const FormatException(
        'Resource reference payload exceeds $maxPayloadBytes bytes',
      );
    }
  }

  static void rejectUnsupportedJsonValue(Object? value, [String path = r'$']) {
    if (value is Uint8List || value is ByteBuffer || value is ByteData) {
      throw FormatException('Binary data is not allowed at $path');
    }
    if (value is List) {
      throw FormatException('Lists and byte payloads are not allowed at $path');
    }
    if (value is Map) {
      for (final entry in value.entries) {
        if (entry.key is! String) {
          throw FormatException('Non-string JSON key at $path');
        }
        rejectUnsupportedJsonValue(entry.value, '$path.${entry.key}');
      }
    }
  }

  static void _validateSource(String source) {
    if (source.length > maxSourceLength || !_sourcePattern.hasMatch(source)) {
      throw const FormatException('source must be a short source identifier');
    }
    _rejectLocationOrEmbeddedData('source', source);
  }

  static void _validateIdentifier(String name, String value) {
    if (value.length > maxIdentifierLength ||
        !_identifierPattern.hasMatch(value)) {
      throw FormatException('$name must be a stable opaque identifier');
    }
    _rejectLocationOrEmbeddedData(name, value);
  }

  static void _validateMetadata(String name, Map<String, String> metadata) {
    if (metadata.length > maxMetadataEntries) {
      throw FormatException('$name has too many entries');
    }
    for (final entry in metadata.entries) {
      if (entry.key.length > maxMetadataKeyLength ||
          !_metadataKeyPattern.hasMatch(entry.key)) {
        throw FormatException('$name contains an invalid key');
      }
      if (entry.value.isEmpty ||
          entry.value.length > maxMetadataValueLength ||
          entry.value.contains(RegExp(r'[\u0000-\u001F\u007F]'))) {
        throw FormatException('$name.${entry.key} has an invalid value');
      }
      _rejectLocationOrEmbeddedData('$name.${entry.key}', entry.value);
    }
  }

  static void _rejectLocationOrEmbeddedData(String name, String value) {
    final normalized = value.trim();
    final lower = normalized.toLowerCase();
    final uri = Uri.tryParse(normalized);
    final hasUrlScheme =
        uri != null &&
        uri.hasScheme &&
        const {
          'http',
          'https',
          'file',
          'ftp',
          'data',
        }.contains(uri.scheme.toLowerCase());
    final pathSegments = normalized.split(RegExp(r'[\\/]'));
    final hasTraversal = pathSegments.any((segment) => segment == '..');
    final isAbsolutePath =
        normalized.startsWith('/') ||
        normalized.startsWith(r'\') ||
        _windowsAbsolutePath.hasMatch(normalized);
    final looksEmbedded =
        lower.startsWith('data:') ||
        lower.contains(';base64,') ||
        _longBase64.hasMatch(normalized);

    if (hasUrlScheme || hasTraversal || isAbsolutePath || looksEmbedded) {
      throw FormatException('$name must not contain a path, URL, or data');
    }
  }
}
