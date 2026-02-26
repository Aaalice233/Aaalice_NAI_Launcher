import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';


import 'package:image/image.dart' as img;

import '../../../core/utils/app_logger.dart';
import '../../models/gallery/nai_image_metadata.dart';

/// 元数据解析结果
class MetadataParseResult {
  final bool success;
  final NaiImageMetadata? metadata;
  final String? sourceFormat;
  final String? rawData;
  final List<String> triedParsers;
  final String? errorMessage;
  final Duration? parseTime;
  final int? bytesRead;

  const MetadataParseResult({
    this.success = false,
    this.metadata,
    this.sourceFormat,
    this.rawData,
    this.triedParsers = const [],
    this.errorMessage,
    this.parseTime,
    this.bytesRead,
  });

  factory MetadataParseResult.failed(
    List<String> triedParsers,
    String error, {
    Duration? parseTime,
    int? bytesRead,
  }) {
    return MetadataParseResult(
      success: false,
      triedParsers: triedParsers,
      errorMessage: error,
      parseTime: parseTime,
      bytesRead: bytesRead,
    );
  }

  factory MetadataParseResult.success(
    NaiImageMetadata metadata,
    String sourceFormat,
    String rawData,
    List<String> triedParsers, {
    Duration? parseTime,
    int? bytesRead,
  }) {
    return MetadataParseResult(
      success: true,
      metadata: metadata,
      sourceFormat: sourceFormat,
      rawData: rawData,
      triedParsers: triedParsers,
      parseTime: parseTime,
      bytesRead: bytesRead,
    );
  }
}

/// 解析统计信息
class ParseStatistics {
  int totalAttempts = 0;
  int successfulParses = 0;
  int failedParses = 0;
  int gradualReadAttempts = 0;
  int gradualReadSuccesses = 0;
  final Map<String, int> parserSuccessCounts = {};
  final Map<String, int> parserFailureCounts = {};
  Duration totalParseTime = Duration.zero;

  Map<String, dynamic> toMap() => {
    'totalAttempts': totalAttempts,
    'successfulParses': successfulParses,
    'failedParses': failedParses,
    'gradualReadAttempts': gradualReadAttempts,
    'gradualReadSuccesses': gradualReadSuccesses,
    'parserSuccessCounts': parserSuccessCounts,
    'parserFailureCounts': parserFailureCounts,
    'averageParseTimeMs': totalAttempts > 0
        ? totalParseTime.inMilliseconds ~/ totalAttempts
        : 0,
  };

  void reset() {
    totalAttempts = 0;
    successfulParses = 0;
    failedParses = 0;
    gradualReadAttempts = 0;
    gradualReadSuccesses = 0;
    parserSuccessCounts.clear();
    parserFailureCounts.clear();
    totalParseTime = Duration.zero;
  }
}

/// 统一元数据解析器
///
/// 支持多种 AI 绘画工具的元数据格式：
/// - NovelAI (JSON in Comment/parameters)
/// - Stable Diffusion WebUI (Plain text)
/// - ComfyUI (JSON with workflow)
/// - InvokeAI (JSON format)
/// - Fooocus (JSON format)
/// - Draw Things (JSON format)
/// - 以及更多...
///
/// 特性：
/// - 渐进式读取策略（100KB -> 500KB -> 2MB -> 完整文件）
/// - 解析结果缓存
/// - 详细的错误信息和统计
/// - 元数据嵌入支持
class UnifiedMetadataParser {
  static const String _tag = 'UnifiedMetadataParser';
  static const String _magic = 'stealth_pngcomp';

  // PNG 文件头签名
  static const List<int> _pngSignature = [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  ];

  /// 渐进式读取的阈值（字节）
  ///
  /// 按以下顺序尝试：
  /// 1. 100KB - 大多数元数据都在这个范围内
  /// 2. 500KB - 大型元数据或 WebUI 格式
  /// 3. 2MB  - 超大元数据或 ComfyUI workflow
  /// 4. 完整文件 - 最后的保障
  static const List<int> _gradualReadThresholds = [
    100 * 1024, // 100KB
    500 * 1024, // 500KB
    2 * 1024 * 1024, // 2MB
  ];

  /// 解析结果缓存（避免重复解析相同字节）
  static final Map<String, MetadataParseResult> _resultCache = {};

  /// 解析统计
  static final ParseStatistics _statistics = ParseStatistics();

  /// 所有注册的解析器
  static final List<MetadataParser> _parsers = [
    NovelAiParser(),
    WebUiParser(),
    ComfyUiParser(),
    InvokeAiParser(),
    JsonGenericParser(
      name: 'Fooocus',
      fieldsToTry: ['fooocus', 'Fooocus', 'parameters'],
      software: 'Fooocus',
    ),
    JsonGenericParser(
      name: 'Draw Things',
      fieldsToTry: ['draw_things', 'DrawThings', 'drawthings'],
      software: 'Draw Things',
      scaleKeys: ['scale', 'cfg_scale'],
    ),
  ];

  /// 检查是否为有效的 PNG 文件头
  static bool isPngHeader(Uint8List bytes) {
    if (bytes.length < 8) return false;
    for (var i = 0; i < 8; i++) {
      if (bytes[i] != _pngSignature[i]) return false;
    }
    return true;
  }

  /// 从 PNG 文件路径提取元数据（智能渐进式读取）
  ///
  /// [filePath] PNG 文件路径
  /// [maxBytes] 限制读取的最大字节数（null 表示使用渐进式读取）
  /// [useGradualRead] 是否使用渐进式读取策略（默认 true）
  /// [useCache] 是否使用解析结果缓存（默认 true）
  static MetadataParseResult parseFromFile(
    String filePath, {
    int? maxBytes,
    bool useGradualRead = true,
    bool useCache = true,
  }) {
    final stopwatch = Stopwatch()..start();
    _statistics.totalAttempts++;

    // 扫描时日志太频繁，只在需要时开启详细日志
    // AppLogger.d(
    //   '[UnifiedMetadataParser] parseFromFile START: $filePath, '
    //   'maxBytes=$maxBytes, useGradualRead=$useGradualRead',
    //   _tag,
    // );

    try {
      final file = File(filePath);

      if (!file.existsSync()) {
        final error = 'File not found: $filePath';
        AppLogger.w(error, _tag);
        return MetadataParseResult.failed(
          [],
          error,
          parseTime: stopwatch.elapsed,
        );
      }

      final fileSize = file.lengthSync();
      if (fileSize < 8) {
        final error = 'File too small: $fileSize bytes';
        AppLogger.w(error, _tag);
        return MetadataParseResult.failed(
          [],
          error,
          parseTime: stopwatch.elapsed,
        );
      }

      // AppLogger.d('[UnifiedMetadataParser] File size: $fileSize bytes', _tag);

      MetadataParseResult result;

      // 如果指定了 maxBytes 且不使用渐进式读取，直接按指定大小读取
      if (maxBytes != null && !useGradualRead) {
        result = _extractWithLimit(file, filePath, maxBytes, fileSize);
      } else if (useGradualRead) {
        // 使用渐进式读取策略
        result = _extractGradual(file, filePath, fileSize);
      } else {
        // 默认：完整文件读取
        result = _extractFullFile(file, filePath);
      }

      // 缓存结果
      if (useCache && result.success && result.metadata != null) {
        _cacheResult(filePath, fileSize, result);
      }

      // 更新统计
      _updateStatistics(result, stopwatch.elapsed);

      return result;
    } on FileSystemException catch (e) {
      final error = 'File system error: ${e.message}';
      AppLogger.w(error, _tag);
      return MetadataParseResult.failed(
        [],
        error,
        parseTime: stopwatch.elapsed,
      );
    } catch (e, stack) {
      final error = 'Unexpected error: $e';
      AppLogger.e(error, e, stack, _tag);
      return MetadataParseResult.failed(
        [],
        error,
        parseTime: stopwatch.elapsed,
      );
    }
  }

  /// 从 PNG 字节中提取元数据
  ///
  /// [bytes] PNG 字节数据
  /// [filePathForLog] 可选的文件路径，用于错误日志记录
  /// [useCache] 是否使用解析结果缓存（默认 false，因为字节数据通常不重复）
  static MetadataParseResult parseFromPng(
    Uint8List bytes, {
    String? filePathForLog,
    bool useCache = false,
  }) {
    final stopwatch = Stopwatch()..start();
    _statistics.totalAttempts++;

    final triedParsers = <String>[];
    final fileInfo = filePathForLog != null ? 'file=$filePathForLog, ' : '';

    // 检查缓存
    if (useCache) {
      final cacheKey = _generateBytesCacheKey(bytes);
      final cached = _resultCache[cacheKey];
      if (cached != null) {
        AppLogger.d('Cache hit for bytes, returning cached result', _tag);
        return cached;
      }
    }

    try {
      // 快速检查 PNG 文件头
      if (!isPngHeader(bytes)) {
        final error = 'Not a valid PNG file header, ${fileInfo}bytes length=${bytes.length}';
        AppLogger.w(error, _tag);
        return MetadataParseResult.failed(
          triedParsers,
          error,
          parseTime: stopwatch.elapsed,
          bytesRead: bytes.length,
        );
      }

      // AppLogger.d(
      //   'PNG header valid, ${fileInfo}bytes length=${bytes.length}, starting decode...',
      //   _tag,
      // );

      // 使用 image 包解析 PNG
      final decoder = img.PngDecoder();
      final info = decoder.startDecode(bytes);

      if (info == null) {
        // 如果部分数据解码失败，可能是数据不完整
        final error = bytes.length < 1024 * 1024 // 小于1MB认为是部分读取
            ? 'Failed to decode PNG (incomplete data?)'
            : 'Failed to decode PNG';
        // 【扫描时日志太频繁，禁用】
        // AppLogger.w(
        //   'PngDecoder.startDecode returned null, ${fileInfo}bytes length=${bytes.length}. $error',
        //   _tag,
        // );
        return MetadataParseResult.failed(
          triedParsers,
          error,
          parseTime: stopwatch.elapsed,
          bytesRead: bytes.length,
        );
      }

      final pngInfo = info as img.PngInfo;
      final textData = pngInfo.textData;

      // AppLogger.d(
      //   'PNG decoded successfully, ${fileInfo}textData fields: ${textData.keys.toList()}',
      //   _tag,
      // );

      // 使用 textData 解析
      final result = parseFromTextData(textData);

      // 缓存结果
      if (useCache && result.success) {
        final cacheKey = _generateBytesCacheKey(bytes);
        _resultCache[cacheKey] = result;
      }

      // 更新统计
      _updateStatistics(result, stopwatch.elapsed);

      return result;
    } catch (e, stack) {
      final error = 'Error parsing metadata from PNG (${fileInfo}bytes=${bytes.length}): $e';
      AppLogger.e(error, e, stack, _tag);
      return MetadataParseResult.failed(
        triedParsers,
        error,
        parseTime: stopwatch.elapsed,
        bytesRead: bytes.length,
      );
    }
  }

  /// 从 PNG textData Map 中解析元数据
  ///
  /// 这是主要的解析入口，可以被 PngMetadataExtractor 和其他服务直接使用
  static MetadataParseResult parseFromTextData(Map<String, String> textData) {
    final stopwatch = Stopwatch()..start();
    final triedParsers = <String>[];

    try {
      // AppLogger.d('Parsing textData with ${textData.length} entries', _tag);

      // 尝试每个解析器
      for (final parser in _parsers) {
        triedParsers.add(parser.name);

        try {
          final metadata = parser.parse(textData);
          if (metadata != null) {
            // 扫描时成功日志太频繁，只在调试时开启
            // AppLogger.i(
            //   'Metadata parsed successfully by ${parser.name}: ${metadata.prompt.substring(0, metadata.prompt.length > 30 ? 30 : metadata.prompt.length)}...',
            //   _tag,
            // );

            // 更新解析器统计
            _statistics.parserSuccessCounts[parser.name] =
                (_statistics.parserSuccessCounts[parser.name] ?? 0) + 1;

            final result = MetadataParseResult.success(
              metadata,
              parser.name,
              parser.getRawData(textData) ?? '',
              triedParsers,
              parseTime: stopwatch.elapsed,
            );

            _updateStatistics(result, stopwatch.elapsed);
            return result;
          }
        } catch (e) {
          // AppLogger.d('Parser ${parser.name} failed: $e', _tag);
          _statistics.parserFailureCounts[parser.name] =
              (_statistics.parserFailureCounts[parser.name] ?? 0) + 1;
        }
      }

      // 所有解析器都失败，尝试智能组合
      final combined = _tryCombineParsers(textData);
      if (combined != null) {
        triedParsers.add('CombinedParser');
        final result = MetadataParseResult.success(
          combined,
          'Combined',
          'Multiple sources',
          triedParsers,
          parseTime: stopwatch.elapsed,
        );
        _updateStatistics(result, stopwatch.elapsed);
        return result;
      }

      final error = 'No parser could extract metadata from ${textData.length} fields';
      // AppLogger.d(error, _tag);
      return MetadataParseResult.failed(
        triedParsers,
        error,
        parseTime: stopwatch.elapsed,
      );
    } catch (e, stack) {
      final error = 'Error parsing metadata from textData: $e';
      AppLogger.e(error, e, stack, _tag);
      return MetadataParseResult.failed(
        triedParsers,
        error,
        parseTime: stopwatch.elapsed,
      );
    }
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
  static Uint8List embedTextChunkOnly(Uint8List originalPng, String keyword, String text) {
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

        // 如果存在相同 keyword 的 chunk，替换它
        if (chunk.type == 'tEXt' && !textChunkAdded) {
          final nullIndex = chunk.data.indexOf(0);
          if (nullIndex > 0) {
            final existingKeyword = latin1.decode(chunk.data.sublist(0, nullIndex));
            if (existingKeyword == keyword) {
              _writeTextChunk(output, keyword, text);
              textChunkAdded = true;
              continue; // 跳过原始 chunk
            }
          }
        }

        // 在第一个 IDAT 之前插入新 chunk（PNG 规范建议）
        if (i == idatIndex && !textChunkAdded) {
          _writeTextChunk(output, keyword, text);
          textChunkAdded = true;
        }

        // 写入原始 chunk
        _writeChunk(output, chunk.type, chunk.data);
      }

      // 如果还没添加（没有 IDAT 的情况），追加到末尾
      if (!textChunkAdded) {
        _writeTextChunk(output, keyword, text);
      }

      return output.toBytes();
    } catch (e, stack) {
      AppLogger.e('[UnifiedMetadataParser] Failed to embed text chunk', e, stack, _tag);
      // 失败时返回原始数据
      return originalPng;
    }
  }

  /// 渐进式读取策略
  ///
  /// 按阈值逐步扩大读取范围，直到找到元数据或读取完整文件
  static MetadataParseResult _extractGradual(
    File file,
    String filePath,
    int fileSize,
  ) {
    // AppLogger.d('[UnifiedMetadataParser] Using gradual read strategy', _tag);
    _statistics.gradualReadAttempts++;

    // 如果文件很小，直接完整读取
    if (fileSize <= _gradualReadThresholds.first) {
      // AppLogger.d(
      //   '[UnifiedMetadataParser] Small file (${fileSize ~/ 1024}KB), reading entirely',
      //   _tag,
      // );
      return _extractFullFile(file, filePath);
    }

    // 按阈值逐步尝试
    for (final threshold in _gradualReadThresholds) {
      if (fileSize <= threshold) {
        // 文件小于当前阈值，直接完整读取
        // AppLogger.d(
        //   '[UnifiedMetadataParser] File size <= ${threshold ~/ 1024}KB, reading entirely',
        //   _tag,
        // );
        return _extractFullFile(file, filePath);
      }

      // 尝试读取到当前阈值
      // AppLogger.d(
      //   '[UnifiedMetadataParser] Trying ${threshold ~/ 1024}KB read...',
      //   _tag,
      // );
      final result = _extractWithLimit(file, filePath, threshold, fileSize);

      if (result.success) {
        // AppLogger.i(
        //   '[UnifiedMetadataParser] Metadata found at ${threshold ~/ 1024}KB threshold',
        //   _tag,
        // );
        _statistics.gradualReadSuccesses++;
        return result;
      }

      // AppLogger.d(
      //   '[UnifiedMetadataParser] No metadata in first ${threshold ~/ 1024}KB, will expand...',
      //   _tag,
      // );
    }

    // 所有阈值都尝试过，读取完整文件
    // AppLogger.d(
    //   '[UnifiedMetadataParser] No metadata in thresholds, trying full file read...',
    //   _tag,
    // );
    return _extractFullFile(file, filePath);
  }

  /// 读取完整文件并提取元数据
  static MetadataParseResult _extractFullFile(File file, String filePath) {
    // AppLogger.d('[UnifiedMetadataParser] Reading full file...', _tag);
    try {
      final bytes = file.readAsBytesSync();
      // AppLogger.d(
      //   '[UnifiedMetadataParser] Full read: ${bytes.length} bytes',
      //   _tag,
      // );
      return parseFromPng(bytes, filePathForLog: filePath);
    } catch (e) {
      final error = 'Error reading full file: $e';
      AppLogger.e(error, e, null, _tag);
      return MetadataParseResult.failed(
        [],
        error,
        bytesRead: file.lengthSync(),
      );
    }
  }

  /// 按指定限制读取文件并提取元数据
  ///
  /// 注意：在 Windows 上，raf.readSync() 可能不会一次返回所有请求的字节，
  /// 需要循环读取直到获得足够的字节。
  static MetadataParseResult _extractWithLimit(
    File file,
    String filePath,
    int maxBytes,
    int fileSize,
  ) {
    try {
      Uint8List bytes;

      if (fileSize <= maxBytes) {
        // 文件本身就小于限制，完整读取
        bytes = file.readAsBytesSync();
      } else {
        // 部分读取：循环确保读取完整的 maxBytes
        final raf = file.openSync();
        try {
          final buffer = BytesBuilder();
          var remaining = maxBytes;
          while (remaining > 0) {
            final chunk = raf.readSync(remaining);
            if (chunk.isEmpty) break; // 文件结束或错误
            buffer.add(chunk);
            remaining -= chunk.length;
          }
          bytes = buffer.toBytes();
        } finally {
          raf.closeSync();
        }
      }

      // AppLogger.d(
      //   '[UnifiedMetadataParser] Read ${bytes.length} bytes (requested $maxBytes), decoding...',
      //   _tag,
      // );

      return parseFromPng(bytes, filePathForLog: filePath);
    } catch (e) {
      final error = 'Error with ${maxBytes ~/ 1024}KB read: $e';
      AppLogger.d(error, _tag);
      return MetadataParseResult.failed(
        [],
        error,
        bytesRead: maxBytes,
      );
    }
  }

  /// 手动解析 PNG chunks
  static List<_PngChunk> _parsePngChunks(Uint8List bytes) {
    final chunks = <_PngChunk>[];
    var offset = 8; // 跳过 PNG 文件头

    while (offset < bytes.length) {
      if (offset + 12 > bytes.length) break;

      // 读取 chunk 长度（4字节，大端序）
      final length = ByteData.sublistView(bytes, offset, offset + 4).getUint32(0);

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

  /// 写入 tEXt chunk 到 builder
  static void _writeTextChunk(BytesBuilder builder, String keyword, String text) {
    final keywordBytes = latin1.encode(keyword);
    final textBytes = latin1.encode(text);

    final data = Uint8List(keywordBytes.length + 1 + textBytes.length);
    data.setAll(0, keywordBytes);
    data[keywordBytes.length] = 0; // null separator
    data.setAll(keywordBytes.length + 1, textBytes);

    _writeChunk(builder, 'tEXt', data);
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

  /// 更新 PNG 的 tEXt chunk 中的 Comment 字段
  static Future<Uint8List> _updateTextChunk(Uint8List bytes, String metadataJson) async {
    try {
      final chunks = _parsePngChunks(bytes);
      final output = BytesBuilder();

      // 写入 PNG 文件头
      output.add(bytes.sublist(0, 8));

      var commentUpdated = false;

      for (final chunk in chunks) {
        if (chunk.type == 'tEXt' && !commentUpdated) {
          // 解析现有的 tEXt chunk
          final nullIndex = chunk.data.indexOf(0);

          if (nullIndex > 0) {
            final keyword = latin1.decode(chunk.data.sublist(0, nullIndex));

            if (keyword == 'Comment') {
              // 更新 Comment chunk
              final newComment = _createTextChunk('Comment', metadataJson);
              output.add(newComment);
              commentUpdated = true;
              continue; // 跳过原始 chunk
            }
          }
        }

        // 写入原始 chunk
        output.add(_createChunk(chunk.type, chunk.data));
      }

      // 如果没有找到 Comment chunk，添加一个新的
      if (!commentUpdated) {
        final newComment = _createTextChunk('Comment', metadataJson);
        // 在 IHDR 之后插入（通常是第二个位置）
        final ihdrEnd = _findChunkEnd(bytes, 'IHDR');
        if (ihdrEnd > 0) {
          final result = output.toBytes();
          final before = result.sublist(0, ihdrEnd);
          final after = result.sublist(ihdrEnd);
          return Uint8List.fromList([...before, ...newComment, ...after]);
        }
      }

      return output.toBytes();
    } catch (e) {
      AppLogger.w('[UnifiedMetadataParser] Failed to update tEXt chunk: $e', _tag);
      return bytes; // 失败时返回原始数据
    }
  }

  /// 创建 tEXt chunk
  static Uint8List _createTextChunk(String keyword, String text) {
    final keywordBytes = latin1.encode(keyword);
    final textBytes = latin1.encode(text);
    final data = Uint8List(keywordBytes.length + 1 + textBytes.length);

    data.setRange(0, keywordBytes.length, keywordBytes);
    data[keywordBytes.length] = 0; // null separator
    data.setRange(keywordBytes.length + 1, data.length, textBytes);

    return _createChunk('tEXt', data);
  }

  /// 创建 PNG chunk
  static Uint8List _createChunk(String type, Uint8List data) {
    final output = BytesBuilder();

    // Length (4 bytes, big-endian)
    final lengthBytes = ByteData(4)..setUint32(0, data.length);
    output.add(lengthBytes.buffer.asUint8List());

    // Type (4 bytes)
    final typeBytes = latin1.encode(type);
    output.add(typeBytes);

    // Data
    output.add(data);

    // CRC32 (type + data)
    final crcInput = Uint8List(typeBytes.length + data.length);
    crcInput.setRange(0, typeBytes.length, typeBytes);
    crcInput.setRange(typeBytes.length, crcInput.length, data);
    final crc = _crc32(crcInput);
    final crcBytes = ByteData(4)..setUint32(0, crc);
    output.add(crcBytes.buffer.asUint8List());

    return output.toBytes();
  }

  /// 查找 chunk 的结束位置
  static int _findChunkEnd(Uint8List bytes, String chunkType) {
    var offset = 8; // 跳过 PNG 文件头

    while (offset < bytes.length) {
      if (offset + 8 > bytes.length) break;

      final length = ByteData.sublistView(bytes, offset, offset + 4).getUint32(0);
      final type = latin1.decode(bytes.sublist(offset + 4, offset + 8));

      if (type == chunkType) {
        return offset + 12 + length; // length(4) + type(4) + data(length) + crc(4)
      }

      offset += 12 + length;
    }

    return 0;
  }

  /// CRC32 计算（PNG 标准）
  static int _crc32(Uint8List data) {
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

  /// 嵌入 stealth 数据到 alpha 通道
  static Future<Uint8List> _embedStealthData(Uint8List imageBytes, String metadataJson) async {
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

  /// 缓存解析结果
  static void _cacheResult(String filePath, int fileSize, MetadataParseResult result) {
    final cacheKey = '$filePath:$fileSize:${result.metadata?.prompt.hashCode ?? 0}';
    _resultCache[cacheKey] = result;

    // 限制缓存大小（保留最近 100 个结果）
    if (_resultCache.length > 100) {
      final oldestKey = _resultCache.keys.first;
      _resultCache.remove(oldestKey);
    }
  }

  /// 生成字节缓存键
  static String _generateBytesCacheKey(Uint8List bytes) {
    // 使用前 1KB 的哈希作为缓存键
    final dataToHash = bytes.length > 1024 ? bytes.sublist(0, 1024) : bytes;
    return dataToHash.hashCode.toString();
  }

  /// 更新统计信息
  static void _updateStatistics(MetadataParseResult result, Duration parseTime) {
    _statistics.totalParseTime += parseTime;
    if (result.success) {
      _statistics.successfulParses++;
    } else {
      _statistics.failedParses++;
    }
  }

  /// 获取解析统计
  static ParseStatistics get statistics => _statistics;

  /// 重置统计
  static void resetStatistics() => _statistics.reset();

  /// 清除解析结果缓存
  static void clearCache() => _resultCache.clear();

  /// 检查是否为 PNG 文件
  /// 尝试组合多个解析器的结果
  static NaiImageMetadata? _tryCombineParsers(Map<String, String> textData) {
    // 收集所有可能的元数据片段
    String? prompt;
    String? negativePrompt;
    String? sampler;
    int? steps;
    double? cfgScale;
    int? seed;
    int? width;
    int? height;
    String? model;
    String? software;

    // 尝试从各个字段提取信息
    for (final entry in textData.entries) {
      final key = entry.key.toLowerCase();
      final value = entry.value;

      // Prompt 字段
      if (key.contains('prompt') && !key.contains('negative')) {
        prompt ??= value;
      }

      // Negative prompt 字段
      if (key.contains('negative') || key.contains('uc')) {
        negativePrompt ??= value;
      }

      // 尝试解析 JSON
      if (value.startsWith('{')) {
        try {
          final json = jsonDecode(value) as Map<String, dynamic>;

          prompt ??= _extractString(json, ['prompt', 'positive_prompt', 'text']);
          negativePrompt ??= _extractString(json, ['negative_prompt', 'uc', 'negative']);
          sampler ??= _extractString(json, ['sampler', 'sampler_name', 'scheduler']);
          steps ??= _extractInt(json, ['steps', 'num_inference_steps', 'step']);
          cfgScale ??= _extractDouble(json, ['cfg_scale', 'scale', 'guidance_scale', 'cfg']);
          seed ??= _extractInt(json, ['seed', 'noise_seed', 'random_seed']);
          width ??= _extractInt(json, ['width', 'w', 'image_width']);
          height ??= _extractInt(json, ['height', 'h', 'image_height']);
          model ??= _extractString(json, ['model', 'model_name', 'checkpoint', 'model_hash']);
          software ??= _extractString(json, ['software', 'source', 'generator', 'app']);
        } catch (_) {
          // 不是有效的 JSON
        }
      }

      // 解析文本格式的参数
      if (value.contains('Steps:') || value.contains('CFG')) {
        final params = _parsePlainTextParams(value);
        steps ??= params['steps'];
        sampler ??= params['sampler'];
        cfgScale ??= params['cfg_scale'];
        seed ??= params['seed'];
      }
    }

    // 如果至少找到了 prompt，创建元数据
    if (prompt != null && prompt.isNotEmpty) {
      return NaiImageMetadata(
        prompt: prompt,
        negativePrompt: negativePrompt ?? '',
        seed: seed ?? 0,
        sampler: sampler ?? 'Unknown',
        steps: steps ?? 0,
        scale: cfgScale ?? 7.0,
        width: width ?? 0,
        height: height ?? 0,
        model: model ?? 'Unknown',
        software: software ?? 'Unknown',
        rawJson: textData.toString(),
      );
    }

    return null;
  }

  /// 从 JSON 中提取字符串
  static String? _extractString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  /// 从 JSON 中提取整数
  static int? _extractInt(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      if (value is double) return value.toInt();
    }
    return null;
  }

  /// 从 JSON 中提取浮点数
  static double? _extractDouble(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);
    }
    return null;
  }

  /// 解析纯文本格式的参数
  static Map<String, dynamic> _parsePlainTextParams(String text) {
    final result = <String, dynamic>{};

    // 匹配 "Key: Value" 格式
    final regex = RegExp(r'(\w+(?:\s+\w+)?):\s*([^,\n]+)');
    final matches = regex.allMatches(text);

    for (final match in matches) {
      final key = match.group(1)?.trim();
      final value = match.group(2)?.trim();
      if (key == null || value == null) continue;

      switch (key.toLowerCase()) {
        case 'steps':
          result['steps'] = int.tryParse(value);
          break;
        case 'sampler':
          result['sampler'] = value;
          break;
        case 'cfg scale':
        case 'cfg':
        case 'scale':
          result['cfg_scale'] = double.tryParse(value);
          break;
        case 'seed':
          result['seed'] = int.tryParse(value);
          break;
        case 'size':
          final sizeParts = value.split('x');
          if (sizeParts.length == 2) {
            result['width'] = int.tryParse(sizeParts[0].trim());
            result['height'] = int.tryParse(sizeParts[1].trim());
          }
          break;
        case 'model':
        case 'model hash':
          result['model'] = value;
          break;
      }
    }

    return result;
  }
}

/// PNG chunk 数据结构
class _PngChunk {
  final String type;
  final Uint8List data;

  _PngChunk(this.type, this.data);
}

/// 元数据解析器接口
abstract class MetadataParser {
  String get name;
  NaiImageMetadata? parse(Map<String, String> textData);
  String? getRawData(Map<String, String> textData);
}

/// NovelAI 解析器
class NovelAiParser implements MetadataParser {
  @override
  String get name => 'NovelAI';

  @override
  NaiImageMetadata? parse(Map<String, String> textData) {
    // 尝试所有可能的字段
    final fieldsToTry = ['Comment', 'parameters', 'nai', 'novelai'];

    for (final field in fieldsToTry) {
      final text = textData[field];
      if (text == null || text.isEmpty) continue;

      try {
        final json = jsonDecode(text) as Map<String, dynamic>;
        // AppLogger.d(
        //   'NovelAiParser: Parsed JSON from "$field", keys=${json.keys.toList()}',
        //   'UnifiedMetadataParser',
        // );

        // 直接格式
        if (json.containsKey('prompt')) {
          // AppLogger.d(
          //   'NovelAiParser: Found prompt field, creating metadata...',
          //   'UnifiedMetadataParser',
          // );
          try {
            final result = NaiImageMetadata.fromNaiComment(json, rawJson: text);
            // AppLogger.d('NovelAiParser: Metadata created successfully', 'UnifiedMetadataParser');
            return result;
          } catch (e, stack) {
            AppLogger.e(
              'NovelAiParser: Failed to create metadata fromNaiComment',
              e,
              stack,
              'UnifiedMetadataParser',
            );
            continue;
          }
        }

        // 嵌套格式
        if (json.containsKey('Comment')) {
          final comment = json['Comment'];
          // AppLogger.d(
          //   'NovelAiParser: Found nested Comment field, type=${comment.runtimeType}',
          //   'UnifiedMetadataParser',
          // );

          if (comment is String) {
            try {
              final commentJson = jsonDecode(comment) as Map<String, dynamic>;
              AppLogger.d(
                'NovelAiParser: Nested JSON parsed, keys=${commentJson.keys.toList()}',
                'UnifiedMetadataParser',
              );

              final result = NaiImageMetadata.fromNaiComment(commentJson, rawJson: text);
              // AppLogger.d('NovelAiParser: Metadata created from nested Comment', 'UnifiedMetadataParser');
              return result;
            } catch (e, stack) {
              AppLogger.e(
                'NovelAiParser: Failed to parse nested Comment',
                e,
                stack,
                'UnifiedMetadataParser',
              );
              continue;
            }
          } else if (comment is Map) {
            try {
              final result = NaiImageMetadata.fromNaiComment(
                comment as Map<String, dynamic>,
                rawJson: text,
              );
              AppLogger.d('NovelAiParser: Metadata created from nested Comment Map', 'UnifiedMetadataParser');
              return result;
            } catch (e, stack) {
              AppLogger.e(
                'NovelAiParser: Failed to parse nested Comment Map',
                e,
                stack,
                'UnifiedMetadataParser',
              );
              continue;
            }
          }
        }
      } catch (e) {
        AppLogger.d('NovelAiParser: Failed to parse field "$field": $e', 'UnifiedMetadataParser');
        continue;
      }
    }

    return null;
  }

  @override
  String? getRawData(Map<String, String> textData) {
    return textData['Comment'] ?? textData['parameters'];
  }
}

/// Stable Diffusion WebUI 解析器（同时支持 AUTOMATIC1111 格式）
class WebUiParser implements MetadataParser {
  @override
  String get name => 'WebUI';

  @override
  NaiImageMetadata? parse(Map<String, String> textData) {
    // 尝试所有可能的字段（包括 AUTOMATIC1111 的 Description 字段）
    final fieldsToTry = [
      'parameters',
      'SD:parameters',
      'prompt',
      'Description',
      'description',
    ];

    for (final field in fieldsToTry) {
      final text = textData[field];
      if (text == null || text.isEmpty) continue;

      final result = _parseWebUiText(text);
      if (result != null) return result;
    }

    return null;
  }

  NaiImageMetadata? _parseWebUiText(String text) {
    // 检查是否是 WebUI 格式
    if (!text.contains('Steps:') && !text.contains('Sampler:')) {
      return null;
    }

    String? prompt;
    String? negativePrompt;

    // 分割正向和负向提示词
    final negPromptIndex = text.indexOf('Negative prompt:');
    if (negPromptIndex != -1) {
      prompt = text.substring(0, negPromptIndex).trim();
      final remaining = text.substring(negPromptIndex + 'Negative prompt:'.length);
      final stepsIndex = remaining.indexOf('Steps:');
      if (stepsIndex != -1) {
        negativePrompt = remaining.substring(0, stepsIndex).trim();
      }
    } else {
      // 尝试直接找 Steps:
      final stepsIndex = text.indexOf('Steps:');
      if (stepsIndex != -1) {
        prompt = text.substring(0, stepsIndex).trim();
      }
    }

    if (prompt == null || prompt.isEmpty) {
      return null;
    }

    // 解析参数
    final params = UnifiedMetadataParser._parsePlainTextParams(text);

    return NaiImageMetadata(
      prompt: prompt,
      negativePrompt: negativePrompt ?? '',
      seed: params['seed'] ?? 0,
      sampler: params['sampler'] ?? 'Unknown',
      steps: params['steps'] ?? 0,
      scale: params['cfg_scale'] ?? 7.0,
      width: params['width'] ?? 0,
      height: params['height'] ?? 0,
      model: params['model'] ?? 'Unknown',
      software: 'Stable Diffusion WebUI',
      rawJson: text,
    );
  }

  @override
  String? getRawData(Map<String, String> textData) {
    return textData['parameters'] ??
        textData['SD:parameters'] ??
        textData['Description'] ??
        textData['description'];
  }
}

/// ComfyUI 解析器
class ComfyUiParser implements MetadataParser {
  @override
  String get name => 'ComfyUI';

  @override
  NaiImageMetadata? parse(Map<String, String> textData) {
    final workflow = textData['workflow'];
    final prompt = textData['prompt'];

    if (workflow == null && prompt == null) return null;

    try {
      // 尝试从 prompt 字段提取
      if (prompt != null && prompt.isNotEmpty) {
        final json = jsonDecode(prompt) as Map<String, dynamic>;

        // 查找 KSampler 节点
        String? positivePrompt;
        String? negativePrompt;
        String? sampler;
        int? steps;
        double? cfg;
        int? seed;

        for (final entry in json.entries) {
          final node = entry.value as Map<String, dynamic>;
          final classType = node['class_type'] as String?;

          if (classType?.contains('KSampler') == true) {
            final inputs = node['inputs'] as Map<String, dynamic>?;
            if (inputs != null) {
              sampler = inputs['sampler_name'] as String?;
              steps = inputs['steps'] as int?;
              cfg = (inputs['cfg'] as num?)?.toDouble();
              seed = inputs['seed'] as int?;
            }
          }

          // 提取提示词
          if (classType?.contains('CLIPTextEncode') == true) {
            final inputs = node['inputs'] as Map<String, dynamic>?;
            final text = inputs?['text'] as String?;
            if (text != null) {
              // 假设第一个是正向，第二个是负向（简化处理）
              if (positivePrompt == null) {
                positivePrompt = text;
              } else {
                negativePrompt = text;
              }
            }
          }
        }

        if (positivePrompt != null) {
          return NaiImageMetadata(
            prompt: positivePrompt,
            negativePrompt: negativePrompt ?? '',
            seed: seed ?? 0,
            sampler: sampler ?? 'Unknown',
            steps: steps ?? 0,
            scale: cfg ?? 7.0,
            model: 'Unknown',
            software: 'ComfyUI',
            rawJson: prompt,
          );
        }
      }
    } catch (e) {
      AppLogger.d('ComfyUI parser failed: $e', 'UnifiedMetadataParser');
    }

    return null;
  }

  @override
  String? getRawData(Map<String, String> textData) {
    return textData['prompt'] ?? textData['workflow'];
  }
}

/// InvokeAI 解析器
class InvokeAiParser implements MetadataParser {
  @override
  String get name => 'InvokeAI';

  @override
  NaiImageMetadata? parse(Map<String, String> textData) {
    final sdMetadata = textData['sd-metadata'];
    if (sdMetadata == null) return null;

    try {
      final json = jsonDecode(sdMetadata) as Map<String, dynamic>;

      final image = json['image'] as Map<String, dynamic>?;
      if (image == null) return null;

      final prompt = image['prompt'] as List<dynamic>?;
      final positivePrompt = prompt?.map((p) => p['prompt'] as String?).join(', ') ?? '';

      return NaiImageMetadata(
        prompt: positivePrompt,
        negativePrompt: image['negative_prompt']?['prompt'] as String? ?? '',
        seed: image['seed'] as int? ?? 0,
        sampler: image['sampler'] as String? ?? 'Unknown',
        steps: image['steps'] as int? ?? 0,
        scale: (image['cfg_scale'] as num?)?.toDouble() ?? 7.0,
        width: image['width'] as int? ?? 0,
        height: image['height'] as int? ?? 0,
        model: image['model'] as String? ?? 'Unknown',
        software: 'InvokeAI',
        rawJson: sdMetadata,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  String? getRawData(Map<String, String> textData) {
    return textData['sd-metadata'];
  }
}

/// 通用 JSON 元数据解析器
///
/// 用于解析格式相似的 JSON 元数据（Fooocus、Draw Things 等）
class JsonGenericParser implements MetadataParser {
  @override
  final String name;
  final List<String> fieldsToTry;
  final String software;
  final List<String> scaleKeys;

  JsonGenericParser({
    required this.name,
    required this.fieldsToTry,
    required this.software,
    this.scaleKeys = const ['cfg_scale', 'scale'],
  });

  @override
  NaiImageMetadata? parse(Map<String, String> textData) {
    for (final field in fieldsToTry) {
      final text = textData[field];
      if (text == null || text.isEmpty) continue;

      try {
        final json = jsonDecode(text) as Map<String, dynamic>;
        if (!json.containsKey('prompt')) continue;

        // 查找 scale 值（支持多个可能的键名）
        double? scale;
        for (final key in scaleKeys) {
          final value = json[key];
          if (value is num) {
            scale = value.toDouble();
            break;
          }
          if (value is String) {
            scale = double.tryParse(value);
            if (scale != null) break;
          }
        }

        return NaiImageMetadata(
          prompt: json['prompt'] as String? ?? '',
          negativePrompt: json['negative_prompt'] as String? ?? '',
          seed: (json['seed'] as num?)?.toInt() ?? 0,
          sampler: json['sampler'] as String? ?? 'Unknown',
          steps: (json['steps'] as num?)?.toInt() ?? 0,
          scale: scale ?? 7.0,
          width: (json['width'] as num?)?.toInt() ?? 0,
          height: (json['height'] as num?)?.toInt() ?? 0,
          model: json['model'] as String? ?? 'Unknown',
          software: software,
          rawJson: text,
        );
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  @override
  String? getRawData(Map<String, String> textData) {
    for (final field in fieldsToTry) {
      final data = textData[field];
      if (data != null) return data;
    }
    return null;
  }
}
