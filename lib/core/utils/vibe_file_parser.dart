import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:png_chunks_extract/png_chunks_extract.dart' as png_extract;

import '../../data/models/vibe/vibe_reference.dart';
import 'app_logger.dart';

/// Vibe 文件解析器
///
/// 支持以下格式:
/// - PNG 文件 (带 NovelAI_Vibe_Encoding_Base64 iTXt 元数据)
/// - .naiv4vibe JSON 文件
/// - .naiv4vibebundle JSON 包
/// - 其他图片格式 (作为原始图片处理)
class VibeFileParser {
  /// PNG iTXt 块中的 Vibe 编码关键字
  static const String _iTXtKeyword = 'NovelAI_Vibe_Encoding_Base64';

  /// 支持的图片扩展名
  static const List<String> _imageExtensions = [
    'png',
    'jpg',
    'jpeg',
    'webp',
    'gif',
    'bmp',
  ];

  /// 从文件字节和文件名解析 Vibe 参考
  ///
  /// 根据文件扩展名自动选择解析方式
  /// 支持智能检测：
  /// - 文件名包含 .naiv4vibebundle 但扩展名为 .png 时，优先尝试 bundle 解析
  /// - PNG 文件如果 iTXt 解析失败，尝试检测是否包含 JSON bundle 数据
  static Future<List<VibeReference>> parseFile(
    String fileName,
    Uint8List bytes, {
    double defaultStrength = 0.6,
  }) async {
    final extension = fileName.split('.').last.toLowerCase();
    final lowerFileName = fileName.toLowerCase();

    // 智能检测：文件名包含 .naiv4vibebundle 但扩展名为 .png
    // 这种情况通常是用户将 bundle 文件重命名为 .png
    if (lowerFileName.contains('.naiv4vibebundle') && extension == 'png') {
      AppLogger.i(
        'Detected bundle in filename, trying bundle parsing first: $fileName',
        'VibeParser',
      );
      try {
        // 尝试作为 bundle 解析
        final result = await fromBundle(
          fileName,
          bytes,
          defaultStrength: defaultStrength,
        );
        AppLogger.i(
          'Successfully parsed as bundle: ${result.length} vibes found',
          'VibeParser',
        );
        return result;
      } catch (e) {
        AppLogger.i(
          'Bundle parsing failed, falling back to PNG parsing: $e',
          'VibeParser',
        );
        // 失败则继续尝试 PNG 解析
      }
    }

    switch (extension) {
      case 'png':
        return [
          await fromPng(fileName, bytes, defaultStrength: defaultStrength),
        ];

      case 'naiv4vibe':
        return [
          await fromNaiV4Vibe(
            fileName,
            bytes,
            defaultStrength: defaultStrength,
          ),
        ];

      case 'naiv4vibebundle':
        return fromBundle(fileName, bytes, defaultStrength: defaultStrength);

      default:
        // 其他图片格式作为原始图片处理
        if (_imageExtensions.contains(extension)) {
          return [
            VibeReference(
              displayName: fileName,
              vibeEncoding: '',
              thumbnail: bytes,
              rawImageData: bytes,
              strength: defaultStrength,
              sourceType: VibeSourceType.rawImage,
            ),
          ];
        }
        throw FormatException('Unsupported file type: $extension');
    }
  }

  /// 从 PNG 文件解析 Vibe 参考（Isolate 版本）
  ///
  /// 在单独的 isolate 中执行解析，避免阻塞 UI 线程
  /// 适用于大文件或批量处理场景
  static Future<VibeReference> fromPngInIsolate(
    String fileName,
    Uint8List bytes, {
    double defaultStrength = 0.6,
  }) async {
    return Isolate.run(() async {
      return fromPng(
        fileName,
        bytes,
        defaultStrength: defaultStrength,
      );
    });
  }

  /// 从 PNG 文件解析 Vibe 参考
  ///
  /// 尝试从 iTXt 块中提取预编码的 Vibe 数据
  /// 如果没有找到，尝试检测是否包含 JSON bundle 数据（Embed Into Image 格式）
  /// 如果都没有找到，则作为原始图片处理
  static Future<VibeReference> fromPng(
    String fileName,
    Uint8List bytes, {
    double defaultStrength = 0.6,
  }) async {
    String? vibeEncoding;

    try {
      final chunks = png_extract.extractChunks(bytes);

      for (final chunk in chunks) {
        if (chunk['name'] == 'iTXt') {
          final iTXtData = chunk['data'] as Uint8List;
          vibeEncoding = _parseITXtChunk(iTXtData);
          if (vibeEncoding != null) {
            AppLogger.i(
              'Found pre-encoded Vibe data in PNG: $fileName',
              'VibeParser',
            );
            break;
          }
        }
      }

      if (vibeEncoding != null && vibeEncoding.isNotEmpty) {
        // 找到预编码数据 - 使用png类型（isPreEncoded = true）
        return VibeReference(
          displayName: fileName,
          vibeEncoding: vibeEncoding,
          thumbnail: bytes,
          strength: defaultStrength,
          sourceType: VibeSourceType.png, // png类型被isPreEncoded视为预编码
        );
      }

      // 没有找到 iTXt 数据，尝试检测 PNG 中是否包含 JSON 文本（Embed Into Image 格式）
      // 有些工具会将 bundle JSON 作为文本块嵌入 PNG
      AppLogger.i(
        'No iTXt Vibe data found, checking for embedded JSON: $fileName',
        'VibeParser',
      );
      
      final embeddedJson = _extractEmbeddedJsonFromPng(chunks);
      if (embeddedJson != null) {
        AppLogger.i(
          'Found embedded JSON data in PNG: $fileName',
          'VibeParser',
        );
        
        // 尝试解析为单个 vibe 或 bundle
        try {
          final jsonData = jsonDecode(embeddedJson) as Map<String, dynamic>;
          
          // 检查是否为 bundle
          if (jsonData.containsKey('vibes')) {
            AppLogger.i(
              'PNG contains embedded bundle, but parseFile should handle this',
              'VibeParser',
            );
          }
          
          // 检查是否为单个 vibe
          final extractedEncoding = _extractEncodingFromJson(jsonData);
          if (extractedEncoding != null) {
            final name = jsonData['name'] as String? ?? fileName;
            double strength = defaultStrength;
            final importInfo = jsonData['importInfo'] as Map<String, dynamic>?;
            if (importInfo != null && importInfo['strength'] != null) {
              strength = (importInfo['strength'] as num).toDouble();
            }
            
            return VibeReference(
              displayName: name,
              vibeEncoding: extractedEncoding,
              thumbnail: bytes,
              strength: strength.clamp(0.0, 1.0),
              sourceType: VibeSourceType.png,
            );
          }
        } catch (e) {
          AppLogger.d(
            'Failed to parse embedded JSON in PNG: $e',
            'VibeParser',
          );
        }
      }

      // 没有找到任何 Vibe 数据 - 作为原始图片处理
      AppLogger.i(
        'No pre-encoded Vibe data found in PNG: $fileName, '
            'will be encoded on demand (2 Anlas per image)',
        'VibeParser',
      );

      return VibeReference(
        displayName: fileName,
        vibeEncoding: '',
        thumbnail: bytes,
        rawImageData: bytes,
        strength: defaultStrength,
        sourceType: VibeSourceType.rawImage, // 需要编码，消耗2 Anlas
      );
    } catch (e, stack) {
      // 解析失败 - 记录错误日志，作为原始图片处理
      AppLogger.e(
        'Failed to parse Vibe from PNG: $fileName, '
            'falling back to raw image mode',
        e,
        stack,
        'VibeParser',
      );

      return VibeReference(
        displayName: fileName,
        vibeEncoding: '',
        thumbnail: bytes,
        rawImageData: bytes,
        strength: defaultStrength,
        sourceType: VibeSourceType.rawImage,
      );
    }
  }

  /// 从 PNG chunks 中提取嵌入的 JSON 数据
  /// 
  /// 检查 tEXt 和 zTXt chunks 中是否包含 JSON 数据
  static String? _extractEmbeddedJsonFromPng(List<dynamic> chunks) {
    for (final chunk in chunks) {
      final chunkName = chunk['name'] as String?;
      
      if (chunkName == 'tEXt' || chunkName == 'zTXt') {
        try {
          final data = chunk['data'] as Uint8List;
          final text = utf8.decode(data);
          
          // 检查是否包含 JSON 特征
          if (text.contains('"identifier"') || 
              text.contains('"novelai-vibe-transfer"') ||
              text.contains('"encodings"')) {
            // 尝试找到 JSON 开始位置
            final jsonStart = text.indexOf('{');
            if (jsonStart != -1) {
              final jsonText = text.substring(jsonStart);
              // 验证是否为有效 JSON
              jsonDecode(jsonText);
              return jsonText;
            }
          }
        } catch (e) {
          // 不是有效的 JSON，继续检查下一个 chunk
          continue;
        }
      }
    }
    return null;
  }

  /// 解析 PNG iTXt 块
  ///
  /// iTXt 块格式:
  /// - Keyword (null-terminated)
  /// - Compression flag (1 byte)
  /// - Compression method (1 byte)
  /// - Language tag (null-terminated)
  /// - Translated keyword (null-terminated)
  /// - Text
  static String? _parseITXtChunk(Uint8List data) {
    try {
      // 查找关键字结束位置
      final int keywordEndIndex = data.indexOf(0);
      if (keywordEndIndex == -1) return null;

      final keyword = utf8.decode(data.sublist(0, keywordEndIndex));
      if (keyword != _iTXtKeyword) return null;

      int currentIndex = keywordEndIndex + 1;

      // 检查压缩标志
      if (currentIndex >= data.length) return null;
      final compressionFlag = data[currentIndex++];
      if (compressionFlag != 0) {
        // 不支持压缩
        throw FormatException(
          'Unsupported iTXt compression flag: $compressionFlag',
        );
      }

      // 跳过压缩方法
      if (currentIndex >= data.length) return null;
      currentIndex++;

      // 跳过语言标签
      final int langTagEndIndex = data.indexOf(0, currentIndex);
      if (langTagEndIndex == -1) return null;
      currentIndex = langTagEndIndex + 1;

      // 跳过翻译后的关键字
      final int translatedKeywordEndIndex = data.indexOf(0, currentIndex);
      if (translatedKeywordEndIndex == -1) return null;
      currentIndex = translatedKeywordEndIndex + 1;

      // 提取文本内容
      if (currentIndex < data.length) {
        return utf8.decode(data.sublist(currentIndex));
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.d('Error parsing iTXt chunk: $e', 'VibeParser');
      }
    }

    return null;
  }

  /// 从导入信息中提取强度值
  static double _extractStrength(Map<String, dynamic>? importInfo, double defaultValue) {
    final strengthValue = importInfo?['strength'];
    return switch (strengthValue) {
      final double v => v,
      final int v => v.toDouble(),
      final String v => double.tryParse(v) ?? defaultValue,
      _ => defaultValue,
    };
  }

  /// 从 .naiv4vibe 文件解析 Vibe 参考
  static Future<VibeReference> fromNaiV4Vibe(
    String fileName,
    Uint8List bytes, {
    double defaultStrength = 0.6,
  }) async {
    final jsonString = utf8.decode(bytes);
    final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

    final name = jsonData['name'] as String? ?? fileName;
    final strength = _extractStrength(
      jsonData['importInfo'] as Map<String, dynamic>?,
      defaultStrength,
    );

    final vibeEncoding = _extractEncodingFromJson(jsonData);
    if (vibeEncoding == null) {
      throw ArgumentError(
        'Could not find valid encoding in .naiv4vibe file: $fileName',
      );
    }

    return VibeReference(
      displayName: name,
      vibeEncoding: vibeEncoding,
      thumbnail: null,
      strength: strength.clamp(0.0, 1.0),
      sourceType: VibeSourceType.naiv4vibe,
    );
  }

  /// 从 .naiv4vibebundle 文件解析多个 Vibe 参考
  static Future<List<VibeReference>> fromBundle(
    String fileName,
    Uint8List bytes, {
    double defaultStrength = 0.6,
  }) async {
    final jsonString = utf8.decode(bytes);
    final bundleData = jsonDecode(jsonString) as Map<String, dynamic>;
    final vibesList = bundleData['vibes'] as List<dynamic>? ?? [];

    final results = <VibeReference>[];

    for (var i = 0; i < vibesList.length; i++) {
      try {
        final vibeJson = vibesList[i] as Map<String, dynamic>;
        final name = vibeJson['name'] as String? ?? '$fileName#$i';
        final strength = _extractStrength(
          vibeJson['importInfo'] as Map<String, dynamic>?,
          defaultStrength,
        );

        final vibeEncoding = _extractEncodingFromJson(vibeJson);
        if (vibeEncoding != null) {
          results.add(
            VibeReference(
              displayName: name,
              vibeEncoding: vibeEncoding,
              thumbnail: null,
              strength: strength.clamp(0.0, 1.0),
              sourceType: VibeSourceType.naiv4vibebundle,
            ),
          );
        }
      } catch (e) {
        if (kDebugMode) {
          AppLogger.d(
            'Error parsing vibe entry $i in bundle: $e',
            'VibeParser',
          );
        }
      }
    }

    if (results.isEmpty) {
      throw ArgumentError('No valid vibes found in bundle: $fileName');
    }

    return results;
  }

  /// 从 JSON 数据中提取 Vibe 编码
  static String? _extractEncodingFromJson(Map<String, dynamic> jsonData) {
    final encodingsMap = jsonData['encodings'] as Map<String, dynamic>?;
    if (encodingsMap == null) return null;

    // 遍历 encodings 找到第一个有效的 encoding
    for (var modelKey in encodingsMap.keys) {
      final modelEncodings = encodingsMap[modelKey] as Map<String, dynamic>?;
      if (modelEncodings == null) continue;

      for (var typeKey in modelEncodings.keys) {
        final typeEncodingInfo =
            modelEncodings[typeKey] as Map<String, dynamic>?;
        if (typeEncodingInfo != null &&
            typeEncodingInfo.containsKey('encoding')) {
          final dynamic encodingValue = typeEncodingInfo['encoding'];
          if (encodingValue is String && encodingValue.isNotEmpty) {
            return encodingValue;
          }
        }
      }
    }

    return null;
  }

  /// 检查文件扩展名是否为支持的图片格式
  static bool isSupportedImageExtension(String extension) {
    final ext = extension.toLowerCase();
    return _imageExtensions.contains(ext) ||
        ext == 'naiv4vibe' ||
        ext == 'naiv4vibebundle';
  }

  /// 检查文件名是否为支持的格式
  static bool isSupportedFile(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return isSupportedImageExtension(extension);
  }
}
