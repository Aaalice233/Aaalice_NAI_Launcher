import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../data/models/vibe/vibe_reference.dart';
import 'app_logger.dart';
import 'novelai_vibe_codec.dart';

// 注意：已移除 png_chunks_extract 依赖，使用 image 包替代
// image 包的 PngDecoder.startDecode() 提供纯 Dart 的 PNG chunks 解析

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
      AppLogger.e('Failed to extract bundle from PNG', e, stack, 'VibeParser');
      return [];
    }
  }

  /// 从 PNG 提取 Bundle 的 Isolate 方法
  static Future<List<VibeReference>> _extractBundleFromPngIsolate(
    _PngParseParams params,
  ) async {
    final results = <VibeReference>[];

    try {
      // 使用 image 包的 PngDecoder - 纯 Dart 实现
      final decoder = img.PngDecoder();
      final info = decoder.startDecode(params.bytes);

      if (info == null) {
        return results;
      }

      // 从 PngInfo 获取 textData
      final pngInfo = info as img.PngInfo;
      final textData = pngInfo.textData;

      // 查找 iTXt chunk（NovelAI_Vibe_Encoding_Base64 或 naidata）
      for (final entry in textData.entries) {
        final keyword = entry.key;
        final content = entry.value;

        if (keyword == _naiDataKeyword) {
          // naidata 格式：Base64 编码的 JSON bundle
          try {
            final jsonBytes = base64.decode(content);
            final jsonData =
                jsonDecode(utf8.decode(jsonBytes)) as Map<String, dynamic>;

            final vibes = jsonData['vibes'] as List<dynamic>?;
            if (vibes != null && vibes.isNotEmpty) {
              for (var i = 0; i < vibes.length; i++) {
                final vibeJson = vibes[i] as Map<String, dynamic>;
                final extractedEncoding = _extractEncodingFromNaiVibe(vibeJson);

                if (extractedEncoding != null && extractedEncoding.isNotEmpty) {
                  final name =
                      vibeJson['name'] as String? ?? '${params.fileName}#$i';
                  double strength = params.defaultStrength;
                  var infoExtracted = 0.7;
                  final importInfo =
                      vibeJson['importInfo'] as Map<String, dynamic>?;
                  if (importInfo != null && importInfo['strength'] != null) {
                    strength = (importInfo['strength'] as num).toDouble();
                  }
                  infoExtracted = _extractInformationExtracted(
                    importInfo,
                    infoExtracted,
                  );

                  // 提取 vibe 自己的缩略图，如果没有则使用原图
                  final thumbnail =
                      _extractThumbnailFromJson(vibeJson) ?? params.bytes;
                  final rawImageData = _extractRawImageFromJson(vibeJson);

                  results.add(
                    VibeReference(
                      displayName: name,
                      vibeEncoding: extractedEncoding,
                      thumbnail: thumbnail,
                      rawImageData: rawImageData,
                      strength: VibeReference.sanitizeStrength(strength),
                      infoExtracted: infoExtracted,
                      encodingModel: _extractEncodingModelFromJson(vibeJson),
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
        } else if (keyword == _iTXtKeyword) {
          // NovelAI_Vibe_Encoding_Base64 格式：单个 encoding
          if (content.isNotEmpty) {
            results.add(
              VibeReference(
                displayName: params.fileName,
                vibeEncoding: content,
                thumbnail: params.bytes,
                rawImageData: params.bytes,
                strength: params.defaultStrength,
                sourceType: VibeSourceType.png,
              ),
            );
            return results;
          }
        }
      }

      // 没有找到 iTXt 数据，尝试检测 PNG 中是否包含 JSON 文本
      final embeddedJson = _extractEmbeddedJsonFromTextData(textData);
      if (embeddedJson != null) {
        try {
          final jsonData = jsonDecode(embeddedJson) as Map<String, dynamic>;
          final extractedEncoding = _extractEncodingFromJson(jsonData);
          if (extractedEncoding != null) {
            final name = jsonData['name'] as String? ?? params.fileName;
            double strength = params.defaultStrength;
            var infoExtracted = 0.7;
            final importInfo = jsonData['importInfo'] as Map<String, dynamic>?;
            if (importInfo != null && importInfo['strength'] != null) {
              strength = (importInfo['strength'] as num).toDouble();
            }
            infoExtracted = _extractInformationExtracted(
              importInfo,
              infoExtracted,
            );

            results.add(
              VibeReference(
                displayName: name,
                vibeEncoding: extractedEncoding,
                thumbnail: params.bytes,
                rawImageData: _extractRawImageFromJson(jsonData),
                strength: VibeReference.sanitizeStrength(strength),
                infoExtracted: infoExtracted,
                encodingModel: _extractEncodingModelFromJson(jsonData),
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
      // 使用 image 包的 PngDecoder - 纯 Dart 实现
      final decoder = img.PngDecoder();
      final info = decoder.startDecode(params.bytes);

      if (info == null) {
        return VibeReference(
          displayName: params.fileName,
          vibeEncoding: '',
          thumbnail: params.bytes,
          rawImageData: params.bytes,
          strength: params.defaultStrength,
          sourceType: VibeSourceType.rawImage,
        );
      }

      // 从 PngInfo 获取 textData
      final pngInfo = info as img.PngInfo;
      final textData = pngInfo.textData;

      for (final entry in textData.entries) {
        final keyword = entry.key;
        final content = entry.value;

        // 只处理我们关心的关键字
        if (keyword == _iTXtKeyword || keyword == _naiDataKeyword) {
          iTxtContent = content;
          foundKeyword = keyword;
          break;
        }
      }

      if (iTxtContent != null && iTxtContent.isNotEmpty) {
        // 根据 keyword 类型处理数据
        if (foundKeyword == _naiDataKeyword) {
          // naidata 格式：Base64 编码的 JSON bundle
          try {
            final jsonBytes = base64.decode(iTxtContent);
            final jsonData =
                jsonDecode(utf8.decode(jsonBytes)) as Map<String, dynamic>;

            // 从 bundle 中提取第一个 vibe
            final vibes = jsonData['vibes'] as List<dynamic>?;
            if (vibes != null && vibes.isNotEmpty) {
              final firstVibe = vibes.first as Map<String, dynamic>;
              final extractedEncoding = _extractEncodingFromNaiVibe(firstVibe);

              if (extractedEncoding != null && extractedEncoding.isNotEmpty) {
                final name = firstVibe['name'] as String? ?? params.fileName;
                double strength = params.defaultStrength;
                var infoExtracted = 0.7;
                final importInfo =
                    firstVibe['importInfo'] as Map<String, dynamic>?;
                if (importInfo != null && importInfo['strength'] != null) {
                  strength = (importInfo['strength'] as num).toDouble();
                }
                infoExtracted = _extractInformationExtracted(
                  importInfo,
                  infoExtracted,
                );

                return VibeReference(
                  displayName: name,
                  vibeEncoding: extractedEncoding,
                  thumbnail: params.bytes,
                  rawImageData: _extractRawImageFromJson(firstVibe),
                  strength: VibeReference.sanitizeStrength(strength),
                  infoExtracted: infoExtracted,
                  encodingModel: _extractEncodingModelFromJson(firstVibe),
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
            rawImageData: params.bytes,
            strength: params.defaultStrength,
            sourceType: VibeSourceType.png,
          );
        }
      }

      // 没有找到 iTXt 数据，尝试检测 PNG 中是否包含 JSON 文本
      final embeddedJson = _extractEmbeddedJsonFromTextData(textData);
      if (embeddedJson != null) {
        try {
          final jsonData = jsonDecode(embeddedJson) as Map<String, dynamic>;

          // 检查是否为单个 vibe
          final extractedEncoding = _extractEncodingFromJson(jsonData);
          if (extractedEncoding != null) {
            final name = jsonData['name'] as String? ?? params.fileName;
            double strength = params.defaultStrength;
            var infoExtracted = 0.7;
            final importInfo = jsonData['importInfo'] as Map<String, dynamic>?;
            if (importInfo != null && importInfo['strength'] != null) {
              strength = (importInfo['strength'] as num).toDouble();
            }
            infoExtracted = _extractInformationExtracted(
              importInfo,
              infoExtracted,
            );

            return VibeReference(
              displayName: name,
              vibeEncoding: extractedEncoding,
              thumbnail: params.bytes,
              rawImageData: _extractRawImageFromJson(jsonData) ?? params.bytes,
              strength: VibeReference.sanitizeStrength(strength),
              infoExtracted: infoExtracted,
              encodingModel: _extractEncodingModelFromJson(jsonData),
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

  /// 从 textData 中提取嵌入的 JSON 数据
  ///
  /// 检查 textData 中是否包含 JSON 数据
  static String? _extractEmbeddedJsonFromTextData(
    Map<String, String> textData,
  ) {
    for (final entry in textData.entries) {
      final text = entry.value;
      try {
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
        // 不是有效的 JSON，继续检查下一个 entry
        continue;
      }
    }
    return null;
  }

  /// 从 NAI vibe 数据中提取 encoding。
  static String? _extractEncodingFromNaiVibe(Map<String, dynamic> vibe) {
    return _extractEncodingDetails(vibe)?.encoding;
  }

  /// 从导入信息中提取强度值
  static double _extractStrength(
    Map<String, dynamic>? importInfo,
    double defaultValue,
  ) {
    final strengthValue = importInfo?['strength'];
    return switch (strengthValue) {
      final double v => v,
      final int v => v.toDouble(),
      final String v => double.tryParse(v) ?? defaultValue,
      _ => defaultValue,
    };
  }

  /// 从导入信息中提取信息提取值
  static double _extractInformationExtracted(
    Map<String, dynamic>? importInfo,
    double defaultValue,
  ) {
    final infoValue = importInfo?['information_extracted'];
    return switch (infoValue) {
      final double v => VibeReference.sanitizeInfoExtracted(v),
      final int v => VibeReference.sanitizeInfoExtracted(v.toDouble()),
      final String v => VibeReference.sanitizeInfoExtracted(
        double.tryParse(v) ?? defaultValue,
      ),
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
    final infoExtracted = _extractInformationExtracted(
      jsonData['importInfo'] as Map<String, dynamic>?,
      0.7,
    );
    final rawImageData = _extractRawImageFromJson(jsonData);
    final thumbnail = _extractThumbnailFromJson(jsonData);
    final type = jsonData['type'] as String?;
    final encodingDetails = _extractEncodingDetails(jsonData);

    if (type == 'image') {
      if (rawImageData == null || rawImageData.isEmpty) {
        throw ArgumentError(
          '文件缺少可用的原图数据: $fileName '
          '(type=image). 此文件可能已损坏或不完整，建议删除后重新保存。',
        );
      }

      return VibeReference(
        displayName: name,
        vibeEncoding: encodingDetails?.encoding ?? '',
        thumbnail: thumbnail,
        rawImageData: rawImageData,
        strength: VibeReference.sanitizeStrength(strength),
        infoExtracted: infoExtracted,
        encodingModel: encodingDetails?.model,
        sourceType: encodingDetails == null
            ? VibeSourceType.rawImage
            : VibeSourceType.naiv4vibe,
      );
    }

    if (encodingDetails == null) {
      final hasEncodings = jsonData.containsKey('encodings');
      throw ArgumentError(
        '文件缺少有效的 Vibe encoding: $fileName '
        '(type=$type, hasEncodings=$hasEncodings). '
        '此文件可能已损坏或不完整，建议删除后重新保存。',
      );
    }

    return VibeReference(
      displayName: name,
      vibeEncoding: encodingDetails.encoding,
      thumbnail: thumbnail,
      rawImageData: rawImageData,
      strength: VibeReference.sanitizeStrength(strength),
      infoExtracted: infoExtracted,
      encodingModel: encodingDetails.model,
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

  /// 从 JSON 数据中提取原始图片
  static Uint8List? _extractRawImageFromJson(Map<String, dynamic> jsonData) {
    try {
      final imageBase64 = jsonData['image'] as String?;
      if (imageBase64 != null && imageBase64.isNotEmpty) {
        final base64Data = _extractBase64FromDataUri(imageBase64);
        if (base64Data != null) {
          return base64Decode(base64Data);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.d('Error extracting raw image from JSON: $e', 'VibeParser');
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
        final vibeItem = vibesList[i];
        // 验证元素类型，跳过非 Map 类型的元素
        if (vibeItem is! Map<String, dynamic>) {
          if (kDebugMode) {
            AppLogger.d(
              'Skipping invalid vibe entry $i in bundle: expected Map but got ${vibeItem.runtimeType}',
              'VibeParser',
            );
          }
          continue;
        }
        final vibeJson = vibeItem;
        final name = vibeJson['name'] as String? ?? '$fileName#$i';
        final strength = _extractStrength(
          vibeJson['importInfo'] as Map<String, dynamic>?,
          defaultStrength,
        );
        final infoExtracted = _extractInformationExtracted(
          vibeJson['importInfo'] as Map<String, dynamic>?,
          0.7,
        );

        final encodingDetails = _extractEncodingDetails(vibeJson);
        final rawImageData = _extractRawImageFromJson(vibeJson);
        if (encodingDetails != null ||
            (rawImageData != null && rawImageData.isNotEmpty)) {
          final thumbnail = _extractThumbnailFromJson(vibeJson);
          results.add(
            VibeReference(
              displayName: name,
              vibeEncoding: encodingDetails?.encoding ?? '',
              thumbnail: thumbnail,
              rawImageData: rawImageData,
              strength: VibeReference.sanitizeStrength(strength),
              infoExtracted: infoExtracted,
              encodingModel:
                  encodingDetails?.model ??
                  _extractEncodingModelFromJson(vibeJson),
              sourceType: encodingDetails == null
                  ? VibeSourceType.rawImage
                  : VibeSourceType.naiv4vibebundle,
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
    return _extractEncodingDetails(jsonData)?.encoding;
  }

  static String? _extractEncodingModelFromJson(Map<String, dynamic> jsonData) {
    final encodingModel = _extractEncodingDetails(jsonData)?.model;
    if (encodingModel != null) {
      return encodingModel;
    }
    final importInfo = jsonData['importInfo'];
    final model = importInfo is Map ? importInfo['model'] : null;
    return model is String
        ? NovelAiVibeCodec.normalizeModelOrNull(model)
        : null;
  }

  static ({String encoding, String? model})? _extractEncodingDetails(
    Map<String, dynamic> jsonData,
  ) {
    final encodingsValue = jsonData['encodings'];
    if (encodingsValue is! Map) {
      return null;
    }

    final importInfo = jsonData['importInfo'];
    final importedModel = importInfo is Map && importInfo['model'] is String
        ? NovelAiVibeCodec.normalizeModelOrNull(importInfo['model'] as String)
        : null;
    final preferredModelKey = importedModel == null
        ? null
        : NovelAiVibeCodec.encodingKeyForModel(importedModel);
    final informationExtracted = importInfo is Map
        ? switch (importInfo['information_extracted']) {
            final num value => value.toDouble(),
            final String value => double.tryParse(value),
            _ => null,
          }
        : null;

    final modelEntries = encodingsValue.entries.toList(growable: false);
    if (preferredModelKey != null) {
      modelEntries.sort((left, right) {
        if (left.key == preferredModelKey) return -1;
        if (right.key == preferredModelKey) return 1;
        return 0;
      });
    }

    for (final modelEntry in modelEntries) {
      final modelEncodings = modelEntry.value;
      if (modelEncodings is! Map) {
        continue;
      }

      MapEntry<dynamic, dynamic>? fallback;
      MapEntry<dynamic, dynamic>? unknown;
      MapEntry<dynamic, dynamic>? matchingParams;
      for (final variant in modelEncodings.entries) {
        final value = variant.value;
        if (value is! Map) {
          continue;
        }
        final encoding = value['encoding'];
        if (encoding is! String || encoding.isEmpty) {
          continue;
        }
        fallback ??= variant;
        if (variant.key == 'unknown') {
          unknown ??= variant;
        }
        final params = value['params'];
        final parameterValue = params is Map
            ? params['information_extracted']
            : null;
        if (informationExtracted != null &&
            parameterValue is num &&
            parameterValue.toDouble() == informationExtracted) {
          matchingParams ??= variant;
        }
      }

      final selected = matchingParams ?? unknown ?? fallback;
      if (selected == null) {
        continue;
      }
      final selectedValue = selected.value as Map;
      final modelKey = modelEntry.key.toString();
      return (
        encoding: selectedValue['encoding'] as String,
        model: NovelAiVibeCodec.modelForEncodingKey(modelKey) ?? importedModel,
      );
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
