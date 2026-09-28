import 'dart:convert';

import '../../../core/utils/portable_logger.dart';
import '../../models/gallery/nai_image_metadata.dart';
import 'metadata_parse_result.dart';

/// Runs format-specific text decoders in stable precedence order.
class MetadataTextDecoder {
  MetadataTextDecoder({List<MetadataParser>? parsers})
    : parsers = parsers ?? _defaultParsers();

  final List<MetadataParser> parsers;

  static List<MetadataParser> _defaultParsers() => [
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

  MetadataParseResult decode(
    Map<String, String> textData, {
    ParseStatistics? statistics,
  }) {
    final stopwatch = Stopwatch()..start();
    final triedParsers = <String>[];
    for (final parser in parsers) {
      triedParsers.add(parser.name);
      try {
        final metadata = parser.parse(textData);
        if (metadata != null) {
          return MetadataParseResult.success(
            metadata,
            parser.name,
            parser.getRawData(textData) ?? '',
            triedParsers,
            parseTime: stopwatch.elapsed,
          );
        }
      } catch (_) {
        statistics?.parserFailureCounts.update(
          parser.name,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
        // Decoder precedence continues after malformed format-specific data.
      }
    }

    final combined = tryCombineParsers(textData);
    if (combined != null) {
      triedParsers.add('CombinedParser');
      return MetadataParseResult.success(
        combined,
        'Combined',
        'Multiple sources',
        triedParsers,
        parseTime: stopwatch.elapsed,
      );
    }
    return MetadataParseResult.failed(
      triedParsers,
      'No parser could extract metadata from ${textData.length} fields',
      parseTime: stopwatch.elapsed,
    );
  }

  /// 检查是否为 PNG 文件
  /// 尝试组合多个解析器的结果
  NaiImageMetadata? tryCombineParsers(Map<String, String> textData) {
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

      // ComfyUI 把完整执行图放在名为 prompt 的 PNG 字段中；该 JSON
      // 不能作为用户提示词展示。
      if (key.contains('prompt') &&
          !key.contains('negative') &&
          !_looksLikeComfyWorkflowJson(value)) {
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

          prompt ??= _extractString(json, [
            'prompt',
            'positive_prompt',
            'text',
          ]);
          negativePrompt ??= _extractString(json, [
            'negative_prompt',
            'uc',
            'negative',
          ]);
          sampler ??= _extractString(json, [
            'sampler',
            'sampler_name',
            'scheduler',
          ]);
          steps ??= _extractInt(json, ['steps', 'num_inference_steps', 'step']);
          cfgScale ??= _extractDouble(json, [
            'cfg_scale',
            'scale',
            'guidance_scale',
            'cfg',
          ]);
          seed ??= _extractInt(json, ['seed', 'noise_seed', 'random_seed']);
          width ??= _extractInt(json, ['width', 'w', 'image_width']);
          height ??= _extractInt(json, ['height', 'h', 'image_height']);
          model ??= _extractString(json, [
            'model',
            'model_name',
            'checkpoint',
            'model_hash',
          ]);
          software ??= _extractString(json, [
            'software',
            'source',
            'generator',
            'app',
          ]);
        } catch (_) {
          // 不是有效的 JSON
        }
      }

      // 解析文本格式的参数
      if (value.contains('Steps:') || value.contains('CFG')) {
        final params = parsePlainTextParams(value);
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

  static bool _looksLikeComfyWorkflowJson(String value) {
    if (!value.trimLeft().startsWith('{')) return false;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic> || decoded.isEmpty) return false;
      return decoded.values.any(
        (node) =>
            node is Map &&
            node['class_type'] is String &&
            node['inputs'] is Map,
      );
    } catch (_) {
      return false;
    }
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
  static Map<String, dynamic> parsePlainTextParams(String text) {
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
        // PortableLogger.d(
        //   'NovelAiParser: Parsed JSON from "$field", keys=${json.keys.toList()}',
        //   'UnifiedMetadataParser',
        // );

        // 直接格式
        if (json.containsKey('prompt')) {
          // PortableLogger.d(
          //   'NovelAiParser: Found prompt field, creating metadata...',
          //   'UnifiedMetadataParser',
          // );
          try {
            final result = NaiImageMetadata.fromNaiComment({
              'Comment': text,
              'Software': textData['Software'],
              'Source': textData['Source'],
            }, rawJson: text);
            // PortableLogger.d('NovelAiParser: Metadata created successfully', 'UnifiedMetadataParser');
            return result;
          } catch (e, stack) {
            PortableLogger.e(
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
          // PortableLogger.d(
          //   'NovelAiParser: Found nested Comment field, type=${comment.runtimeType}',
          //   'UnifiedMetadataParser',
          // );

          if (comment is String) {
            try {
              final commentJson = jsonDecode(comment) as Map<String, dynamic>;
              PortableLogger.d(
                'NovelAiParser: Nested JSON parsed, keys=${commentJson.keys.toList()}',
                'UnifiedMetadataParser',
              );

              final wrappedResult = NaiImageMetadata.fromNaiComment({
                'Comment': jsonEncode(commentJson),
                'Software': textData['Software'],
                'Source': textData['Source'],
              }, rawJson: text);
              // PortableLogger.d('NovelAiParser: Metadata created from nested Comment', 'UnifiedMetadataParser');
              return wrappedResult;
            } catch (e, stack) {
              PortableLogger.e(
                'NovelAiParser: Failed to parse nested Comment',
                e,
                stack,
                'UnifiedMetadataParser',
              );
              continue;
            }
          } else if (comment is Map) {
            try {
              final result = NaiImageMetadata.fromNaiComment({
                'Comment': jsonEncode(comment),
                'Software': textData['Software'],
                'Source': textData['Source'],
              }, rawJson: text);
              PortableLogger.d(
                'NovelAiParser: Metadata created from nested Comment Map',
                'UnifiedMetadataParser',
              );
              return result;
            } catch (e, stack) {
              PortableLogger.e(
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
        PortableLogger.d(
          'NovelAiParser: Failed to parse field "$field": $e',
          'UnifiedMetadataParser',
        );
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
      final remaining = text.substring(
        negPromptIndex + 'Negative prompt:'.length,
      );
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
    final params = MetadataTextDecoder.parsePlainTextParams(text);

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
          final value = entry.value;
          if (value is! Map) continue;
          final node = Map<String, dynamic>.from(value);
          final classType = node['class_type'] as String?;

          if (classType?.contains('KSampler') == true) {
            final inputs = node['inputs'] as Map<String, dynamic>?;
            if (inputs != null) {
              sampler = inputs['sampler_name'] as String?;
              steps = (inputs['steps'] as num?)?.toInt();
              cfg = (inputs['cfg'] as num?)?.toDouble();
              seed =
                  (inputs['seed'] as num?)?.toInt() ??
                  (inputs['noise_seed'] as num?)?.toInt();
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

        if (positivePrompt != null ||
            sampler != null ||
            steps != null ||
            cfg != null ||
            seed != null) {
          return NaiImageMetadata(
            prompt: positivePrompt ?? '',
            negativePrompt: negativePrompt ?? '',
            seed: seed,
            sampler: sampler,
            steps: steps,
            scale: cfg,
            model: 'Unknown',
            software: 'ComfyUI',
            rawJson: prompt,
          );
        }
      }
    } catch (e) {
      PortableLogger.d('ComfyUI parser failed: $e', 'UnifiedMetadataParser');
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
      final positivePrompt =
          prompt?.map((p) => p['prompt'] as String?).join(', ') ?? '';

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
