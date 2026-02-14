import 'package:csv/csv.dart';

import '../../utils/app_logger.dart';

/// CSV 文件格式类型
enum CsvFormatType {
  /// 简单格式: tag,translation (无标题行)
  /// 例如: danbooru.csv, danbooru_zh.csv
  simple,

  /// 角色格式: 中文名,英文名 (无标题行)
  /// 例如: wai_characters.csv
  character,

  /// GitHub Chening233 格式: danbooru_text,danbooru_url,tag,danbooru_translation
  /// 第4列包含多语言翻译(逗号分隔)
  githubChening233,

  /// HuggingFace 格式: tag,category,count,alias
  /// 第4列包含多语言别名(逗号分隔)
  huggingFaceTags,

  /// GitHub Sanlvzhetang 格式: tag,category,count,aliases
  /// 第4列是英文别名，不是中文翻译
  /// 此格式不提供中文翻译，应跳过
  githubSanlvzhetang,
}

/// CSV 格式处理器
class CsvFormatHandler {
  /// 从多语言字符串中提取中文翻译
  ///
  /// 输入: "女の子,女性,少女,girl,おんなのこ,女子,소녀,女孩,姑娘,女"
  /// 输出: "女の子,女性,少女,女孩,姑娘,女" (只保留中文/日文/韩文)
  static String? extractChineseTranslation(String aliases) {
    if (aliases.isEmpty || aliases.toLowerCase() == 'none') {
      return null;
    }

    final parts = aliases.split(',');
    final chineseParts = <String>[];

    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;

      // 检测是否包含中文字符
      final hasChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(trimmed);
      // 检测是否包含日文假名
      final hasJapanese = RegExp(r'[\u3040-\u309f\u30a0-\u30ff]').hasMatch(trimmed);
      // 检测是否包含韩文
      final hasKorean = RegExp(r'[\uac00-\ud7af]').hasMatch(trimmed);

      // 排除纯英文和数字
      final isOnlyEnglish = RegExp(r'^[a-zA-Z0-9_\s\-/]+$').hasMatch(trimmed);

      if ((hasChinese || hasJapanese || hasKorean) && !isOnlyEnglish) {
        chineseParts.add(trimmed);
      }
    }

    return chineseParts.isEmpty ? null : chineseParts.join(', ');
  }

  /// 解析简单格式 CSV (tag,translation)
  static Map<String, String> parseSimpleFormat(String csvContent) {
    final result = <String, String>{};

    // 统一换行符
    final content = csvContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    const converter = CsvToListConverter(
      fieldDelimiter: ',',
      textDelimiter: '"',
      textEndDelimiter: '"',
      eol: '\n',
      shouldParseNumbers: false,
    );

    final rows = converter.convert(content);
    for (final row in rows) {
      if (row.length >= 2) {
        final tag = row[0].toString().trim().toLowerCase();
        final translation = row[1].toString().trim();

        if (tag.isNotEmpty && translation.isNotEmpty) {
          // 去除引号
          final cleanTag = _removeQuotes(tag);
          final cleanTranslation = _removeQuotes(translation);

          if (cleanTag.isNotEmpty && cleanTranslation.isNotEmpty) {
            result[cleanTag] = cleanTranslation;
          }
        }
      }
    }

    AppLogger.d('Parsed simple format: ${result.length} entries', 'CsvFormatHandler');
    return result;
  }

  /// 解析角色格式 CSV (中文名,英文名)
  static Map<String, String> parseCharacterFormat(String csvContent) {
    final result = <String, String>{};

    // 统一换行符并去除 BOM
    var content = csvContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (content.startsWith('\uFEFF')) {
      content = content.substring(1);
    }

    const converter = CsvToListConverter(
      fieldDelimiter: ',',
      textDelimiter: '"',
      textEndDelimiter: '"',
      eol: '\n',
      shouldParseNumbers: false,
    );

    final rows = converter.convert(content);
    for (final row in rows) {
      if (row.length >= 2) {
        final chineseName = row[0].toString().trim();
        final englishTag = row[1].toString().trim().toLowerCase();

        if (chineseName.isNotEmpty && englishTag.isNotEmpty) {
          final cleanChinese = _removeQuotes(chineseName);
          final cleanEnglish = _removeQuotes(englishTag);

          if (cleanChinese.isNotEmpty && cleanEnglish.isNotEmpty) {
            result[cleanEnglish] = cleanChinese;
          }
        }
      }
    }

    AppLogger.d('Parsed character format: ${result.length} entries', 'CsvFormatHandler');
    return result;
  }

  /// 解析 GitHub Chening233 格式
  /// 格式: danbooru_text,danbooru_url,tag,danbooru_translation
  static Map<String, String> parseGithubChening233Format(String csvContent) {
    final result = <String, String>{};

    final content = csvContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    const converter = CsvToListConverter(
      fieldDelimiter: ',',
      textDelimiter: '"',
      textEndDelimiter: '"',
      eol: '\n',
      shouldParseNumbers: false,
    );

    final rows = converter.convert(content);
    var isFirstRow = true;

    for (final row in rows) {
      // 跳过标题行
      if (isFirstRow) {
        isFirstRow = false;
        continue;
      }

      if (row.length >= 4) {
        final tag = row[2].toString().trim().toLowerCase();
        final rawTranslation = row[3].toString().trim();

        if (tag.isNotEmpty && rawTranslation.isNotEmpty) {
          final cleanTag = _removeQuotes(tag);
          final chineseTranslation = extractChineseTranslation(rawTranslation);

          if (cleanTag.isNotEmpty && chineseTranslation != null) {
            result[cleanTag] = chineseTranslation;
          }
        }
      }
    }

    AppLogger.d('Parsed GitHub Chening233 format: ${result.length} entries', 'CsvFormatHandler');
    return result;
  }

  /// 解析 HuggingFace Tags 格式
  /// 格式: tag,category,count,alias
  static Map<String, String> parseHuggingFaceTagsFormat(String csvContent) {
    final result = <String, String>{};

    final content = csvContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    const converter = CsvToListConverter(
      fieldDelimiter: ',',
      textDelimiter: '"',
      textEndDelimiter: '"',
      eol: '\n',
      shouldParseNumbers: false,
    );

    final rows = converter.convert(content);
    var isFirstRow = true;

    for (final row in rows) {
      // 跳过标题行
      if (isFirstRow) {
        isFirstRow = false;
        continue;
      }

      if (row.length >= 4) {
        final tag = row[0].toString().trim().toLowerCase();
        final rawAliases = row[3].toString().trim();

        if (tag.isNotEmpty && rawAliases.isNotEmpty) {
          final cleanTag = _removeQuotes(tag);
          final chineseTranslation = extractChineseTranslation(rawAliases);

          if (cleanTag.isNotEmpty && chineseTranslation != null) {
            result[cleanTag] = chineseTranslation;
          }
        }
      }
    }

    AppLogger.d('Parsed HuggingFace tags format: ${result.length} entries', 'CsvFormatHandler');
    return result;
  }

  /// 辅助方法：去除引号
  static String _removeQuotes(String value) {
    if (value.startsWith('"') && value.endsWith('"')) {
      return value.substring(1, value.length - 1).trim();
    }
    return value.trim();
  }

  /// 合并多个翻译数据源，后加载的覆盖先加载的
  static Map<String, String> mergeTranslations(
    List<Map<String, String>> sources, {
    List<String>? sourceNames,
  }) {
    final merged = <String, String>{};
    final duplicateCounts = <String, int>{};

    for (var i = 0; i < sources.length; i++) {
      final source = sources[i];
      final sourceName = sourceNames != null && i < sourceNames.length
          ? sourceNames[i]
          : 'source_$i';

      for (final entry in source.entries) {
        if (merged.containsKey(entry.key)) {
          duplicateCounts[entry.key] = (duplicateCounts[entry.key] ?? 1) + 1;
          // 不打印逐条日志，避免日志狂刷
        }
        merged[entry.key] = entry.value;
      }
    }

    if (duplicateCounts.isNotEmpty) {
      AppLogger.i(
        'Merged ${sources.length} sources: ${merged.length} unique tags, '
        '${duplicateCounts.length} duplicates resolved',
        'CsvFormatHandler',
      );
    }

    return merged;
  }
}
