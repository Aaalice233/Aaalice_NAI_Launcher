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
/// - 以 `_Isolate` 结尾的方法表示作为 compute() 的入口点
///   在 Isolate 中执行（如 [_embedVibesIsolate]）
/// - 普通命名的辅助方法也可以在 Isolate 中安全调用
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

  // 文件大小限制常量
  static const int _maxPngFileSize = 50 * 1024 * 1024; // 50MB
  static const int _maxCompressedSize = 5 * 1024 * 1024; // 5MB compressed limit
  static const int _maxDecompressedSize = 10 * 1024 * 1024; // 10MB for zlib
  static const int _maxBase64DecodedSize = 50 * 1024 * 1024; // 50MB decoded

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

    // 验证文件大小
    if (imageBytes.length > _maxPngFileSize) {
      throw InvalidImageFormatException(
        'PNG file size (${(imageBytes.length / 1024 / 1024).toStringAsFixed(1)}MB) '
        'exceeds maximum allowed size (${(_maxPngFileSize / 1024 / 1024).toStringAsFixed(0)}MB)',
      );
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
      final chunks = _parsePngChunks(params.imageBytes);

      // 将序列化数据转换回 VibeReference 对象
      final vibeReferences = params.vibeReferencesData
          .map((data) => _vibeDataToReference(data))
          .toList();

      // 构建 NAI vibe bundle 数据
      final naiData = _buildNaiVibeBundleData(vibeReferences);
      final naiDataBase64 = base64.encode(utf8.encode(jsonEncode(naiData)));

      // 构建 iTXt chunk
      final vibeChunk = _buildITxtChunk(_naiDataKeyword, naiDataBase64);

      // 重新组装 PNG 文件
      final builder = BytesBuilder(copy: false)..add(_pngSignature);
      var idatFound = false;

      for (final chunk in chunks) {
        if (chunk.type == _idatChunkType && !idatFound) {
          builder.add(vibeChunk);
          idatFound = true;
        }

        if (!_isVibeChunk(chunk)) {
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

  /// PNG chunk parsing (safe for Isolate use)
  static List<_PngChunk> _parsePngChunks(Uint8List bytes) {
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

  /// Check if chunk is a vibe chunk (safe for Isolate use)
  static bool _isVibeChunk(_PngChunk chunk) {
    if (chunk.type == _textChunkType) {
      return _isVibeTextChunk(chunk);
    }
    if (chunk.type == _itxtChunkType) {
      return _extractKeywordFromITxt(chunk.data) == _naiDataKeyword;
    }
    return false;
  }

  /// Check if text chunk contains vibe data (safe for Isolate use)
  static bool _isVibeTextChunk(_PngChunk chunk) {
    if (chunk.type != _textChunkType) return false;

    final separator = chunk.data.indexOf(0);
    if (separator <= 0) return false;

    final keyword = latin1.decode(chunk.data.sublist(0, separator));
    return keyword == _vibeKeyword;
  }

  /// Extract keyword from iTXt chunk (safe for Isolate use)
  static String? _extractKeywordFromITxt(Uint8List data) {
    final nullPos = data.indexOf(0);
    if (nullPos <= 0) return null;
    return utf8.decode(data.sublist(0, nullPos));
  }

  /// Build NAI vibe bundle data (safe for Isolate use)
  static Map<String, dynamic> _buildNaiVibeBundleData(
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
        'id': _generateVibeId(),
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

  /// Generate vibe ID (safe for Isolate use)
  static String _generateVibeId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
  }

  /// Build iTXt chunk (safe for Isolate use)
  ///
  /// iTXt structure: keyword\0compression_flag\0compression_method\0language\0translated_keyword\0text
  static Uint8List _buildITxtChunk(String keyword, String text) {
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

    final crcBytes = ByteData(4)..setUint32(0, _crc32(crcInput), Endian.big);
    out.add(crcBytes.buffer.asUint8List());

    return out.toBytes();
  }

  /// CRC32 calculation (PNG standard, safe for Isolate use)
  static int _crc32(List<int> data) {
    const table = [
      0x00000000, 0x77073096, 0xee0e612c, 0x990951ba, 0x076dc419, 0x706af48f, 0xe963a535, 0x9e6495a3,
      0x0edb8832, 0x79dcb8a4, 0xe0d5e91e, 0x97d2d988, 0x09b64c2b, 0x7eb17cbd, 0xe7b82d07, 0x90bf1d91,
      0x1db71064, 0x6ab020f2, 0xf3b97148, 0x84be41de, 0x1adad47d, 0x6ddde4eb, 0xf4d4b551, 0x83d385c7,
      0x136c9856, 0x646ba8c0, 0xfd62f97a, 0x8a65c9ec, 0x14015c4f, 0x63066cd9, 0xfa0f3d63, 0x8d080df5,
      0x3b6e20c8, 0x4c69105e, 0xd56041e4, 0xa2677172, 0x3c03e4d1, 0x4b04d447, 0xd20d85fd, 0xa50ab56b,
      0x35b5a8fa, 0x42b2986c, 0xdbbbc9d6, 0xacbcf940, 0x32d86ce3, 0x45df5c75, 0xdcd60dcf, 0xabd13d59,
      0x26d930ac, 0x51de003a, 0xc8d75180, 0xbfd06116, 0x21b4f4b5, 0x56b3c423, 0xcfba9599, 0xb8bda50f,
      0x2802b89e, 0x5f058808, 0xc60cd9b2, 0xb10be924, 0x2f6f7c87, 0x58684c11, 0xc1611dab, 0xb6662d3d,
      0x76dc4190, 0x01db7106, 0x98d220bc, 0xefd5102a, 0x71b18589, 0x06b6b51f, 0x9fbfe4a5, 0xe8b8d433,
      0x7807c9a2, 0x0f00f934, 0x9609a88e, 0xe10e9818, 0x7f6a0dbb, 0x086d3d2d, 0x91646c97, 0xe6635c01,
      0x6b6b51f4, 0x1c6c6162, 0x856530d8, 0xf262004e, 0x6c0695ed, 0x1b01a57b, 0x8208f4c1, 0xf50fc457,
      0x65b0d9c6, 0x12b7e950, 0x8bbeb8ea, 0xfcb9887c, 0x62dd1ddf, 0x15da2d49, 0x8cd37cf3, 0xfbd44c65,
      0x4db26158, 0x3ab551ce, 0xa3bc0074, 0xd4bb30e2, 0x4adfa541, 0x3dd895d7, 0xa4d1c46d, 0xd3d6f4fb,
      0x4369e96a, 0x346ed9fc, 0xad678846, 0xda60b8d0, 0x44042d73, 0x33031de5, 0xaa0a4c5f, 0xdd0d7cc9,
      0x5005713c, 0x270241aa, 0xbe0b1010, 0xc90c2086, 0x5768b525, 0x206f85b3, 0xb966d409, 0xce61e49f,
      0x5edef90e, 0x29d9c998, 0xb0d09822, 0xc7d7a8b4, 0x59b33d17, 0x2eb40d81, 0xb7bd5c3b, 0xc0ba6cad,
      0xedb88320, 0x9abfb3b6, 0x03b6e20c, 0x74b1d29a, 0xead54739, 0x9dd277af, 0x04db2615, 0x73dc1683,
      0xe3630b12, 0x94643b84, 0x0d6d6a3e, 0x7a6a5aa8, 0xe40ecf0b, 0x9309ff9d, 0x0a00ae27, 0x7d079eb1,
      0xf00f9344, 0x8708a3d2, 0x1e01f268, 0x6906c2fe, 0xf762575d, 0x806567cb, 0x196c3671, 0x6e6b06e7,
      0xfed41b76, 0x89d32be0, 0x10da7a5a, 0x67dd4acc, 0xf9b9df6f, 0x8ebeeff9, 0x17b7be43, 0x60b08ed5,
      0xd6d6a3e8, 0xa1d1937e, 0x38d8c2c4, 0x4fdff252, 0xd1bb67f1, 0xa6bc5767, 0x3fb506dd, 0x48b2364b,
      0xd80d2bda, 0xaf0a1b4c, 0x36034af6, 0x41047a60, 0xdf60efc3, 0xa867df55, 0x316e8eef, 0x4669be79,
      0xcb61b38c, 0xbc66831a, 0x256fd2a0, 0x5268e236, 0xcc0c7795, 0xbb0b4703, 0x220216b9, 0x5505262f,
      0xc5ba3bbe, 0xb2bd0b28, 0x2bb45a92, 0x5cb36a04, 0xc2d7ffa7, 0xb5d0cf31, 0x2cd99e8b, 0x5bdeae1d,
      0x9b64c2b0, 0xec63f226, 0x756aa39c, 0x026d930a, 0x9c0906a9, 0xeb0e363f, 0x72076785, 0x05005713,
      0x95bf4a82, 0xe2b87a14, 0x7bb12bae, 0x0cb61b38, 0x92d28e9b, 0xe5d5be0d, 0x7cdcefb7, 0x0bdbdf21,
      0x86d3d2d4, 0xf1d4e242, 0x68ddb3f8, 0x1fda836e, 0x81be16cd, 0xf6b9265b, 0x6fb077e1, 0x18b74777,
      0x88085ae6, 0xff0f6a70, 0x66063bca, 0x11010b5c, 0x8f659eff, 0xf862ae69, 0x616bffd3, 0x166ccf45,
      0xa00ae278, 0xd70dd2ee, 0x4e048354, 0x3903b3c2, 0xa7672661, 0xd06016f7, 0x4969474d, 0x3e6e77db,
      0xaed16a4a, 0xd9d65adc, 0x40df0b66, 0x37d83bf0, 0xa9bcae53, 0xdebb9ec5, 0x47b2cf7f, 0x30b5ffe9,
      0xbdbdf21c, 0xcabac28a, 0x53b39330, 0x24b4a3a6, 0xbad03605, 0xcdd70693, 0x54de5729, 0x23d967bf,
      0xb3667a2e, 0xc4614ab8, 0x5d681b02, 0x2a6f2b94, 0xb40bbe37, 0xc30c8ea1, 0x5a05df1b, 0x2d02ef8d,
    ];

    var crc = 0xffffffff;
    for (final byte in data) {
      crc = (crc >>> 8) ^ table[(crc ^ byte) & 0xff];
    }
    return crc ^ 0xffffffff;
  }

  /// Result of extracting vibes from image (using Isolate to avoid blocking UI)
  ///
  /// 使用 compute() 调用 Isolate 方法，避免在 UI 线程执行耗时的 PNG 解析操作
  static Future<({List<VibeReference> vibes, bool isBundle})> extractVibeFromImage(
    Uint8List imageBytes,
  ) async {
    // 验证文件大小
    if (imageBytes.length > _maxPngFileSize) {
      throw InvalidImageFormatException(
        'PNG file size (${(imageBytes.length / 1024 / 1024).toStringAsFixed(1)}MB) '
        'exceeds maximum allowed size (${(_maxPngFileSize / 1024 / 1024).toStringAsFixed(0)}MB)',
      );
    }

    try {
      // 使用 compute() 在 Isolate 中执行提取，避免阻塞 UI，添加超时保护
      final result = await compute(_extractVibesFromImageIsolate, imageBytes)
          .timeout(_extractTimeout);

      // 将序列化的结果转换回 VibeReference 对象
      // 安全注意：不再将原始 PNG 图片作为缩略图分配，以防止内存耗尽
      // 如果 vibe 数据中没有缩略图，保持为 null，由 UI 层处理默认显示
      final vibes = result.vibesData.map((data) {
        return _vibeDataToReference(data);
      }).toList();

      return (vibes: vibes, isBundle: result.isBundle);
    } on TimeoutException {
      AppLogger.w('[VibeImageEmbedder] Vibe extraction timeout', 'VibeImageEmbedder');
      throw VibeExtractException('Vibe extraction operation timed out');
    } on NoVibeDataException {
      rethrow;
    } on InvalidImageFormatException {
      rethrow;
    } on VibeExtractException {
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
  static _ExtractVibeResult _extractVibesFromImageIsolate(Uint8List imageBytes) {
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

      throw NoVibeDataException(
        'No naiv4vibe or naidata metadata found in PNG',
      );
    } on InvalidImageFormatException {
      rethrow;
    } on NoVibeDataException {
      rethrow;
    } on VibeExtractException {
      rethrow;
    } catch (e) {
      // 将未知异常包装为 VibeExtractException，保留原始错误信息
      AppLogger.w('[Isolate] Vibe extraction error: $e', 'VibeImageEmbedder');
      throw VibeExtractException('Failed to extract vibe: $e');
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

        if (crcEnd > imageBytes.length) {
          throw InvalidImageFormatException('Invalid PNG chunk length in tEXt');
        }

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
      if (e is InvalidImageFormatException) rethrow;
      AppLogger.w('Error extracting from tEXt chunk: $e', 'VibeImageEmbedder');
      throw VibeExtractException('Failed to extract vibe from tEXt chunk: $e');
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
      'bundleSource': vibe.bundleSource,
    };
  }

  /// 将序列化的 Map 转换回 VibeReference
  static VibeReference _vibeDataToReference(Map<String, dynamic> data) {
    // 空值检查：确保 data 不为 null 且是 Map 类型
    if (data.isEmpty) {
      throw VibeExtractException('Vibe data is empty');
    }

    // 安全提取字段，处理可能的 null 值
    final displayName = data['displayName'];
    final vibeEncoding = data['vibeEncoding'];
    final thumbnail = data['thumbnail'];
    final strength = data['strength'];
    final infoExtracted = data['infoExtracted'];
    final sourceTypeRaw = data['sourceType'];
    final bundleSource = data['bundleSource'];

    // 验证字段类型
    if (displayName != null && displayName is! String) {
      throw VibeExtractException('Invalid displayName type: ${displayName.runtimeType}');
    }
    if (vibeEncoding != null && vibeEncoding is! String) {
      throw VibeExtractException('Invalid vibeEncoding type: ${vibeEncoding.runtimeType}');
    }
    if (thumbnail != null && thumbnail is! Uint8List) {
      throw VibeExtractException('Invalid thumbnail type: ${thumbnail.runtimeType}');
    }
    if (strength != null && strength is! num) {
      throw VibeExtractException('Invalid strength type: ${strength.runtimeType}');
    }
    if (infoExtracted != null && infoExtracted is! num) {
      throw VibeExtractException('Invalid infoExtracted type: ${infoExtracted.runtimeType}');
    }
    if (bundleSource != null && bundleSource is! String) {
      throw VibeExtractException('Invalid bundleSource type: ${bundleSource.runtimeType}');
    }

    // 解析 sourceType
    VibeSourceType sourceType;
    if (sourceTypeRaw == null) {
      sourceType = VibeSourceType.png;
    } else if (sourceTypeRaw is String) {
      sourceType = VibeSourceType.values.firstWhere(
        (t) => t.name == sourceTypeRaw,
        orElse: () => VibeSourceType.png,
      );
    } else {
      sourceType = VibeSourceType.png;
    }

    return VibeReference(
      displayName: (displayName as String?)?.isNotEmpty == true ? displayName : 'unknown',
      vibeEncoding: vibeEncoding as String? ?? '',
      thumbnail: thumbnail as Uint8List?,
      strength: (strength as num?)?.toDouble() ?? 0.6,
      infoExtracted: (infoExtracted as num?)?.toDouble() ?? 1.0,
      sourceType: sourceType,
      bundleSource: bundleSource as String?,
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

      if (crcEnd > imageBytes.length) {
        throw InvalidImageFormatException('Invalid PNG chunk length in iTXt');
      }

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
          ? utf8.decode(_decodeZlibWithLimit(textBytes))
          : utf8.decode(textBytes);

      // 在解码前验证 base64 编码数据的大小，防止内存溢出
      // base64 解码后大小 ≈ 编码大小 * 3/4
      if (text.length > _maxBase64DecodedSize * 4 ~/ 3) {
        throw VibeExtractException(
          'Base64 encoded data too large: ${text.length} bytes '
          '(max encoded: ${_maxBase64DecodedSize * 4 ~/ 3})',
        );
      }

      final decoded = base64.decode(text);

      // 双重验证：解码后再检查实际大小
      if (decoded.length > _maxBase64DecodedSize) {
        throw VibeExtractException(
          'Base64 decoded data too large: ${decoded.length} bytes '
          '(max: $_maxBase64DecodedSize)',
        );
      }

      final jsonData = jsonDecode(utf8.decode(decoded)) as Map<String, dynamic>;

      return {'keyword': keyword, 'data': jsonData};
    } catch (e) {
      AppLogger.w('Failed to parse iTXt chunk: $e', 'VibeImageEmbedder');
      return null;
    }
  }

  /// 解码 zlib 压缩数据，限制最大解压大小以防止 zip bomb 攻击
  ///
  /// 使用流式解码器，在解压过程中检查大小，避免一次性解压大量数据导致内存溢出。
  /// 如果流式解码失败，直接拒绝数据，不使用 decodeBytes() 作为 fallback，
  /// 以防止 zip bomb 攻击绕过大小限制。
  static List<int> _decodeZlibWithLimit(List<int> bytes) {
    // 首先检查压缩数据大小
    if (bytes.length > _maxCompressedSize) {
      throw VibeExtractException(
        'Compressed data too large: ${bytes.length} bytes '
        '(max: $_maxCompressedSize)',
      );
    }

    try {
      // 使用流式解码器，在解压过程中检查大小
      // 这可以防止 zip bomb 攻击（小压缩数据解压成极大文件）
      final decoder = ZLibDecoder();
      final inputStream = InputStream(bytes);
      final outputStream = _LimitedOutputStream(_maxDecompressedSize);

      // 使用 startDecodeStream 进行流式解码
      decoder.startDecodeStream(inputStream, outputStream);

      return outputStream.getBytes();
    } on VibeExtractException {
      rethrow;
    } catch (e) {
      // 解码失败，拒绝数据
      // 注意：不使用 decodeBytes() 作为 fallback，以防止安全绕过
      throw VibeExtractException(
        'Failed to decompress data: $e. '
        'Possible corrupted or malicious data.',
      );
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
          // 检查 base64 编码数据大小，防止内存溢出
          // base64 解码后大小 ≈ 编码大小 * 3/4
          if (base64Data.length > _maxBase64DecodedSize * 4 ~/ 3) {
            throw VibeExtractException(
              'Base64 thumbnail data too large: ${base64Data.length} bytes '
              '(max encoded: ${_maxBase64DecodedSize * 4 ~/ 3})',
            );
          }
          return base64.decode(base64Data);
        }
      }

      // 如果没有 thumbnail 字段，尝试从 image 字段提取
      final imageBase64 = vibe['image'] as String?;
      if (imageBase64 != null && imageBase64.isNotEmpty) {
        AppLogger.d('Found image field, length: ${imageBase64.length}', 'VibeImageEmbedder');
        final base64Data = _extractBase64FromDataUri(imageBase64);
        if (base64Data != null) {
          // 检查 base64 编码数据大小，防止内存溢出
          if (base64Data.length > _maxBase64DecodedSize * 4 ~/ 3) {
            throw VibeExtractException(
              'Base64 image data too large: ${base64Data.length} bytes '
              '(max encoded: ${_maxBase64DecodedSize * 4 ~/ 3})',
            );
          }
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
        // 检查 base64 编码数据大小，防止内存溢出
        // base64 解码后大小 ≈ 编码大小 * 3/4
        if (thumbnailBase64.length > _maxBase64DecodedSize * 4 ~/ 3) {
          throw VibeExtractException(
            'Base64 thumbnail data too large: ${thumbnailBase64.length} bytes '
            '(max encoded: ${_maxBase64DecodedSize * 4 ~/ 3})',
          );
        }
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

/// 带大小限制的 OutputStream，用于防止 zip bomb 攻击
///
/// 在写入数据时实时检查大小，如果超过限制立即抛出异常，
/// 避免恶意压缩数据耗尽内存。
class _LimitedOutputStream extends OutputStream {
  _LimitedOutputStream(this._maxSize);

  final int _maxSize;
  int _currentSize = 0;
  final List<List<int>> _chunks = [];

  @override
  void writeByte(int value) {
    _checkSize(1);
    super.writeByte(value);
    _currentSize++;
  }

  @override
  void writeBytes(List<int> bytes, [int? len]) {
    final length = len ?? bytes.length;
    _checkSize(length);
    super.writeBytes(bytes, length);
    _currentSize += length;
  }

  @override
  void writeInputStream(InputStreamBase stream) {
    _checkSize(stream.length);
    super.writeInputStream(stream);
    _currentSize += stream.length;
  }

  void _checkSize(int additionalBytes) {
    if (_currentSize + additionalBytes > _maxSize) {
      throw VibeExtractException(
        'Decompressed data exceeds maximum size of $_maxSize bytes '
        '(possible zip bomb attack)',
      );
    }
  }
}
