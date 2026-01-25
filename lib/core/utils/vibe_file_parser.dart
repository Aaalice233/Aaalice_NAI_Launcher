import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:png_chunks_extract/png_chunks_extract.dart' as png_extract;

import '../../data/models/vibe/vibe_reference_v4.dart';
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
  static Future<List<VibeReferenceV4>> parseFile(
    String fileName,
    Uint8List bytes, {
    double defaultStrength = 0.6,
  }) async {
    final extension = fileName.split('.').last.toLowerCase();

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
            VibeReferenceV4(
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

  /// 从 PNG 文件解析 Vibe 参考
  ///
  /// 尝试从 iTXt 块中提取预编码的 Vibe 数据
  /// 如果没有找到，则作为原始图片处理
  /// 如果解析失败，记录错误日志并作为原始图片处理
  static Future<VibeReferenceV4> fromPng(
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
        return VibeReferenceV4(
          displayName: fileName,
          vibeEncoding: vibeEncoding,
          thumbnail: bytes,
          strength: defaultStrength,
          sourceType: VibeSourceType.png, // png类型被isPreEncoded视为预编码
        );
      } else {
        // 没有找到预编码数据 - 作为原始图片处理
        AppLogger.i(
          'No pre-encoded Vibe data found in PNG: $fileName, '
              'will be encoded on demand (2 Anlas per image)',
          'VibeParser',
        );

        return VibeReferenceV4(
          displayName: fileName,
          vibeEncoding: '',
          thumbnail: bytes,
          rawImageData: bytes,
          strength: defaultStrength,
          sourceType: VibeSourceType.rawImage, // 需要编码，消耗2 Anlas
        );
      }
    } catch (e, stack) {
      // 解析失败 - 记录错误日志，作为原始图片处理
      AppLogger.e(
        'Failed to parse Vibe from PNG: $fileName, '
            'falling back to raw image mode',
        e,
        stack,
        'VibeParser',
      );

      // 返回null会让调用方崩溃，所以我们返回rawImage类型
      // 但这也意味着用户会被收取编码费用
      // 更好的做法是通知用户解析失败
      return VibeReferenceV4(
        displayName: fileName,
        vibeEncoding: '',
        thumbnail: bytes,
        rawImageData: bytes,
        strength: defaultStrength,
        sourceType: VibeSourceType.rawImage,
      );
    }
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

  /// 从 .naiv4vibe 文件解析 Vibe 参考
  static Future<VibeReferenceV4> fromNaiV4Vibe(
    String fileName,
    Uint8List bytes, {
    double defaultStrength = 0.6,
  }) async {
    final jsonString = utf8.decode(bytes);
    final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

    // 提取名称
    final name = jsonData['name'] as String? ?? fileName;

    // 提取强度
    double strength = defaultStrength;
    final importInfo = jsonData['importInfo'] as Map<String, dynamic>?;
    if (importInfo != null && importInfo['strength'] != null) {
      final dynamic strengthValue = importInfo['strength'];
      if (strengthValue is double) {
        strength = strengthValue;
      } else if (strengthValue is int) {
        strength = strengthValue.toDouble();
      } else if (strengthValue is String) {
        strength = double.tryParse(strengthValue) ?? defaultStrength;
      }
    }

    // 提取编码
    final vibeEncoding = _extractEncodingFromJson(jsonData);
    if (vibeEncoding == null) {
      throw ArgumentError(
        'Could not find valid encoding in .naiv4vibe file: $fileName',
      );
    }

    return VibeReferenceV4(
      displayName: name,
      vibeEncoding: vibeEncoding,
      thumbnail: null, // .naiv4vibe 文件不包含缩略图
      strength: strength.clamp(0.0, 1.0),
      sourceType: VibeSourceType.naiv4vibe,
    );
  }

  /// 从 .naiv4vibebundle 文件解析多个 Vibe 参考
  static Future<List<VibeReferenceV4>> fromBundle(
    String fileName,
    Uint8List bytes, {
    double defaultStrength = 0.6,
  }) async {
    final jsonString = utf8.decode(bytes);
    final bundleData = jsonDecode(jsonString) as Map<String, dynamic>;
    final vibesList = bundleData['vibes'] as List<dynamic>? ?? [];

    final results = <VibeReferenceV4>[];

    for (var i = 0; i < vibesList.length; i++) {
      try {
        final vibeJson = vibesList[i] as Map<String, dynamic>;
        final name = vibeJson['name'] as String? ?? '$fileName#$i';

        // 提取强度
        double strength = defaultStrength;
        final importInfo = vibeJson['importInfo'] as Map<String, dynamic>?;
        if (importInfo != null && importInfo['strength'] != null) {
          final dynamic strengthValue = importInfo['strength'];
          if (strengthValue is double) {
            strength = strengthValue;
          } else if (strengthValue is int) {
            strength = strengthValue.toDouble();
          } else if (strengthValue is String) {
            strength = double.tryParse(strengthValue) ?? defaultStrength;
          }
        }

        final vibeEncoding = _extractEncodingFromJson(vibeJson);
        if (vibeEncoding != null) {
          results.add(
            VibeReferenceV4(
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
        // 继续处理其他条目
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
