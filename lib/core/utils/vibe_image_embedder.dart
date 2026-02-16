import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../data/models/vibe/vibe_reference.dart';

class VibeImageEmbedder {
  static const List<int> _pngSignature = <int>[
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
  ];

  static const String _vibeKeyword = 'naiv4vibe';
  static const String _metadataType = 'naiv4vibe';
  static const String _metadataVersion = '1.0';

  static Future<Uint8List> embedVibeToImage(
    Uint8List imageBytes,
    VibeReference vibeReference,
  ) async {
    return Future<Uint8List>(() {
      try {
        _ensureValidPng(imageBytes);
        final chunks = _parsePngChunks(imageBytes);
        final payloadJson = _encodeMetadataPayload(
          _buildMetadataPayload(vibeReference),
        );
        final vibeChunk = _buildTextChunk(_vibeKeyword, payloadJson);

        final builder = BytesBuilder(copy: false)..add(_pngSignature);
        var hasImageData = false;
        var inserted = false;

        for (final chunk in chunks) {
          final isVibeTextChunk = _isVibeTextChunk(chunk);

          if (chunk.type == 'IDAT' && !inserted) {
            builder.add(vibeChunk);
            inserted = true;
          }

          if (chunk.type == 'IDAT') {
            hasImageData = true;
          }

          if (!isVibeTextChunk) {
            builder.add(chunk.rawBytes);
          }
        }

        if (!hasImageData) {
          throw VibeEmbedException('PNG image is missing IDAT chunk');
        }

        if (!inserted) {
          throw VibeEmbedException('Failed to insert naiv4vibe metadata chunk');
        }

        return builder.toBytes();
      } on InvalidImageFormatException {
        rethrow;
      } on VibeEmbedException {
        rethrow;
      } catch (e) {
        throw VibeEmbedException('Failed to embed vibe metadata: $e');
      }
    });
  }

  static Future<VibeReference> extractVibeFromImage(
    Uint8List imageBytes,
  ) async {
    return Future<VibeReference>(() {
      try {
        final decoder = img.PngDecoder();
        if (!decoder.isValidFile(imageBytes) ||
            decoder.startDecode(imageBytes) == null) {
          throw InvalidImageFormatException(
            'Only valid PNG images can contain naiv4vibe metadata',
          );
        }

        final payloadJson = decoder.info.textData[_vibeKeyword];
        if (payloadJson == null || payloadJson.trim().isEmpty) {
          throw NoVibeDataException(
            'No naiv4vibe metadata found in PNG tEXt chunks',
          );
        }

        final payload = _decodeMetadataPayload(payloadJson);
        return _payloadToVibeReference(payload);
      } on InvalidImageFormatException {
        rethrow;
      } on NoVibeDataException {
        rethrow;
      } on VibeExtractException {
        rethrow;
      } catch (e) {
        throw VibeExtractException('Failed to extract vibe metadata: $e');
      }
    });
  }

  /// 在 isolate 中提取 vibe 元数据
  ///
  /// 对于大文件或需要避免阻塞 UI 线程的场景，使用此方法
  static Future<VibeReference> extractVibeFromImageInIsolate(
    Uint8List imageBytes,
  ) async {
    return Isolate.run(() => extractVibeFromImage(imageBytes)).then((result) => result);
  }

  static void _ensureValidPng(Uint8List imageBytes) {
    final decoder = img.PngDecoder();
    if (!decoder.isValidFile(imageBytes) ||
        decoder.startDecode(imageBytes) == null) {
      throw InvalidImageFormatException(
        'Only valid PNG images are supported for vibe metadata embedding',
      );
    }
  }

  static List<_PngChunk> _parsePngChunks(Uint8List bytes) {
    if (bytes.length < _pngSignature.length + 12) {
      throw InvalidImageFormatException('PNG data is too short');
    }

    for (var i = 0; i < _pngSignature.length; i++) {
      if (bytes[i] != _pngSignature[i]) {
        throw InvalidImageFormatException('Invalid PNG signature');
      }
    }

    final chunkList = <_PngChunk>[];
    final byteData = ByteData.sublistView(bytes);
    var offset = _pngSignature.length;

    while (offset + 12 <= bytes.length) {
      final dataLength = byteData.getUint32(offset, Endian.big);
      final typeStart = offset + 4;
      final dataStart = typeStart + 4;
      final dataEnd = dataStart + dataLength;
      final crcEnd = dataEnd + 4;

      if (crcEnd > bytes.length) {
        throw InvalidImageFormatException('Invalid PNG chunk length');
      }

      final chunkType = ascii.decode(bytes.sublist(typeStart, dataStart));
      final chunkData = Uint8List.fromList(bytes.sublist(dataStart, dataEnd));
      final rawBytes = Uint8List.fromList(bytes.sublist(offset, crcEnd));

      chunkList.add(
        _PngChunk(
          type: chunkType,
          data: chunkData,
          rawBytes: rawBytes,
        ),
      );

      offset = crcEnd;

      if (chunkType == 'IEND') {
        break;
      }
    }

    if (chunkList.isEmpty || chunkList.last.type != 'IEND') {
      throw InvalidImageFormatException('PNG is missing IEND chunk');
    }

    return chunkList;
  }

  static bool _isVibeTextChunk(_PngChunk chunk) {
    if (chunk.type != 'tEXt') {
      return false;
    }

    final separator = chunk.data.indexOf(0);
    if (separator <= 0) {
      return false;
    }

    final keyword = latin1.decode(chunk.data.sublist(0, separator));
    return keyword == _vibeKeyword;
  }

  static Map<String, dynamic> _buildMetadataPayload(VibeReference reference) {
    return <String, dynamic>{
      'version': _metadataVersion,
      'type': _metadataType,
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'data': <String, dynamic>{
        'name': reference.displayName,
        'displayName': reference.displayName,
        'strength': reference.strength,
        'infoExtracted': reference.infoExtracted,
        'encoding': reference.vibeEncoding,
        'vibeEncoding': reference.vibeEncoding,
        'sourceType': reference.sourceType.name,
        'rawImagePath': null,
      },
    };
  }

  static String _encodeMetadataPayload(Map<String, dynamic> payload) {
    final rawJson = jsonEncode(payload);
    return _escapeNonAscii(rawJson);
  }

  static Map<String, dynamic> _decodeMetadataPayload(String payloadJson) {
    try {
      final dynamic decoded = jsonDecode(payloadJson);
      if (decoded is! Map<String, dynamic>) {
        throw VibeExtractException(
          'Vibe metadata payload is not a JSON object',
        );
      }

      final type = decoded['type'] as String?;
      if (type != _metadataType) {
        throw VibeExtractException('Unexpected metadata type: $type');
      }

      return decoded;
    } on FormatException catch (e) {
      throw VibeExtractException('Invalid vibe metadata JSON: ${e.message}');
    }
  }

  static VibeReference _payloadToVibeReference(Map<String, dynamic> payload) {
    final dynamic dataRaw = payload['data'];
    if (dataRaw is! Map<String, dynamic>) {
      throw VibeExtractException('Vibe metadata is missing data section');
    }

    final displayName =
        (dataRaw['displayName'] ?? dataRaw['name']) as String? ?? 'vibe';
    final vibeEncoding =
        (dataRaw['vibeEncoding'] ?? dataRaw['encoding']) as String? ?? '';

    final strength =
        _parseDouble(dataRaw['strength'], 0.6).clamp(0.0, 1.0).toDouble();
    final infoExtracted =
        _parseDouble(dataRaw['infoExtracted'], 0.7).clamp(0.0, 1.0).toDouble();
    final sourceType = _parseSourceType(dataRaw['sourceType'], vibeEncoding);

    return VibeReference(
      displayName: displayName,
      vibeEncoding: vibeEncoding,
      strength: strength,
      infoExtracted: infoExtracted,
      sourceType: sourceType,
    );
  }

  static double _parseDouble(Object? value, double defaultValue) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  static VibeSourceType _parseSourceType(Object? value, String vibeEncoding) {
    if (value is String) {
      for (final type in VibeSourceType.values) {
        if (type.name == value) {
          return type;
        }
      }
    }

    return vibeEncoding.isNotEmpty
        ? VibeSourceType.png
        : VibeSourceType.rawImage;
  }

  static Uint8List _buildTextChunk(String keyword, String text) {
    if (keyword.isEmpty || keyword.length > 79) {
      throw VibeEmbedException('PNG tEXt keyword must be 1-79 characters');
    }

    if (keyword.contains('\u0000')) {
      throw VibeEmbedException('PNG tEXt keyword cannot contain null bytes');
    }

    final keywordBytes = latin1.encode(keyword);
    final textBytes = latin1.encode(text);

    final chunkDataLength = keywordBytes.length + 1 + textBytes.length;
    final chunkData = Uint8List(chunkDataLength);

    chunkData.setRange(0, keywordBytes.length, keywordBytes);
    chunkData[keywordBytes.length] = 0;
    chunkData.setRange(keywordBytes.length + 1, chunkDataLength, textBytes);

    final chunkTypeBytes = ascii.encode('tEXt');
    final crcInput = Uint8List(chunkTypeBytes.length + chunkData.length)
      ..setRange(0, chunkTypeBytes.length, chunkTypeBytes)
      ..setRange(
        chunkTypeBytes.length,
        chunkTypeBytes.length + chunkData.length,
        chunkData,
      );

    final out = BytesBuilder(copy: false);

    final lengthBytes = ByteData(4)..setUint32(0, chunkData.length, Endian.big);
    out.add(lengthBytes.buffer.asUint8List());
    out.add(chunkTypeBytes);
    out.add(chunkData);

    final crcBytes = ByteData(4)..setUint32(0, _crc32(crcInput), Endian.big);
    out.add(crcBytes.buffer.asUint8List());

    return out.toBytes();
  }

  static int _crc32(List<int> bytes) {
    var crc = 0xFFFFFFFF;

    for (final byte in bytes) {
      var current = (crc ^ byte) & 0xFF;
      for (var bit = 0; bit < 8; bit++) {
        if ((current & 1) != 0) {
          current = 0xEDB88320 ^ (current >> 1);
        } else {
          current >>= 1;
        }
      }
      crc = ((crc >> 8) ^ current) & 0xFFFFFFFF;
    }

    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }

  static String _escapeNonAscii(String value) {
    final buffer = StringBuffer();

    for (final rune in value.runes) {
      if (rune <= 0x7F) {
        buffer.writeCharCode(rune);
        continue;
      }

      if (rune <= 0xFFFF) {
        buffer.write('\\u${_toHex4(rune)}');
        continue;
      }

      final codePoint = rune - 0x10000;
      final highSurrogate = 0xD800 + (codePoint >> 10);
      final lowSurrogate = 0xDC00 + (codePoint & 0x3FF);

      buffer
        ..write('\\u${_toHex4(highSurrogate)}')
        ..write('\\u${_toHex4(lowSurrogate)}');
    }

    return buffer.toString();
  }

  static String _toHex4(int value) {
    return value.toRadixString(16).padLeft(4, '0').toUpperCase();
  }
}

class VibeEmbedException implements Exception {
  VibeEmbedException(this.message);

  final String message;

  @override
  String toString() => 'VibeEmbedException: $message';
}

class VibeExtractException implements Exception {
  VibeExtractException(this.message);

  final String message;

  @override
  String toString() => 'VibeExtractException: $message';
}

class InvalidImageFormatException implements Exception {
  InvalidImageFormatException(this.message);

  final String message;

  @override
  String toString() => 'InvalidImageFormatException: $message';
}

class NoVibeDataException implements Exception {
  NoVibeDataException(this.message);

  final String message;

  @override
  String toString() => 'NoVibeDataException: $message';
}

class _PngChunk {
  const _PngChunk({
    required this.type,
    required this.data,
    required this.rawBytes,
  });

  final String type;
  final Uint8List data;
  final Uint8List rawBytes;
}
