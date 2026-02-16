import 'dart:convert';

import '../../data/models/vibe/vibe_reference.dart';

class VibeEncodingUtils {
  static const String _type = 'naiv4vibe';
  static const String _version = '1.0';

  static const String _encodingJson = 'json';
  static const String _encodingBase64 = 'base64';
  static const String _encodingBase64Url = 'base64url';

  static const int _maxPayloadLength = 2 * 1024 * 1024;

  static String encodeToJson(VibeReference vibe) {
    final payload = _buildPayload(vibe, encoding: _encodingJson);
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  static String encodeToBase64(VibeReference vibe) {
    final payload = _buildPayload(vibe, encoding: _encodingBase64);
    final jsonString = jsonEncode(payload);
    return base64Encode(utf8.encode(jsonString));
  }

  static String encodeToUrlSafeBase64(VibeReference vibe) {
    final payload = _buildPayload(vibe, encoding: _encodingBase64Url);
    final jsonString = jsonEncode(payload);
    final encoded = base64UrlEncode(utf8.encode(jsonString));
    return encoded.replaceAll('=', '');
  }

  static VibeReference decode(String encoded) {
    try {
      final payload = _parsePayload(encoded);
      final data = _asMap(payload['data'], fieldName: 'data');

      final displayName = _parseName(data);
      final vibeEncoding = _parseVibeEncoding(data);
      final strength = _parseDouble(data['strength'], 0.6)
          .clamp(0.0, 1.0)
          .toDouble();
      final infoExtracted = _parseDouble(data['infoExtracted'], 0.7)
          .clamp(0.0, 1.0)
          .toDouble();
      final sourceType = _parseSourceType(data['sourceType'], vibeEncoding);

      return VibeReference(
        displayName: displayName,
        vibeEncoding: vibeEncoding,
        strength: strength,
        infoExtracted: infoExtracted,
        sourceType: sourceType,
      );
    } on VibeEncodingException {
      rethrow;
    } on FormatException catch (e) {
      throw VibeEncodingException('Invalid vibe payload: ${e.message}');
    } catch (e) {
      throw VibeEncodingException('Failed to decode vibe payload: $e');
    }
  }

  static bool isVibeEncoding(String value) {
    try {
      _parsePayload(value);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Map<String, dynamic> _buildPayload(
    VibeReference vibe, {
    required String encoding,
  }) {
    if (vibe.displayName.trim().isEmpty) {
      throw VibeEncodingException('Vibe name cannot be empty');
    }

    if (vibe.vibeEncoding.isEmpty) {
      throw VibeEncodingException('Vibe encoding data is empty');
    }

    return <String, dynamic>{
      'version': _version,
      'type': _type,
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'encoding': encoding,
      'data': <String, dynamic>{
        'name': vibe.displayName,
        'strength': vibe.strength,
        'infoExtracted': vibe.infoExtracted,
        'vibeEncoding': vibe.vibeEncoding,
      },
    };
  }

  static Map<String, dynamic> _parsePayload(String rawValue) {
    final value = rawValue.trim();
    if (value.isEmpty) {
      throw VibeEncodingException('Vibe payload cannot be empty');
    }

    if (value.length > _maxPayloadLength) {
      throw VibeEncodingException('Vibe payload is too large');
    }

    final payloadFromJson = _tryParseJsonPayload(value);
    if (payloadFromJson != null) {
      return payloadFromJson;
    }

    final payloadFromBase64 = _tryParseBase64Payload(value);
    if (payloadFromBase64 != null) {
      return payloadFromBase64;
    }

    throw VibeEncodingException('Unsupported vibe payload format');
  }

  static Map<String, dynamic>? _tryParseJsonPayload(String value) {
    try {
      final payload = _asMap(jsonDecode(value), fieldName: 'payload');
      _validatePayload(payload);
      return payload;
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _tryParseBase64Payload(String value) {
    for (final decoded in _decodeBase64Candidates(value)) {
      final payload = _tryParseJsonPayload(decoded);
      if (payload != null) {
        return payload;
      }
    }
    return null;
  }

  static Iterable<String> _decodeBase64Candidates(String value) sync* {
    final normalized = _normalizeBase64Padding(value);
    final candidates = <String>{
      normalized,
      normalized.replaceAll('-', '+').replaceAll('_', '/'),
      normalized.replaceAll('+', '-').replaceAll('/', '_'),
    };

    for (final candidate in candidates) {
      try {
        yield utf8.decode(base64Decode(candidate));
      } catch (_) {
        // Keep trying other candidate forms.
      }

      try {
        yield utf8.decode(base64Url.decode(candidate));
      } catch (_) {
        // Keep trying other candidate forms.
      }
    }
  }

  static String _normalizeBase64Padding(String value) {
    final paddingNeeded = (4 - (value.length % 4)) % 4;
    return '$value${'=' * paddingNeeded}';
  }

  static void _validatePayload(Map<String, dynamic> payload) {
    final type = payload['type'];
    if (type != _type) {
      throw VibeEncodingException('Unexpected payload type: $type');
    }

    final version = payload['version'];
    if (version == null) {
      throw VibeEncodingException('Missing payload version');
    }

    final encoding = payload['encoding'] as String?;
    if (encoding != null &&
        encoding != _encodingJson &&
        encoding != _encodingBase64 &&
        encoding != _encodingBase64Url) {
      throw VibeEncodingException('Unsupported payload encoding: $encoding');
    }

    final data = _asMap(payload['data'], fieldName: 'data');
    _parseName(data);
    _parseVibeEncoding(data);
  }

  static Map<String, dynamic> _asMap(
    Object? value, {
    required String fieldName,
  }) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, dynamic mapValue) {
        return MapEntry(key.toString(), mapValue);
      });
    }
    throw VibeEncodingException('Expected JSON object for $fieldName');
  }

  static String _parseName(Map<String, dynamic> data) {
    final name = data['name'] ?? data['displayName'];
    if (name is String && name.trim().isNotEmpty) {
      return name;
    }
    throw VibeEncodingException('Missing vibe name');
  }

  static String _parseVibeEncoding(Map<String, dynamic> data) {
    final encoding = data['vibeEncoding'] ?? data['encoding'];
    if (encoding is String && encoding.isNotEmpty) {
      return encoding;
    }
    throw VibeEncodingException('Missing vibe encoding data');
  }

  static double _parseDouble(Object? value, double fallback) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  static VibeSourceType _parseSourceType(Object? value, String vibeEncoding) {
    if (value is String) {
      for (final sourceType in VibeSourceType.values) {
        if (sourceType.name == value) {
          return sourceType;
        }
      }
    }

    return vibeEncoding.isNotEmpty
        ? VibeSourceType.png
        : VibeSourceType.rawImage;
  }
}

class VibeEncodingException implements Exception {
  VibeEncodingException(this.message);

  final String message;

  @override
  String toString() => 'VibeEncodingException: $message';
}
