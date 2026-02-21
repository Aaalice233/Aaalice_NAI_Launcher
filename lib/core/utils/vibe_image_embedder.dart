import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/vibe/vibe_reference.dart';
import 'app_logger.dart';

/// Vibe 图片嵌入器
///
/// 用于在 PNG 图片中嵌入和提取 Vibe 元数据的工具类。
///
/// 支持两种格式：
/// - NAI 官方 iTXt 格式（naidata 关键字）- 用于 bundle 多 vibe 嵌入
/// - Legacy tEXt 格式（naiv4vibe 关键字）- 向后兼容
///
/// ## Isolate 执行
///
/// 所有涉及 PNG 解析和 chunk 操作的方法都使用 Isolate 执行，
/// 避免在主线程进行耗时的二进制数据处理，防止 UI 卡顿：
///
/// - [embedVibesToImage] - 使用 [_embedVibesIsolate] 在 Isolate 中构建 PNG chunks
/// - [extractVibeFromImage] - 使用 [_extractVibesFromImageIsolate] 在 Isolate 中解析 PNG
///
/// Isolate 方法命名约定：
/// - 以 `ForIsolate` 结尾的辅助方法（如 [_parsePngChunksForIsolate]）
///   可在 Isolate 中安全调用，不依赖 Flutter 主线程
/// - 以 `_Isolate` 结尾的入口方法（如 [_embedVibesIsolate]）
///   作为 compute() 的入口点在 Isolate 中执行
///
/// ## 使用示例
///
/// ```dart
/// // 嵌入 vibes 到图片
/// final result = await VibeImageEmbedder.embedVibesToImage(
///   imageBytes,
///   [vibeReference1, vibeReference2],
/// );
///
/// // 从图片提取 vibes
/// final ({List<VibeReference> vibes, bool isBundle}) = await
///     VibeImageEmbedder.extractVibeFromImage(imageBytes);
/// ```
class VibeImageEmbedder {
  static const List<int> _pngSignature = <int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  ];

  static const String _vibeKeyword = 'naiv4vibe';
  static const String _metadataType = 'naiv4vibe';
  static const String _naiDataKeyword = 'naidata';
  static const String _itxtChunkType = 'iTXt';
  static const String _textChunkType = 'tEXt';
  static const String _idatChunkType = 'IDAT';
  static const String _iendChunkType = 'IEND';

  static const int _minPngSize = 20; // 8 (signature) + 12 (minimum chunk)
  static const int _chunkHeaderSize = 12; // 4 (length) + 4 (type) + 4 (crc)
  static const Duration _embedTimeout = Duration(seconds: 10);
  static const Duration _extractTimeout = Duration(seconds: 10);

  /// 嵌入单个 Vibe 到图片（保持向后兼容）
  static Future<Uint8List> embedVibeToImage(
    Uint8List imageBytes,
    VibeReference vibeReference, {
    String? thumbnailBase64,
  }) async {
    return embedVibesToImage(imageBytes, [vibeReference]);
  }

  /// 嵌入多个 Vibes 到图片（bundle 格式）
  ///
  /// 使用 Isolate 执行 PNG 解析和 chunk 构建，避免阻塞 UI 线程
  static Future<Uint8List> embedVibesToImage(
    Uint8List imageBytes,
    List<VibeReference> vibeReferences,
  ) async {
    if (vibeReferences.isEmpty) {
      throw ArgumentError('At least one vibe reference is required');
    }

    try {
      // 将 VibeReference 转换为可序列化的数据
      final vibesData = vibeReferences
          .map((ref) => _vibeReferenceToData(ref))
          .toList();

      final params = _EmbedVibesParams(
        imageBytes: imageBytes,
        vibeReferencesData: vibesData,
      );

      // 使用 compute() 在 Isolate 中执行嵌入操作，添加超时保护
      return await compute(_embedVibesIsolate, params)
          .timeout(_embedTimeout);
    } on TimeoutException {
      AppLogger.w('[VibeImageEmbedder] Vibe embedding timeout', 'VibeImageEmbedder');
      throw VibeEmbedException('Vibe embedding operation timed out');
    } on InvalidImageFormatException {
      rethrow;
    } on VibeEmbedException {
      rethrow;
    } catch (e, stack) {
      AppLogger.e('Error embedding vibes to image', e, stack, 'VibeImageEmbedder');
      throw VibeEmbedException('Failed to embed vibes: $e');
    }
  }

  /// Isolate entry point for vibe embedding
  ///
  /// 静态方法，用于在 Isolate 中执行 vibe 嵌入逻辑
  /// 包含 PNG chunk 构建和 iTXt chunk 生成逻辑
  static Uint8List _embedVibesIsolate(_EmbedVibesParams params) {
    try {
      // 验证 PNG 格式
      if (!_hasValidPngSignature(params.imageBytes)) {
        throw InvalidImageFormatException(
          'Only valid PNG images are supported for vibe metadata embedding',
        );
      }

      // 解析 PNG chunks
      final chunks = _parsePngChunksForIsolate(params.imageBytes);

      // 将序列化数据转换回 VibeReference 对象
      final vibeReferences = params.vibeReferencesData
          .map((data) => _vibeDataToReference(data))
          .toList();

      // 构建 NAI vibe bundle 数据
      final naiData = _buildNaiVibeBundleDataForIsolate(vibeReferences);
      final naiDataBase64 = base64.encode(utf8.encode(jsonEncode(naiData)));

      // 构建 iTXt chunk
      final vibeChunk = _buildITxtChunkForIsolate(_naiDataKeyword, naiDataBase64);

      // 重新组装 PNG 文件
      final builder = BytesBuilder(copy: false)..add(_pngSignature);
      var idatFound = false;

      for (final chunk in chunks) {
        if (chunk.type == _idatChunkType && !idatFound) {
          builder.add(vibeChunk);
          idatFound = true;
        }

        if (!_isVibeChunkForIsolate(chunk)) {
          builder.add(chunk.rawBytes);
        }
      }

      if (!idatFound) {
        throw VibeEmbedException('PNG image is missing IDAT chunk');
      }

      return builder.toBytes();
    } on InvalidImageFormatException {
      rethrow;
    } on VibeEmbedException {
      rethrow;
    } catch (e) {
      AppLogger.w('[Isolate] Vibe embedding error: $e', 'VibeImageEmbedder');
      throw VibeEmbedException('Failed to embed vibes in isolate: $e');
    }
  }

  /// Isolate-safe PNG chunk parsing
  static List<_PngChunk> _parsePngChunksForIsolate(Uint8List bytes) {
    if (bytes.length < _minPngSize) {
      throw InvalidImageFormatException('PNG data is too short');
    }

    final chunks = <_PngChunk>[];
    final byteData = ByteData.sublistView(bytes);
    var offset = _pngSignature.length;

    while (offset + _chunkHeaderSize <= bytes.length) {
      final dataLength = byteData.getUint32(offset, Endian.big);
      final typeStart = offset + 4;
      final dataStart = typeStart + 4;
      final dataEnd = dataStart + dataLength;
      final crcEnd = dataEnd + 4;

      if (crcEnd > bytes.length) {
        throw InvalidImageFormatException('Invalid PNG chunk length');
      }

      final chunkType = ascii.decode(bytes.sublist(typeStart, dataStart));

      chunks.add(
        _PngChunk(
          type: chunkType,
          data: Uint8List.fromList(bytes.sublist(dataStart, dataEnd)),
          rawBytes: Uint8List.fromList(bytes.sublist(offset, crcEnd)),
        ),
      );

      if (chunkType == _iendChunkType) break;
      offset = crcEnd;
    }

    if (chunks.isEmpty || chunks.last.type != _iendChunkType) {
      throw InvalidImageFormatException('PNG is missing IEND chunk');
    }

    return chunks;
  }

  /// Isolate-safe vibe chunk check
  static bool _isVibeChunkForIsolate(_PngChunk chunk) {
    if (chunk.type == _textChunkType) {
      return _isVibeTextChunkForIsolate(chunk);
    }
    if (chunk.type == _itxtChunkType) {
      return _extractKeywordFromITxtForIsolate(chunk.data) == _naiDataKeyword;
    }
    return false;
  }

  /// Isolate-safe text chunk vibe check
  static bool _isVibeTextChunkForIsolate(_PngChunk chunk) {
    if (chunk.type != _textChunkType) return false;

    final separator = chunk.data.indexOf(0);
    if (separator <= 0) return false;

    final keyword = latin1.decode(chunk.data.sublist(0, separator));
    return keyword == _vibeKeyword;
  }

  /// Isolate-safe keyword extraction from iTXt
  static String? _extractKeywordFromITxtForIsolate(Uint8List data) {
    final nullPos = data.indexOf(0);
    if (nullPos <= 0) return null;
    return utf8.decode(data.sublist(0, nullPos));
  }

  /// Isolate-safe NAI vibe bundle data builder
  static Map<String, dynamic> _buildNaiVibeBundleDataForIsolate(
    List<VibeReference> references,
  ) {
    final now = DateTime.now().toIso8601String();
    final vibes = references.map((ref) {
      final thumbnailBase64 = ref.thumbnail != null
          ? base64.encode(ref.thumbnail!)
          : null;
      return {
        'identifier': 'novelai-vibe-transfer',
        'version': 1,
        'type': 'image',
        'image': thumbnailBase64 ?? '',
        'id': _generateVibeIdForIsolate(),
        'encodings': {'vibe': ref.vibeEncoding},
        'name': ref.displayName,
        'thumbnail': thumbnailBase64,
        'createdAt': now,
        'importInfo': {
          'source': 'nai_launcher',
          'importedAt': now,
        },
      };
    }).toList();

    return {
      'identifier': 'novelai-vibe-transfer-bundle',
      'version': 1,
      'vibes': vibes,
    };
  }

  /// Isolate-safe vibe ID generator
  static String _generateVibeIdForIsolate() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
  }

  /// Isolate-safe iTXt chunk builder
  ///
  /// iTXt structure: keyword\0compression_flag\0compression_method\0language\0translated_keyword\0text
  static Uint8List _buildITxtChunkForIsolate(String keyword, String text) {
    if (keyword.isEmpty || keyword.length > 79) {
      throw VibeEmbedException('PNG iTXt keyword must be 1-79 characters');
    }

    final keywordBytes = utf8.encode(keyword);
    final textBytes = utf8.encode(text);

    final builder = BytesBuilder(copy: false)
      ..add(keywordBytes)
      ..addByte(0) // null separator
      ..addByte(0) // compression flag (0 = uncompressed)
      ..addByte(0) // compression method (0 = deflate)
      ..addByte(0) // language tag (empty)
      ..addByte(0) // translated keyword (empty)
      ..add(textBytes);

    final chunkData = builder.toBytes();
    final chunkTypeBytes = ascii.encode(_itxtChunkType);
    final crcInput = Uint8List(chunkTypeBytes.length + chunkData.length)
      ..setRange(0, chunkTypeBytes.length, chunkTypeBytes)
      ..setRange(chunkTypeBytes.length, chunkTypeBytes.length + chunkData.length, chunkData);

    final out = BytesBuilder(copy: false);
    final lengthBytes = ByteData(4)..setUint32(0, chunkData.length, Endian.big);
    out.add(lengthBytes.buffer.asUint8List());
    out.add(chunkTypeBytes);
    out.add(chunkData);

    final crcBytes = ByteData(4)..setUint32(0, _crc32ForIsolate(crcInput), Endian.big);
    out.add(crcBytes.buffer.asUint8List());

    return out.toBytes();
  }

  /// Isolate-safe CRC32 calculation
  static int _crc32ForIsolate(List<int> bytes) {
    var crc = 0xFFFFFFFF;

    for (final byte in bytes) {
      var current = (crc ^ byte) & 0xFF;
      for (var bit = 0; bit < 8; bit++) {
        current = (current & 1) != 0
            ? 0xEDB88320 ^ (current >> 1)
            : current >> 1;
      }
      crc = ((crc >> 8) ^ current) & 0xFFFFFFFF;
    }

    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }

  /// Result of extracting vibes from image (using Isolate to avoid blocking UI)
  ///
  /// 使用 compute() 调用 Isolate 方法，避免在 UI 线程执行耗时的 PNG 解析操作
  static Future<({List<VibeReference> vibes, bool isBundle})> extractVibeFromImage(
    Uint8List imageBytes,
  ) async {
    try {
      // 使用 compute() 在 Isolate 中执行提取，避免阻塞 UI，添加超时保护
      final result = await compute(_extractVibesFromImageIsolate, imageBytes)
          .timeout(_extractTimeout);

      if (result == null) {
        throw NoVibeDataException(
          'No naiv4vibe or naidata metadata found in PNG',
        );
      }

      // 将序列化的结果转换回 VibeReference 对象
      final vibes = result.vibesData.map((data) {
        final vibeRef = _vibeDataToReference(data);
        // 如果没有缩略图，使用原始图片
        return vibeRef.thumbnail == null
            ? vibeRef.copyWith(thumbnail: imageBytes)
            : vibeRef;
      }).toList();

      return (vibes: vibes, isBundle: result.isBundle);
    } on TimeoutException {
      AppLogger.w('[VibeImageEmbedder] Vibe extraction timeout', 'VibeImageEmbedder');
      throw VibeExtractException('Vibe extraction operation timed out');
    } on NoVibeDataException {
      rethrow;
    } on InvalidImageFormatException {
      rethrow;
    } catch (e, stack) {
      AppLogger.e('Error extracting vibe from image', e, stack, 'VibeImageEmbedder');
      throw VibeExtractException('Failed to extract vibe: $e');
    }
  }

  /// Isolate entry point for vibe extraction
  ///
  /// 静态方法，用于在 Isolate 中执行 vibe 提取逻辑
  /// 返回序列化的 [_ExtractVibeResult]，确保数据可在 Isolate 间传递
  static _ExtractVibeResult? _extractVibesFromImageIsolate(Uint8List imageBytes) {
    try {
      // 验证 PNG 格式
      if (!_hasValidPngSignature(imageBytes)) {
        throw InvalidImageFormatException(
          'Only valid PNG images can contain naiv4vibe metadata',
        );
      }

      // Try iTXt chunk first (NAI official format)
      final naiData = _extractNaiDataFromITxt(imageBytes);
      if (naiData != null) {
        final result = _parseNaiVibeData(naiData);
        // 将 VibeReference 转换为序列化数据
        return _ExtractVibeResult(
          vibesData: result.vibes.map(_vibeReferenceToData).toList(),
          isBundle: result.isBundle,
        );
      }

      // Try tEXt chunk (legacy format)
      final payloadJson = _extractVibeFromTextChunk(imageBytes);
      if (payloadJson != null && payloadJson.trim().isNotEmpty) {
        final payload = _decodeMetadataPayload(payloadJson);
        final vibe = _payloadToVibeReference(payload);
        // 在 Isolate 中返回序列化数据，不包含原始图片字节
        return _ExtractVibeResult(
          vibesData: [_vibeReferenceToData(vibe)],
          isBundle: false,
        );
      }

      return null;
    } on InvalidImageFormatException {
      rethrow;
    } catch (e) {
      AppLogger.w('[Isolate] Vibe extraction error: $e', 'VibeImageEmbedder');
      return null;
    }
  }

  /// 从 PNG tEXt chunk 中提取 legacy vibe 元数据
  static String? _extractVibeFromTextChunk(Uint8List imageBytes) {
    try {
      final byteData = ByteData.sublistView(imageBytes);
      var offset = _pngSignature.length;

      while (offset + _chunkHeaderSize <= imageBytes.length) {
        final dataLength = byteData.getUint32(offset, Endian.big);
        final typeStart = offset + 4;
        final dataStart = typeStart + 4;
        final dataEnd = dataStart + dataLength;
        final crcEnd = dataEnd + 4;

        if (crcEnd > imageBytes.length) break;

        final chunkType = ascii.decode(imageBytes.sublist(typeStart, dataStart));

        if (chunkType == _textChunkType) {
          final chunkData = imageBytes.sublist(dataStart, dataEnd);
          final separator = chunkData.indexOf(0);
          if (separator > 0) {
            final keyword = latin1.decode(chunkData.sublist(0, separator));
            if (keyword == _vibeKeyword) {
              final text = latin1.decode(chunkData.sublist(separator + 1));
              return text;
            }
          }
        }

        if (chunkType == _iendChunkType) break;
        offset = crcEnd;
      }
    } catch (e) {
      AppLogger.w('Error extracting from tEXt chunk: $e', 'VibeImageEmbedder');
    }
    return null;
  }

  /// 将 VibeReference 转换为可序列化的 Map
  static Map<String, dynamic> _vibeReferenceToData(VibeReference vibe) {
    return {
      'displayName': vibe.displayName,
      'vibeEncoding': vibe.vibeEncoding,
      'thumbnail': vibe.thumbnail, // Uint8List 可以跨 Isolate 传递
      'strength': vibe.strength,
      'infoExtracted': vibe.infoExtracted,
      'sourceType': vibe.sourceType.name,
    };
  }

  /// 将序列化的 Map 转换回 VibeReference
  static VibeReference _vibeDataToReference(Map<String, dynamic> data) {
    return VibeReference(
      displayName: data['displayName'] as String,
      vibeEncoding: data['vibeEncoding'] as String,
      thumbnail: data['thumbnail'] as Uint8List?,
      strength: data['strength'] as double,
      infoExtracted: data['infoExtracted'] as double,
      sourceType: VibeSourceType.values.firstWhere(
        (t) => t.name == data['sourceType'],
        orElse: () => VibeSourceType.png,
      ),
    );
  }

  static Map<String, dynamic>? _extractNaiDataFromITxt(Uint8List imageBytes) {
    if (!_hasValidPngSignature(imageBytes)) return null;

    final byteData = ByteData.sublistView(imageBytes);
    var offset = _pngSignature.length;

    while (offset + _chunkHeaderSize <= imageBytes.length) {
      final dataLength = byteData.getUint32(offset, Endian.big);
      final typeStart = offset + 4;
      final dataStart = typeStart + 4;
      final dataEnd = dataStart + dataLength;
      final crcEnd = dataEnd + 4;

      if (crcEnd > imageBytes.length) break;

      final chunkType = ascii.decode(imageBytes.sublist(typeStart, dataStart));

      if (chunkType == _itxtChunkType) {
        final chunkData = imageBytes.sublist(dataStart, dataEnd);
        final result = _parseITxtChunk(chunkData);
        if (result != null && result['keyword'] == _naiDataKeyword) {
          return result['data'] as Map<String, dynamic>?;
        }
      }

      if (chunkType == _iendChunkType) break;
      offset = crcEnd;
    }

    return null;
  }

  static bool _hasValidPngSignature(Uint8List bytes) {
    if (bytes.length < _pngSignature.length) return false;
    for (var i = 0; i < _pngSignature.length; i++) {
      if (bytes[i] != _pngSignature[i]) return false;
    }
    return true;
  }

  /// iTXt structure: keyword\0compression_flag\0compression_method\0language\0translated_keyword\0text
  static Map<String, dynamic>? _parseITxtChunk(Uint8List data) {
    try {
      final keywordEnd = data.indexOf(0);
      if (keywordEnd <= 0) return null;

      final keyword = utf8.decode(data.sublist(0, keywordEnd));
      var offset = keywordEnd + 1;

      if (offset + 2 > data.length) return null;

      final compressionFlag = data[offset];
      offset += 2; // Skip compression flag and method

      // Skip language tag and translated keyword
      for (var i = 0; i < 2; i++) {
        final end = data.indexOf(0, offset);
        if (end < 0) return null;
        offset = end + 1;
      }

      final textBytes = data.sublist(offset);
      final text = compressionFlag == 1
          ? utf8.decode(const ZLibDecoder().decodeBytes(textBytes))
          : utf8.decode(textBytes);

      final decoded = base64.decode(text);
      final jsonData = jsonDecode(utf8.decode(decoded)) as Map<String, dynamic>;

      return {'keyword': keyword, 'data': jsonData};
    } catch (e) {
      AppLogger.w('Failed to parse iTXt chunk: $e', 'VibeImageEmbedder');
      return null;
    }
  }

  static ({List<VibeReference> vibes, bool isBundle}) _parseNaiVibeData(
    Map<String, dynamic> naiData,
  ) {
    final identifier = naiData['identifier'] as String?;

    if (identifier == 'novelai-vibe-transfer-bundle') {
      final vibes = naiData['vibes'] as List<dynamic>?;
      if (vibes == null || vibes.isEmpty) {
        throw VibeExtractException('NAI vibe bundle contains no vibes');
      }
      final parsedVibes = vibes
          .map((v) => _parseNaiSingleVibe(v as Map<String, dynamic>))
          .toList();
      return (vibes: parsedVibes, isBundle: true);
    }

    if (identifier == 'novelai-vibe-transfer') {
      final vibe = _parseNaiSingleVibe(naiData);
      return (vibes: [vibe], isBundle: false);
    }

    throw VibeExtractException('Unknown NAI data identifier: $identifier');
  }

  static VibeReference _parseNaiSingleVibe(Map<String, dynamic> vibe) {
    final name = vibe['name'] as String? ?? 'vibe';
    final encoding = _extractEncodingFromVibe(vibe);
    final thumbnail = _extractThumbnailFromVibe(vibe);

    return VibeReference(
      displayName: name,
      vibeEncoding: encoding,
      thumbnail: thumbnail,
      strength: 0.6,
      infoExtracted: 1.0,
      sourceType: VibeSourceType.png,
    );
  }

  /// 从 vibe 数据中提取缩略图
  static Uint8List? _extractThumbnailFromVibe(Map<String, dynamic> vibe) {
    try {
      // 记录 vibe 中的可用字段，用于调试
      AppLogger.d('Vibe fields: ${vibe.keys.toList()}', 'VibeImageEmbedder');

      final thumbnailBase64 = vibe['thumbnail'] as String?;
      if (thumbnailBase64 != null && thumbnailBase64.isNotEmpty) {
        AppLogger.d('Found thumbnail field, length: ${thumbnailBase64.length}', 'VibeImageEmbedder');
        final base64Data = _extractBase64FromDataUri(thumbnailBase64);
        if (base64Data != null) {
          return base64.decode(base64Data);
        }
      }

      // 如果没有 thumbnail 字段，尝试从 image 字段提取
      final imageBase64 = vibe['image'] as String?;
      if (imageBase64 != null && imageBase64.isNotEmpty) {
        AppLogger.d('Found image field, length: ${imageBase64.length}', 'VibeImageEmbedder');
        final base64Data = _extractBase64FromDataUri(imageBase64);
        if (base64Data != null) {
          return base64.decode(base64Data);
        }
      }

      AppLogger.w('No thumbnail or image field found in vibe data', 'VibeImageEmbedder');
    } catch (e) {
      AppLogger.w('Failed to extract thumbnail from vibe: $e', 'VibeImageEmbedder');
    }
    return null;
  }

  /// 从 Data URI 中提取 base64 数据
  /// 格式: data:image/jpeg;base64,/9j/4AAQSkZJRgABAQ...
  static String? _extractBase64FromDataUri(String dataUri) {
    if (dataUri.startsWith('data:')) {
      final commaIndex = dataUri.indexOf(',');
      if (commaIndex != -1 && commaIndex < dataUri.length - 1) {
        return dataUri.substring(commaIndex + 1);
      }
    }
    // 如果不是 Data URI 格式，假设是纯 base64
    return dataUri;
  }

  /// Extract encoding from nested encodings structure
  /// Format: {model: {hash: {encoding: "..."}}}
  static String _extractEncodingFromVibe(Map<String, dynamic> vibe) {
    final encodings = vibe['encodings'];
    if (encodings is! Map<String, dynamic>) return '';

    final firstModel = encodings.values.firstOrNull;
    if (firstModel is! Map<String, dynamic>) return '';

    final firstHash = firstModel.values.firstOrNull;
    if (firstHash is! Map<String, dynamic>) return '';

    return firstHash['encoding'] as String? ?? '';
  }

  static Map<String, dynamic> _decodeMetadataPayload(String payloadJson) {
    try {
      final dynamic decoded = jsonDecode(payloadJson);
      if (decoded is! Map<String, dynamic>) {
        throw VibeExtractException('Vibe metadata payload is not a JSON object');
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
    final dataRaw = payload['data'];
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
    final thumbnail = _extractThumbnailFromPayload(dataRaw);

    return VibeReference(
      displayName: displayName,
      vibeEncoding: vibeEncoding,
      thumbnail: thumbnail,
      strength: strength,
      infoExtracted: infoExtracted,
      sourceType: sourceType,
    );
  }

  /// 从 legacy payload 数据中提取缩略图
  static Uint8List? _extractThumbnailFromPayload(Map<String, dynamic> dataRaw) {
    try {
      final thumbnailBase64 = dataRaw['thumbnail'] as String?;
      if (thumbnailBase64 != null && thumbnailBase64.isNotEmpty) {
        return base64.decode(thumbnailBase64);
      }
    } catch (e) {
      AppLogger.w('Failed to extract thumbnail from payload: $e', 'VibeImageEmbedder');
    }
    return null;
  }

  static double _parseDouble(Object? value, double defaultValue) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  static VibeSourceType _parseSourceType(Object? value, String vibeEncoding) {
    if (value is String) {
      for (final type in VibeSourceType.values) {
        if (type.name == value) return type;
      }
    }
    return vibeEncoding.isNotEmpty
        ? VibeSourceType.png
        : VibeSourceType.rawImage;
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

/// Embed vibes parameters (for Isolate)
///
/// 用于在 Isolate 中传递 embedVibesToImage 的参数
/// 包含 imageBytes 和可序列化的 vibeReferences 数据
class _EmbedVibesParams {
  final Uint8List imageBytes;
  final List<Map<String, dynamic>> vibeReferencesData;

  _EmbedVibesParams({
    required this.imageBytes,
    required this.vibeReferencesData,
  });
}

/// Extract vibe result (serializable for Isolate)
class _ExtractVibeResult {
  final List<Map<String, dynamic>> vibesData;
  final bool isBundle;

  _ExtractVibeResult({
    required this.vibesData,
    required this.isBundle,
  });
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
