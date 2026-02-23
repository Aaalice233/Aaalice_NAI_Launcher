import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:png_chunks_extract/png_chunks_extract.dart' as png_extract;

import '../../data/models/gallery/nai_image_metadata.dart';
import 'app_logger.dart';

/// PNG 元数据提取器
///
/// 统一的 PNG 元数据提取工具类，支持从 PNG chunks (tEXt/zTXt/iTXt) 中提取 NAI 元数据。
///
/// 此类为纯静态方法，无状态，可在任意 isolate 中安全使用。
///
/// 使用示例：
/// ```dart
/// // 从文件路径提取
/// final metadata = PngMetadataExtractor.extractFromFile(filePath);
///
/// // 从字节数据提取
/// final metadata = PngMetadataExtractor.extractFromBytes(bytes);
///
/// // 仅提取前 N 个 chunks（性能优化）
/// final metadata = PngMetadataExtractor.extractFromBytes(bytes, maxChunks: 15);
/// ```
class PngMetadataExtractor {
  PngMetadataExtractor._(); // 私有构造，阻止实例化

  // PNG 文件头签名
  static const List<int> _pngSignature = [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  ];

  // 支持的 text chunk 类型
  static const Set<String> _textChunkTypes = {'tEXt', 'zTXt', 'iTXt'};

  // 关心的 keyword（用于快速过滤）
  static const Set<String> _validKeywords = {'Comment', 'parameters'};

  /// 检查是否为有效的 PNG 文件头
  static bool isPngHeader(Uint8List bytes) {
    if (bytes.length < 8) return false;
    for (var i = 0; i < 8; i++) {
      if (bytes[i] != _pngSignature[i]) return false;
    }
    return true;
  }

  /// 从文件路径提取元数据
  ///
  /// [maxBytes] 限制读取的最大字节数（用于流式解析优化）
  /// [maxChunks] 限制解析的最大 chunk 数量
  static NaiImageMetadata? extractFromFile(
    String filePath, {
    int? maxBytes,
    int maxChunks = 15,
  }) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        AppLogger.d('[PngMetadataExtractor] File not found: $filePath', 'PngMetadataExtractor');
        return null;
      }

      Uint8List bytes;
      if (maxBytes != null) {
        // 流式读取：只读前 N 字节
        final raf = file.openSync();
        try {
          final length = raf.lengthSync();
          final toRead = length < maxBytes ? length : maxBytes;
          bytes = raf.readSync(toRead);
        } finally {
          raf.closeSync();
        }
      } else {
        bytes = file.readAsBytesSync();
      }

      return extractFromBytes(bytes, maxChunks: maxChunks);
    } catch (e, stack) {
      AppLogger.e(
        '[PngMetadataExtractor] Failed to extract from file: $filePath',
        e,
        stack,
        'PngMetadataExtractor',
      );
      return null;
    }
  }

  /// 从字节数据提取元数据
  ///
  /// [maxChunks] 限制解析的最大 chunk 数量（性能优化）
  static NaiImageMetadata? extractFromBytes(
    Uint8List bytes, {
    int maxChunks = 15,
    String? filePathForLog,
  }) {
    if (bytes.length < 8 || !isPngHeader(bytes)) {
      return null;
    }

    try {
      final chunks = png_extract.extractChunks(bytes);
      return _extractFromChunks(
        chunks,
        maxChunks: maxChunks,
        filePathForLog: filePathForLog,
      );
    } catch (e, stack) {
      AppLogger.e(
        '[PngMetadataExtractor] Failed to extract from bytes',
        e,
        stack,
        'PngMetadataExtractor',
      );
      return null;
    }
  }

  /// 从已解析的 chunks 中提取元数据
  ///
  /// [chunks] 从 png_extract.extractChunks() 返回的 chunks
  /// [maxChunks] 限制检查的最大 chunk 数量
  static NaiImageMetadata? extractFromChunks(
    List<Map<String, dynamic>> chunks, {
    int maxChunks = 15,
    String? filePathForLog,
  }) {
    return _extractFromChunks(
      chunks,
      maxChunks: maxChunks,
      filePathForLog: filePathForLog,
    );
  }

  /// 内部实现：从 chunks 中提取元数据
  static NaiImageMetadata? _extractFromChunks(
    List<Map<String, dynamic>> chunks, {
    required int maxChunks,
    String? filePathForLog,
  }) {
    final fileName = filePathForLog?.split(Platform.pathSeparator).last;

    final effectiveMaxChunks = chunks.length < maxChunks ? chunks.length : maxChunks;

    for (var i = 0; i < effectiveMaxChunks; i++) {
      final chunk = chunks[i];
      final name = chunk['name'] as String?;

      if (name == null || !_textChunkTypes.contains(name)) continue;

      final data = chunk['data'] as Uint8List?;
      if (data == null) continue;

      final textData = _parseTextChunk(data, name);
      if (textData == null) continue;

      // 快速检查：是否包含 NAI 特征
      final hasPrompt = textData.contains('prompt');
      final hasSampler = textData.contains('sampler');
      if (!hasPrompt && !hasSampler) continue;

      // 尝试解析 JSON
      final json = _tryParseNaiJson(textData);
      if (json != null) {
        if (fileName != null) {
          AppLogger.d(
            '[PngMetadataExtractor] Found NAI metadata in $name chunk #$i for $fileName',
            'PngMetadataExtractor',
          );
        }
        return NaiImageMetadata.fromNaiComment(json, rawJson: textData);
      }
    }

    return null;
  }

  /// 解析 text chunk（根据类型分发）
  static String? _parseTextChunk(Uint8List data, String chunkType) {
    try {
      return switch (chunkType) {
        'tEXt' => _parseTEXt(data),
        'zTXt' => _parseZTXt(data),
        'iTXt' => _parseITXt(data),
        _ => null,
      };
    } catch (e) {
      return null;
    }
  }

  /// 解析 tEXt chunk: keyword\0text (Latin-1)
  ///
  /// 只返回 Comment 或 parameters keyword 的文本内容
  static String? _parseTEXt(Uint8List data) {
    final nullIndex = data.indexOf(0);
    if (nullIndex < 0 || nullIndex + 1 >= data.length) return null;

    final keyword = latin1.decode(data.sublist(0, nullIndex));
    if (!_validKeywords.contains(keyword)) return null;

    return latin1.decode(data.sublist(nullIndex + 1));
  }

  /// 解析 zTXt chunk: keyword\0compressionMethod\0compressedText
  ///
  /// 只返回 Comment 或 parameters keyword 的解压后文本
  static String? _parseZTXt(Uint8List data) {
    final firstNull = data.indexOf(0);
    if (firstNull < 0 || firstNull + 1 >= data.length) return null;

    final keyword = latin1.decode(data.sublist(0, firstNull));
    if (!_validKeywords.contains(keyword)) return null;

    final compressionMethod = data[firstNull + 1];
    if (compressionMethod != 0) return null;

    return _inflateZlib(data.sublist(firstNull + 2));
  }

  /// 解析 iTXt chunk: keyword\0compressed\0method\0language\0translatedKeyword\0text
  ///
  /// 只返回 Comment 或 parameters keyword 的文本内容
  static String? _parseITXt(Uint8List data) {
    var offset = 0;

    // 跳过 keyword
    final keywordEnd = data.indexOf(0, offset);
    if (keywordEnd < 0) return null;

    final keyword = utf8.decode(data.sublist(0, keywordEnd));
    if (!_validKeywords.contains(keyword)) return null;

    offset = keywordEnd + 1;
    if (offset + 1 >= data.length) return null;

    final compressed = data[offset++];
    final method = data[offset++];

    // 跳过 language tag
    final langEnd = data.indexOf(0, offset);
    if (langEnd < 0) return null;
    offset = langEnd + 1;

    // 跳过 translated keyword
    final transEnd = data.indexOf(0, offset);
    if (transEnd < 0) return null;
    offset = transEnd + 1;

    if (offset >= data.length) return null;
    final textData = data.sublist(offset);

    if (compressed == 1) {
      if (method != 0) return null;
      return _inflateZlib(textData);
    }
    return utf8.decode(textData);
  }

  /// 解压 zlib 压缩数据
  static String? _inflateZlib(Uint8List data) {
    try {
      final inflated = ZLibCodec().decode(data);
      return utf8.decode(inflated);
    } catch (e) {
      return null;
    }
  }

  /// 尝试解析 NAI JSON 数据
  ///
  /// 支持两种格式：
  /// 1. 官方格式：{"prompt": "...", "uc": "..."} - prompt在顶层
  /// 2. PNG标准格式：{"Description": "...", "Comment": "{...}"} - Comment字段包含实际元数据
  /// 3. 嵌套格式：{"Comment": {"prompt": "...", "uc": "..."}}
  static Map<String, dynamic>? _tryParseNaiJson(String text) {
    try {
      final lowerText = text.toLowerCase();
      final hasNaiKeywords =
          lowerText.contains('prompt') ||
          lowerText.contains('sampler') ||
          lowerText.contains('steps');
      if (!hasNaiKeywords) return null;

      final json = jsonDecode(text) as Map<String, dynamic>;

      // 格式1: 直接格式 - prompt在顶层
      if (json.containsKey('prompt') || json.containsKey('comment')) {
        return json;
      }

      // 格式2: PNG标准格式 - Comment字段包含实际元数据（可能是字符串或对象）
      if (json.containsKey('Comment')) {
        final comment = json['Comment'];

        // Comment 是对象
        if (comment is Map<String, dynamic>) {
          if (comment.containsKey('prompt') || comment.containsKey('uc')) {
            return comment;
          }
        }

        // Comment 是字符串（需要再次解析）
        if (comment is String) {
          try {
            final commentJson = jsonDecode(comment) as Map<String, dynamic>;
            if (commentJson.containsKey('prompt') || commentJson.containsKey('uc')) {
              return commentJson;
            }
          } catch (_) {
            // Comment不是有效的JSON，忽略
          }
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}
