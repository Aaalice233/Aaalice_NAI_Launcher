import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../../core/utils/portable_logger.dart';

/// Encodes and decodes metadata carried by image containers.
class ImageMetadataContainerCodec {
  static const String _tag = 'UnifiedMetadataParser';
  static const String _magic = 'stealth_pngcomp';
  static const int _maxStealthDecodePixels = 0x1000000;
  static const List<int> _pngSignature = [
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
  ];

  /// 检查是否为有效的 PNG 文件头
  static bool isPngHeader(Uint8List bytes) {
    if (bytes.length < 8) return false;
    for (var i = 0; i < 8; i++) {
      if (bytes[i] != _pngSignature[i]) return false;
    }
    return true;
  }

  /// 读取 PNG 文本元数据，同时支持 Latin-1 `tEXt` 和 UTF-8 `iTXt`。
  ///
  /// `package:image` 4.3.0 只暴露 `tEXt`，因此 Unicode 提示词需要在这里
  /// 额外解析标准 `iTXt`，避免中文等内容被丢弃或误解码。
  static Map<String, String> extractPngTextData(
    Uint8List bytes, {
    Map<String, String>? decoderTextData,
  }) {
    if (!isPngHeader(bytes)) return const {};

    final textData = <String, String>{};
    if (decoderTextData != null) {
      textData.addAll(decoderTextData);
    } else {
      try {
        final info = img.PngDecoder().startDecode(bytes);
        if (info is img.PngInfo) {
          textData.addAll(info.textData);
        }
      } catch (_) {
        // 手动 chunk 解析仍可能成功。
      }
    }

    // Keep HEAD precedence: manually decoded tEXt/iTXt/zTXt chunks override
    // package:image values for the same keyword.
    textData.addAll(_extractTextDataFromChunks(bytes));
    return textData;
  }

  /// 将元数据嵌入 PNG 图片
  ///
  /// 支持两种模式：
  /// 1. 快速模式（默认）：仅添加 tEXt chunk，不重新编码 PNG（<5ms，性能提升50-100倍）
  /// 2. 完整模式：同时写入 stealth（alpha通道）和 tEXt chunk（500-800ms，兼容性更好）
  ///
  /// [useStealth] 是否嵌入 stealth 数据到 alpha 通道。默认 false，使用快速路径。
  static Future<Uint8List> embedMetadata(
    Uint8List imageBytes,
    String metadataJson, {
    bool useStealth = false,
  }) async {
    if (!useStealth) {
      // 快速路径：仅添加/更新 tEXt chunk（不重新编码PNG）
      return embedTextChunkOnly(imageBytes, 'Comment', metadataJson);
    }

    // 完整路径：stealth + tEXt（保持最大兼容性）
    final stealthBytes = await _embedStealthData(imageBytes, metadataJson);
    return _updateTextChunk(stealthBytes, metadataJson);
  }

  /// 仅嵌入 tEXt chunk（不重新编码 PNG，性能提升 50-100 倍）
  ///
  /// 直接操作 PNG chunks，避免调用 img.decodePng/img.encodePng，
  /// 保留所有原始 chunks，包括非标准 chunks。
  ///
  /// 时间对比（1024x1024 图片）：
  /// - 重新编码: 500-800ms
  /// - 此方法: 5-15ms
  static Uint8List embedTextChunkOnly(
    Uint8List originalPng,
    String keyword,
    String text,
  ) {
    try {
      final chunks = _parsePngChunks(originalPng);
      final output = BytesBuilder();

      // 写入 PNG 签名
      output.add(originalPng.sublist(0, 8));

      var textChunkAdded = false;
      var idatIndex = -1;

      // 找到第一个 IDAT 的位置（用于决定插入位置）
      for (var i = 0; i < chunks.length; i++) {
        if (chunks[i].type == 'IDAT') {
          idatIndex = i;
          break;
        }
      }

      for (var i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];

        // 替换同名 tEXt/iTXt/zTXt，并清除重复项。
        final existingKeyword = _textChunkKeyword(chunk);
        if (existingKeyword == keyword) {
          if (!textChunkAdded) {
            _writeTextMetadataChunk(output, keyword, text);
            textChunkAdded = true;
          }
          continue;
        }

        // 在第一个 IDAT 之前插入新 chunk（PNG 规范建议）
        if (i == idatIndex && !textChunkAdded) {
          _writeTextMetadataChunk(output, keyword, text);
          textChunkAdded = true;
        }

        // 写入原始 chunk
        _writeChunk(output, chunk.type, chunk.data);
      }

      // 如果还没添加（没有 IDAT 的情况），追加到末尾
      if (!textChunkAdded) {
        _writeTextMetadataChunk(output, keyword, text);
      }

      return output.toBytes();
    } catch (e, stack) {
      PortableLogger.e(
        '[UnifiedMetadataParser] Failed to embed text chunk',
        e,
        stack,
        _tag,
      );
      // 失败时返回原始数据
      return originalPng;
    }
  }

  /// 手动解析 PNG chunks
  static List<_PngChunk> _parsePngChunks(Uint8List bytes) {
    final chunks = <_PngChunk>[];
    var offset = 8; // 跳过 PNG 文件头

    while (offset < bytes.length) {
      if (offset + 12 > bytes.length) break;

      // 读取 chunk 长度（4字节，大端序）
      final length = ByteData.sublistView(
        bytes,
        offset,
        offset + 4,
      ).getUint32(0);

      // 读取 chunk 类型（4字节）
      final type = latin1.decode(bytes.sublist(offset + 4, offset + 8));

      // 检查数据边界
      if (offset + 12 + length > bytes.length) break;

      // 读取 chunk 数据
      final data = bytes.sublist(offset + 8, offset + 8 + length);

      chunks.add(_PngChunk(type, data));

      // 移动到下一个 chunk (length + type + data + crc)
      offset += 12 + length;
    }

    return chunks;
  }

  static Map<String, String> _extractTextDataFromChunks(Uint8List bytes) {
    final result = <String, String>{};
    for (final chunk in _parsePngChunks(bytes)) {
      final entry = switch (chunk.type) {
        'tEXt' => _decodeTextChunk(chunk.data),
        'iTXt' => _decodeInternationalTextChunk(chunk.data),
        'zTXt' => _decodeCompressedTextChunk(chunk.data),
        _ => null,
      };
      if (entry != null) {
        result[entry.$1] = entry.$2;
      }
    }
    return result;
  }

  static (String, String)? _decodeTextChunk(Uint8List data) {
    final separator = data.indexOf(0);
    if (separator <= 0) return null;
    return (
      latin1.decode(data.sublist(0, separator)),
      latin1.decode(data.sublist(separator + 1)),
    );
  }

  static (String, String)? _decodeInternationalTextChunk(Uint8List data) {
    final keywordEnd = data.indexOf(0);
    if (keywordEnd <= 0 || keywordEnd + 5 > data.length) return null;

    var cursor = keywordEnd + 1;
    final compressionFlag = data[cursor++];
    final compressionMethod = data[cursor++];
    final languageEnd = data.indexOf(0, cursor);
    if (languageEnd < 0) return null;
    cursor = languageEnd + 1;
    final translatedKeywordEnd = data.indexOf(0, cursor);
    if (translatedKeywordEnd < 0) return null;
    cursor = translatedKeywordEnd + 1;

    List<int> textBytes = data.sublist(cursor);
    if (compressionFlag == 1) {
      if (compressionMethod != 0) return null;
      textBytes = ZLibCodec().decode(textBytes);
    } else if (compressionFlag != 0) {
      return null;
    }

    return (latin1.decode(data.sublist(0, keywordEnd)), utf8.decode(textBytes));
  }

  static (String, String)? _decodeCompressedTextChunk(Uint8List data) {
    final keywordEnd = data.indexOf(0);
    if (keywordEnd <= 0 || keywordEnd + 2 > data.length) return null;
    final compressionMethod = data[keywordEnd + 1];
    if (compressionMethod != 0) return null;
    final decoded = ZLibCodec().decode(data.sublist(keywordEnd + 2));
    return (latin1.decode(data.sublist(0, keywordEnd)), latin1.decode(decoded));
  }

  static String? _textChunkKeyword(_PngChunk chunk) {
    if (chunk.type != 'tEXt' && chunk.type != 'iTXt' && chunk.type != 'zTXt') {
      return null;
    }
    final separator = chunk.data.indexOf(0);
    if (separator <= 0) return null;
    return latin1.decode(chunk.data.sublist(0, separator));
  }

  static bool _isLatin1(String text) {
    for (final codeUnit in text.codeUnits) {
      if (codeUnit > 0xff) return false;
    }
    return true;
  }

  static void _writeTextMetadataChunk(
    BytesBuilder builder,
    String keyword,
    String text,
  ) {
    if (_isLatin1(text)) {
      _writeTextChunk(builder, keyword, text);
    } else {
      _writeInternationalTextChunk(builder, keyword, text);
    }
  }

  /// 写入 tEXt chunk 到 builder
  static void _writeTextChunk(
    BytesBuilder builder,
    String keyword,
    String text,
  ) {
    final keywordBytes = latin1.encode(keyword);
    final textBytes = latin1.encode(text);

    final data = Uint8List(keywordBytes.length + 1 + textBytes.length);
    data.setAll(0, keywordBytes);
    data[keywordBytes.length] = 0; // null separator
    data.setAll(keywordBytes.length + 1, textBytes);

    _writeChunk(builder, 'tEXt', data);
  }

  /// 写入未压缩 UTF-8 iTXt chunk。
  static void _writeInternationalTextChunk(
    BytesBuilder builder,
    String keyword,
    String text,
  ) {
    final keywordBytes = latin1.encode(keyword);
    final textBytes = utf8.encode(text);
    final data = Uint8List(keywordBytes.length + 5 + textBytes.length);
    data.setAll(0, keywordBytes);
    // keyword terminator, compression flag/method, empty language tag and
    // empty translated keyword are all zero-filled.
    data.setAll(keywordBytes.length + 5, textBytes);
    _writeChunk(builder, 'iTXt', data);
  }

  /// 写入 PNG chunk（带 length + type + data + crc 结构）
  static void _writeChunk(BytesBuilder builder, String type, Uint8List data) {
    // Length (4 bytes, big-endian)
    final lengthBytes = ByteData(4)..setUint32(0, data.length);
    builder.add(lengthBytes.buffer.asUint8List());

    // Type (4 bytes)
    final typeBytes = latin1.encode(type);
    builder.add(typeBytes);

    // Data
    builder.add(data);

    // CRC32 (type + data)
    final crcInput = Uint8List(typeBytes.length + data.length);
    crcInput.setAll(0, typeBytes);
    crcInput.setAll(typeBytes.length, data);
    final crc = _crc32(crcInput);
    final crcBytes = ByteData(4)..setUint32(0, crc);
    builder.add(crcBytes.buffer.asUint8List());
  }

  /// 更新 PNG 的 Comment 文本字段。
  static Future<Uint8List> _updateTextChunk(
    Uint8List bytes,
    String metadataJson,
  ) async {
    return embedTextChunkOnly(bytes, 'Comment', metadataJson);
  }

  /// CRC32 计算（PNG 标准）
  static int _crc32(Uint8List data) {
    const table = [
      0x00000000,
      0x77073096,
      0xee0e612c,
      0x990951ba,
      0x076dc419,
      0x706af48f,
      0xe963a535,
      0x9e6495a3,
      0x0edb8832,
      0x79dcb8a4,
      0xe0d5e91e,
      0x97d2d988,
      0x09b64c2b,
      0x7eb17cbd,
      0xe7b82d07,
      0x90bf1d91,
      0x1db71064,
      0x6ab020f2,
      0xf3b97148,
      0x84be41de,
      0x1adad47d,
      0x6ddde4eb,
      0xf4d4b551,
      0x83d385c7,
      0x136c9856,
      0x646ba8c0,
      0xfd62f97a,
      0x8a65c9ec,
      0x14015c4f,
      0x63066cd9,
      0xfa0f3d63,
      0x8d080df5,
      0x3b6e20c8,
      0x4c69105e,
      0xd56041e4,
      0xa2677172,
      0x3c03e4d1,
      0x4b04d447,
      0xd20d85fd,
      0xa50ab56b,
      0x35b5a8fa,
      0x42b2986c,
      0xdbbbc9d6,
      0xacbcf940,
      0x32d86ce3,
      0x45df5c75,
      0xdcd60dcf,
      0xabd13d59,
      0x26d930ac,
      0x51de003a,
      0xc8d75180,
      0xbfd06116,
      0x21b4f4b5,
      0x56b3c423,
      0xcfba9599,
      0xb8bda50f,
      0x2802b89e,
      0x5f058808,
      0xc60cd9b2,
      0xb10be924,
      0x2f6f7c87,
      0x58684c11,
      0xc1611dab,
      0xb6662d3d,
      0x76dc4190,
      0x01db7106,
      0x98d220bc,
      0xefd5102a,
      0x71b18589,
      0x06b6b51f,
      0x9fbfe4a5,
      0xe8b8d433,
      0x7807c9a2,
      0x0f00f934,
      0x9609a88e,
      0xe10e9818,
      0x7f6a0dbb,
      0x086d3d2d,
      0x91646c97,
      0xe6635c01,
      0x6b6b51f4,
      0x1c6c6162,
      0x856530d8,
      0xf262004e,
      0x6c0695ed,
      0x1b01a57b,
      0x8208f4c1,
      0xf50fc457,
      0x65b0d9c6,
      0x12b7e950,
      0x8bbeb8ea,
      0xfcb9887c,
      0x62dd1ddf,
      0x15da2d49,
      0x8cd37cf3,
      0xfbd44c65,
      0x4db26158,
      0x3ab551ce,
      0xa3bc0074,
      0xd4bb30e2,
      0x4adfa541,
      0x3dd895d7,
      0xa4d1c46d,
      0xd3d6f4fb,
      0x4369e96a,
      0x346ed9fc,
      0xad678846,
      0xda60b8d0,
      0x44042d73,
      0x33031de5,
      0xaa0a4c5f,
      0xdd0d7cc9,
      0x5005713c,
      0x270241aa,
      0xbe0b1010,
      0xc90c2086,
      0x5768b525,
      0x206f85b3,
      0xb966d409,
      0xce61e49f,
      0x5edef90e,
      0x29d9c998,
      0xb0d09822,
      0xc7d7a8b4,
      0x59b33d17,
      0x2eb40d81,
      0xb7bd5c3b,
      0xc0ba6cad,
      0xedb88320,
      0x9abfb3b6,
      0x03b6e20c,
      0x74b1d29a,
      0xead54739,
      0x9dd277af,
      0x04db2615,
      0x73dc1683,
      0xe3630b12,
      0x94643b84,
      0x0d6d6a3e,
      0x7a6a5aa8,
      0xe40ecf0b,
      0x9309ff9d,
      0x0a00ae27,
      0x7d079eb1,
      0xf00f9344,
      0x8708a3d2,
      0x1e01f268,
      0x6906c2fe,
      0xf762575d,
      0x806567cb,
      0x196c3671,
      0x6e6b06e7,
      0xfed41b76,
      0x89d32be0,
      0x10da7a5a,
      0x67dd4acc,
      0xf9b9df6f,
      0x8ebeeff9,
      0x17b7be43,
      0x60b08ed5,
      0xd6d6a3e8,
      0xa1d1937e,
      0x38d8c2c4,
      0x4fdff252,
      0xd1bb67f1,
      0xa6bc5767,
      0x3fb506dd,
      0x48b2364b,
      0xd80d2bda,
      0xaf0a1b4c,
      0x36034af6,
      0x41047a60,
      0xdf60efc3,
      0xa867df55,
      0x316e8eef,
      0x4669be79,
      0xcb61b38c,
      0xbc66831a,
      0x256fd2a0,
      0x5268e236,
      0xcc0c7795,
      0xbb0b4703,
      0x220216b9,
      0x5505262f,
      0xc5ba3bbe,
      0xb2bd0b28,
      0x2bb45a92,
      0x5cb36a04,
      0xc2d7ffa7,
      0xb5d0cf31,
      0x2cd99e8b,
      0x5bdeae1d,
      0x9b64c2b0,
      0xec63f226,
      0x756aa39c,
      0x026d930a,
      0x9c0906a9,
      0xeb0e363f,
      0x72076785,
      0x05005713,
      0x95bf4a82,
      0xe2b87a14,
      0x7bb12bae,
      0x0cb61b38,
      0x92d28e9b,
      0xe5d5be0d,
      0x7cdcefb7,
      0x0bdbdf21,
      0x86d3d2d4,
      0xf1d4e242,
      0x68ddb3f8,
      0x1fda836e,
      0x81be16cd,
      0xf6b9265b,
      0x6fb077e1,
      0x18b74777,
      0x88085ae6,
      0xff0f6a70,
      0x66063bca,
      0x11010b5c,
      0x8f659eff,
      0xf862ae69,
      0x616bffd3,
      0x166ccf45,
      0xa00ae278,
      0xd70dd2ee,
      0x4e048354,
      0x3903b3c2,
      0xa7672661,
      0xd06016f7,
      0x4969474d,
      0x3e6e77db,
      0xaed16a4a,
      0xd9d65adc,
      0x40df0b66,
      0x37d83bf0,
      0xa9bcae53,
      0xdebb9ec5,
      0x47b2cf7f,
      0x30b5ffe9,
      0xbdbdf21c,
      0xcabac28a,
      0x53b39330,
      0x24b4a3a6,
      0xbad03605,
      0xcdd70693,
      0x54de5729,
      0x23d967bf,
      0xb3667a2e,
      0xc4614ab8,
      0x5d681b02,
      0x2a6f2b94,
      0xb40bbe37,
      0xc30c8ea1,
      0x5a05df1b,
      0x2d02ef8d,
    ];

    var crc = 0xffffffff;
    for (final byte in data) {
      crc = (crc >>> 8) ^ table[(crc ^ byte) & 0xff];
    }
    return crc ^ 0xffffffff;
  }

  /// 嵌入 stealth 数据到 alpha 通道
  static Future<Uint8List> _embedStealthData(
    Uint8List imageBytes,
    String metadataJson,
  ) async {
    final image = img.decodePng(imageBytes);
    if (image == null) throw Exception('Failed to decode PNG image');

    final encodedData = GZipCodec().encode(utf8.encode(metadataJson));
    final bitLengthBytes = ByteData(4)..setInt32(0, encodedData.length * 8);

    final dataToEmbed = [
      ...utf8.encode(_magic),
      ...bitLengthBytes.buffer.asUint8List(),
      ...encodedData,
    ];

    var bitIndex = 0;
    for (var x = 0; x < image.width; x++) {
      for (var y = 0; y < image.height; y++) {
        final byteIndex = bitIndex ~/ 8;
        if (byteIndex >= dataToEmbed.length) break;

        final bit = (dataToEmbed[byteIndex] >> (7 - bitIndex % 8)) & 1;
        final pixel = image.getPixel(x, y);
        pixel.a = (pixel.a.toInt() & 0xFE) | bit;
        image.setPixel(x, y, pixel);

        bitIndex++;
      }
    }

    return img.encodePng(image);
  }

  /// 从 NovelAI stealth_pngcomp alpha LSB 数据中读取元数据。
  static String? extractStealthMetadataText(Uint8List imageBytes) {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null ||
          image.width * image.height > _maxStealthDecodePixels) {
        return null;
      }

      final magicBytes = utf8.encode(_magic);
      final headerBytes = _readAlphaLsbBytes(image, magicBytes.length + 4);
      if (headerBytes == null || headerBytes.length < magicBytes.length + 4) {
        return null;
      }

      for (var i = 0; i < magicBytes.length; i++) {
        if (headerBytes[i] != magicBytes[i]) {
          return null;
        }
      }

      final lengthData = ByteData.sublistView(
        Uint8List.fromList(headerBytes.sublist(magicBytes.length)),
      );
      final bitLength = lengthData.getInt32(0);
      if (bitLength <= 0) return null;

      final byteLength = (bitLength + 7) ~/ 8;
      final payload = _readAlphaLsbBytes(
        image,
        byteLength,
        bitOffset: (magicBytes.length + 4) * 8,
      );
      if (payload == null) return null;

      final decoded = GZipCodec().decode(payload);
      return utf8.decode(decoded);
    } catch (e) {
      PortableLogger.d('Failed to extract stealth_pngcomp metadata: $e', _tag);
      return null;
    }
  }

  static List<int>? _readAlphaLsbBytes(
    img.Image image,
    int byteCount, {
    int bitOffset = 0,
  }) {
    final totalBits = byteCount * 8;
    final capacityBits = image.width * image.height;
    if (bitOffset < 0 || bitOffset + totalBits > capacityBits) {
      return null;
    }

    final output = List<int>.filled(byteCount, 0);
    for (var bitIndex = 0; bitIndex < totalBits; bitIndex++) {
      final absoluteBit = bitOffset + bitIndex;
      final x = absoluteBit ~/ image.height;
      final y = absoluteBit % image.height;
      if (x >= image.width) return null;

      final bit = image.getPixel(x, y).a.toInt() & 1;
      output[bitIndex ~/ 8] |= bit << (7 - (bitIndex % 8));
    }
    return output;
  }
}

class _PngChunk {
  const _PngChunk(this.type, this.data);

  final String type;
  final Uint8List data;
}
