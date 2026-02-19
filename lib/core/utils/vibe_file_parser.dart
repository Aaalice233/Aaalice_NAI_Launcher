import 'dart:async';
import 'dart:convert';

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
  /// PNG iTXt 块中的 Vibe 编码关键字（官方格式）
  static const String _iTXtKeyword = 'NovelAI_Vibe_Encoding_Base64';
  
  /// NAI 官方 iTXt 关键字（嵌入图片使用）
  static const String _naiDataKeyword = 'naidata';

  /// 最大处理的文件大小（20MB）
  static const int _maxFileSize = 20 * 1024 * 1024;

  /// 解析超时时间
  static const Duration _parseTimeout = Duration(seconds: 5);

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

  /// 从 PNG 文件解析 Vibe 参考（使用 Isolate 避免阻塞 UI）
  ///
  /// 尝试从 iTXt 块中提取预编码的 Vibe 数据
  /// 如果没有找到，尝试检测是否包含 JSON bundle 数据（Embed Into Image 格式）
  /// 如果都没有找到，则作为原始图片处理
  static Future<VibeReference> fromPng(
    String fileName,
    Uint8List bytes, {
    double defaultStrength = 0.6,
  }) async {
    // 文件大小检查
    if (bytes.length > _maxFileSize) {
      AppLogger.w(
        'PNG file too large (${bytes.length} bytes), treating as raw image: $fileName',
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

    try {
      // 使用 compute 将耗时操作移到 Isolate
      final result = await compute(
        _parsePngIsolate,
        _PngParseParams(
          fileName: fileName,
          bytes: bytes,
          defaultStrength: defaultStrength,
        ),
      ).timeout(_parseTimeout);
      return result;
    } on TimeoutException {
      AppLogger.w(
        'PNG parsing timeout, treating as raw image: $fileName',
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

  /// 从 PNG 文件提取所有 Vibe 数据（支持 Bundle）
  ///
  /// 用于拖放保存到库时检测是否为 bundle 格式
  /// 返回列表，如果是单个 vibe 则列表长度为 1
  static Future<List<VibeReference>> extractBundleFromPng(
    Uint8List bytes, {
    double defaultStrength = 0.6,
  }) async {
    try {
      final result = await compute(
        _extractBundleFromPngIsolate,
        _PngParseParams(
          fileName: 'bundle.png',
          bytes: bytes,
          defaultStrength: defaultStrength,
        ),
      ).timeout(_parseTimeout);
      return result;
    } catch (e, stack) {
      AppLogger.e(
        'Failed to extract bundle from PNG',
        e,
        stack,
        'VibeParser',
      );
      return [];
    }
  }

  /// 从 PNG 提取 Bundle 的 Isolate 方法
  static Future<List<VibeReference>> _extractBundleFromPngIsolate(
    _PngParseParams params,
  ) async {
    final results = <VibeReference>[];

    try {
      final chunks = png_extract.extractChunks(params.bytes);

      // 查找 iTXt chunk
      for (final chunk in chunks) {
        if (chunk['name'] == 'iTXt') {
          final iTXtData = chunk['data'] as Uint8List;
          final result = _parseITXtChunkWithKeyword(iTXtData);

          if (result != null && result.keyword == _naiDataKeyword) {
            // naidata 格式：Base64 编码的 JSON bundle
            try {
              final jsonBytes = base64.decode(result.content);
              final jsonData = jsonDecode(utf8.decode(jsonBytes))
                  as Map<String, dynamic>;

              final vibes = jsonData['vibes'] as List<dynamic>?;
              if (vibes != null && vibes.isNotEmpty) {
                for (var i = 0; i < vibes.length; i++) {
                  final vibeJson = vibes[i] as Map<String, dynamic>;
                  final extractedEncoding =
                      _extractEncodingFromNaiVibe(vibeJson);

                  if (extractedEncoding != null &&
                      extractedEncoding.isNotEmpty) {
                    final name = vibeJson['name'] as String? ??
                        '${params.fileName}#$i';
                    double strength = params.defaultStrength;
                    final importInfo =
                        vibeJson['importInfo'] as Map<String, dynamic>?;
                    if (importInfo != null &&
                        importInfo['strength'] != null) {
                      strength = (importInfo['strength'] as num).toDouble();
                    }

                    // 提取 vibe 自己的缩略图，如果没有则使用原图
                    final thumbnail = _extractThumbnailFromJson(vibeJson) ??
                        params.bytes;

                    results.add(
                      VibeReference(
                        displayName: name,
                        vibeEncoding: extractedEncoding,
                        thumbnail: thumbnail,
                        strength: strength.clamp(0.0, 1.0),
                        sourceType: VibeSourceType.png,
                      ),
                    );
                  }
                }
                return results;
              }
            } catch (e) {
              AppLogger.w('Failed to parse naidata bundle: $e', 'VibeParser');
            }
          } else if (result != null) {
            // NovelAI_Vibe_Encoding_Base64 格式：单个 encoding
            if (result.content.isNotEmpty) {
              results.add(
                VibeReference(
                  displayName: params.fileName,
                  vibeEncoding: result.content,
                  thumbnail: params.bytes,
                  strength: params.defaultStrength,
                  sourceType: VibeSourceType.png,
                ),
              );
              return results;
            }
          }
        }
      }

      // 没有找到 iTXt 数据，尝试检测 PNG 中是否包含 JSON 文本
      final embeddedJson = _extractEmbeddedJsonFromPng(chunks);
      if (embeddedJson != null) {
        try {
          final jsonData = jsonDecode(embeddedJson) as Map<String, dynamic>;
          final extractedEncoding = _extractEncodingFromJson(jsonData);
          if (extractedEncoding != null) {
            final name = jsonData['name'] as String? ?? params.fileName;
            double strength = params.defaultStrength;
            final importInfo =
                jsonData['importInfo'] as Map<String, dynamic>?;
            if (importInfo != null && importInfo['strength'] != null) {
              strength = (importInfo['strength'] as num).toDouble();
            }

            results.add(
              VibeReference(
                displayName: name,
                vibeEncoding: extractedEncoding,
                thumbnail: params.bytes,
                strength: strength.clamp(0.0, 1.0),
                sourceType: VibeSourceType.png,
              ),
            );
            return results;
          }
        } catch (e) {
          // 忽略 JSON 解析错误
        }
      }
    } catch (e) {
      AppLogger.w('Error extracting bundle from PNG: $e', 'VibeParser');
    }

    return results;
  }

  /// PNG 解析参数
  static Future<VibeReference> _parsePngIsolate(_PngParseParams params) async {
    String? iTxtContent;
    String? foundKeyword;

    try {
      final chunks = png_extract.extractChunks(params.bytes);

      for (final chunk in chunks) {
        if (chunk['name'] == 'iTXt') {
          final iTXtData = chunk['data'] as Uint8List;
          // 尝试解析 iTXt，同时获取内容和 keyword
          final result = _parseITXtChunkWithKeyword(iTXtData);
          if (result != null) {
            iTxtContent = result.content;
            foundKeyword = result.keyword;
            break;
          }
        }
      }

      if (iTxtContent != null && iTxtContent.isNotEmpty) {
        // 根据 keyword 类型处理数据
        if (foundKeyword == _naiDataKeyword) {
          // naidata 格式：Base64 编码的 JSON bundle
          try {
            final jsonBytes = base64.decode(iTxtContent);
            final jsonData = jsonDecode(utf8.decode(jsonBytes)) as Map<String, dynamic>;
            
            // 从 bundle 中提取第一个 vibe
            final vibes = jsonData['vibes'] as List<dynamic>?;
            if (vibes != null && vibes.isNotEmpty) {
              final firstVibe = vibes.first as Map<String, dynamic>;
              final extractedEncoding = _extractEncodingFromNaiVibe(firstVibe);
              
              if (extractedEncoding != null && extractedEncoding.isNotEmpty) {
                final name = firstVibe['name'] as String? ?? params.fileName;
                double strength = params.defaultStrength;
                final importInfo = firstVibe['importInfo'] as Map<String, dynamic>?;
                if (importInfo != null && importInfo['strength'] != null) {
                  strength = (importInfo['strength'] as num).toDouble();
                }

                return VibeReference(
                  displayName: name,
                  vibeEncoding: extractedEncoding,
                  thumbnail: params.bytes,
                  strength: strength.clamp(0.0, 1.0),
                  sourceType: VibeSourceType.png,
                );
              }
            }
          } catch (e) {
            AppLogger.w('Failed to parse naidata format: $e', 'VibeParser');
          }
        } else {
          // NovelAI_Vibe_Encoding_Base64 格式：直接是 encoding
          return VibeReference(
            displayName: params.fileName,
            vibeEncoding: iTxtContent,
            thumbnail: params.bytes,
            strength: params.defaultStrength,
            sourceType: VibeSourceType.png,
          );
        }
      }

      // 没有找到 iTXt 数据，尝试检测 PNG 中是否包含 JSON 文本
      final embeddedJson = _extractEmbeddedJsonFromPng(chunks);
      if (embeddedJson != null) {
        try {
          final jsonData = jsonDecode(embeddedJson) as Map<String, dynamic>;

          // 检查是否为单个 vibe
          final extractedEncoding = _extractEncodingFromJson(jsonData);
          if (extractedEncoding != null) {
            final name = jsonData['name'] as String? ?? params.fileName;
            double strength = params.defaultStrength;
            final importInfo = jsonData['importInfo'] as Map<String, dynamic>?;
            if (importInfo != null && importInfo['strength'] != null) {
              strength = (importInfo['strength'] as num).toDouble();
            }

            return VibeReference(
              displayName: name,
              vibeEncoding: extractedEncoding,
              thumbnail: params.bytes,
              strength: strength.clamp(0.0, 1.0),
              sourceType: VibeSourceType.png,
            );
          }
        } catch (e) {
          // 忽略 JSON 解析错误
        }
      }

      // 没有找到任何 Vibe 数据 - 作为原始图片处理
      return VibeReference(
        displayName: params.fileName,
        vibeEncoding: '',
        thumbnail: params.bytes,
        rawImageData: params.bytes,
        strength: params.defaultStrength,
        sourceType: VibeSourceType.rawImage,
      );
    } catch (e) {
      // 解析失败 - 作为原始图片处理
      return VibeReference(
        displayName: params.fileName,
        vibeEncoding: '',
        thumbnail: params.bytes,
        rawImageData: params.bytes,
        strength: params.defaultStrength,
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

  /// 解析 PNG iTXt 块（带 keyword 返回）
  ///
  /// iTXt 块格式:
  /// - Keyword (null-terminated)
  /// - Compression flag (1 byte)
  /// - Compression method (1 byte)
  /// - Language tag (null-terminated)
  /// - Translated keyword (null-terminated)
  /// - Text
  /// 
  /// 支持两种关键字:
  /// - NovelAI_Vibe_Encoding_Base64 (官方格式)
  /// - naidata (嵌入图片使用)
  /// 返回 ({String keyword, String content})? 的 Record 类型
  static ({String keyword, String content})? _parseITXtChunkWithKeyword(Uint8List data) {
    try {
      // 查找关键字结束位置
      final int keywordEndIndex = data.indexOf(0);
      if (keywordEndIndex == -1) return null;

      final keyword = utf8.decode(data.sublist(0, keywordEndIndex));
      // 支持两种关键字格式
      if (keyword != _iTXtKeyword && keyword != _naiDataKeyword) return null;

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
        final content = utf8.decode(data.sublist(currentIndex));
        return (keyword: keyword, content: content);
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.d('Error parsing iTXt chunk: $e', 'VibeParser');
      }
    }

    return null;
  }

  /// 从 NAI vibe 数据中提取 encoding
  /// 
  /// NAI 格式: encodings: {model: {hash: {encoding: "..."}}}
  static String? _extractEncodingFromNaiVibe(Map<String, dynamic> vibe) {
    final encodings = vibe['encodings'] as Map<String, dynamic>?;
    if (encodings == null) return null;

    // 获取第一个模型的 encoding
    final firstModel = encodings.values.firstOrNull as Map<String, dynamic>?;
    if (firstModel == null) return null;

    // NAI 格式: {hash: {encoding: "..."}} 或 {vibe: {encoding: "..."}}
    final hashData = firstModel.values.firstOrNull;
    if (hashData is Map<String, dynamic>) {
      return hashData['encoding'] as String?;
    }
    
    // 也可能是直接的 encoding 字段
    if (firstModel.containsKey('encoding')) {
      return firstModel['encoding'] as String?;
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
      final type = jsonData['type'] as String?;
      final hasEncodings = jsonData.containsKey('encodings');
      throw ArgumentError(
        '文件缺少有效的 Vibe encoding: $fileName '
        '(type=$type, hasEncodings=$hasEncodings). '
        '此文件可能已损坏或不完整，建议删除后重新保存。',
      );
    }

    // 提取缩略图
    final thumbnail = _extractThumbnailFromJson(jsonData);

    return VibeReference(
      displayName: name,
      vibeEncoding: vibeEncoding,
      thumbnail: thumbnail,
      strength: strength.clamp(0.0, 1.0),
      sourceType: VibeSourceType.naiv4vibe,
    );
  }

  /// 从 JSON 数据中提取缩略图
  static Uint8List? _extractThumbnailFromJson(Map<String, dynamic> jsonData) {
    try {
      final thumbnailBase64 = jsonData['thumbnail'] as String?;
      if (thumbnailBase64 != null && thumbnailBase64.isNotEmpty) {
        final base64Data = _extractBase64FromDataUri(thumbnailBase64);
        if (base64Data != null) {
          return base64Decode(base64Data);
        }
      }

      // 如果没有 thumbnail 字段，尝试从 image 字段提取
      final imageBase64 = jsonData['image'] as String?;
      if (imageBase64 != null && imageBase64.isNotEmpty) {
        final base64Data = _extractBase64FromDataUri(imageBase64);
        if (base64Data != null) {
          return base64Decode(base64Data);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.d('Error extracting thumbnail from JSON: $e', 'VibeParser');
      }
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
          final thumbnail = _extractThumbnailFromJson(vibeJson);
          results.add(
            VibeReference(
              displayName: name,
              vibeEncoding: vibeEncoding,
              thumbnail: thumbnail,
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

/// PNG 解析参数（用于 Isolate）
class _PngParseParams {
  final String fileName;
  final Uint8List bytes;
  final double defaultStrength;

  _PngParseParams({
    required this.fileName,
    required this.bytes,
    required this.defaultStrength,
  });
}
