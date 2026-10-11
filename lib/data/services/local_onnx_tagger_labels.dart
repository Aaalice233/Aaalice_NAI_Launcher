import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:csv/csv.dart';

enum OnnxTaggerLabelCategory {
  rating,
  general,
  character,
  copyright,
  artist,
  meta,
  other;

  // 与在线画廊的提示词类别一致：可选项、默认勾选与拼进提示词的先后顺序
  static const selectable = [general, character, copyright, artist, meta];
  static const defaultPromptCategories = {general, character, copyright};
  static const promptOrder = [artist, character, copyright, general, meta];

  static OnnxTaggerLabelCategory parse(String? category, {String name = ''}) {
    final normalized = category?.trim().toLowerCase();
    if (normalized == '9' ||
        normalized == 'rating' ||
        name.startsWith('rating:')) {
      return rating;
    }
    return switch (normalized) {
      '0' || 'general' || 'tag' || 'tags' => general,
      '4' || 'character' || 'characters' => character,
      '3' || 'copyright' || 'copyrights' => copyright,
      // PixAI 的 style 分类收录的是画师名
      '1' || 'artist' || 'artists' || 'style' => artist,
      '5' || 'meta' => meta,
      _ => other,
    };
  }
}

class OnnxTaggerLabel {
  const OnnxTaggerLabel({required this.name, this.category});

  final String name;
  final String? category;

  OnnxTaggerLabelCategory get labelCategory =>
      OnnxTaggerLabelCategory.parse(category, name: name);
}

class OnnxTaggerLabelSet {
  const OnnxTaggerLabelSet({
    required this.labels,
    this.recommendedThresholds = const {},
  });

  final List<OnnxTaggerLabel> labels;

  final Map<OnnxTaggerLabelCategory, double> recommendedThresholds;

  Set<OnnxTaggerLabelCategory> get categories => {
    for (final label in labels) label.labelCategory,
  };
}

enum OnnxTaggerLabelFormat {
  // HF 配置：tags 按 tags_split 的分类与数量顺序排列
  splitTagConfig,

  // 分类映射：categories 内每项给出 offset、count 与 tags
  categoryOffsetMap,
  other,
}

abstract final class OnnxTaggerLabelFiles {
  static const int _sniffBytes = 4096;

  static Future<OnnxTaggerLabelSet> load(String labelsPath) async {
    final file = File(labelsPath);
    if (!await file.exists()) {
      return const OnnxTaggerLabelSet(labels: []);
    }
    return parse(
      await file.readAsString(),
      extension: labelsPath.split('.').last.toLowerCase(),
    );
  }

  static OnnxTaggerLabelSet parse(String raw, {required String extension}) {
    return switch (extension) {
      'json' => _parseJson(raw),
      'csv' => OnnxTaggerLabelSet(labels: _parseCsvLabels(raw)),
      _ => OnnxTaggerLabelSet(labels: _parseTextLabels(raw)),
    };
  }

  // 两种格式的标识分别位于 HF 配置末尾（键按字母序）与分类映射开头，只读首尾避免整份解析
  static Future<OnnxTaggerLabelFormat> sniffFormat(String labelsPath) async {
    final file = File(labelsPath);
    if (!labelsPath.toLowerCase().endsWith('.json') || !await file.exists()) {
      return OnnxTaggerLabelFormat.other;
    }
    final handle = await file.open();
    try {
      final length = await handle.length();
      final head = await handle.read(math.min(length, _sniffBytes));
      await handle.setPosition(math.max(0, length - _sniffBytes));
      final tail = await handle.read(_sniffBytes);
      final text =
          '${latin1.decode(head, allowInvalid: true)}'
          '${latin1.decode(tail, allowInvalid: true)}';
      if (text.contains('"tags_split"')) {
        return OnnxTaggerLabelFormat.splitTagConfig;
      }
      if (text.contains('"category_order"') && text.contains('"offset"')) {
        return OnnxTaggerLabelFormat.categoryOffsetMap;
      }
      return OnnxTaggerLabelFormat.other;
    } finally {
      await handle.close();
    }
  }

  static OnnxTaggerLabelSet _parseJson(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return OnnxTaggerLabelSet(labels: _labelsFromJsonList(decoded));
    }
    if (decoded is! Map<String, dynamic>) {
      return const OnnxTaggerLabelSet(labels: []);
    }

    final vocabularyLabels = _parseVocabularyLabels(decoded);
    if (vocabularyLabels.isNotEmpty) {
      return OnnxTaggerLabelSet(labels: vocabularyLabels);
    }
    final splitTagConfig = _parseSplitTagConfig(decoded);
    if (splitTagConfig != null) return splitTagConfig;
    final categoryOffsetMap = _parseCategoryOffsetMap(decoded);
    if (categoryOffsetMap != null) return categoryOffsetMap;
    return OnnxTaggerLabelSet(labels: _parseIndexedOrFlatLabels(decoded));
  }

  static OnnxTaggerLabelSet? _parseSplitTagConfig(
    Map<String, dynamic> decoded,
  ) {
    final tags = decoded['tags'];
    final split = decoded['tags_split'];
    if (tags is! List || split is! List) return null;

    final labels = <OnnxTaggerLabel>[];
    for (final entry in split) {
      if (entry is! List || entry.length < 2 || entry[1] is! int) {
        throw const FormatException('Invalid tags_split entry');
      }
      final category = entry[0].toString();
      final end = labels.length + (entry[1] as int);
      if (end > tags.length) {
        throw const FormatException('tags_split exceeds the tag list');
      }
      for (var index = labels.length; index < end; index++) {
        labels.add(
          OnnxTaggerLabel(
            name: tags[index].toString().trim(),
            category: category,
          ),
        );
      }
    }
    if (labels.length != tags.length) {
      throw const FormatException('tags_split does not cover every tag');
    }
    return OnnxTaggerLabelSet(
      labels: labels,
      recommendedThresholds: _categoryThresholds(
        decoded['category_best_threshold'],
      ),
    );
  }

  static OnnxTaggerLabelSet? _parseCategoryOffsetMap(
    Map<String, dynamic> decoded,
  ) {
    final categories = decoded['categories'];
    if (categories is! List ||
        categories.isEmpty ||
        categories.any(
          (entry) =>
              entry is! Map ||
              entry['offset'] is! int ||
              entry['count'] is! int,
        )) {
      return null;
    }

    final entries = categories.cast<Map>();
    final classCount =
        decoded['num_classes'] as int? ??
        entries.fold<int>(0, (sum, entry) => sum + (entry['count'] as int));
    final labels = List<OnnxTaggerLabel?>.filled(classCount, null);
    for (final entry in entries) {
      final offset = entry['offset'] as int;
      final tags = entry['tags'];
      if (tags is! List ||
          entry['count'] != tags.length ||
          offset < 0 ||
          offset + tags.length > classCount) {
        throw const FormatException('Invalid tag map category');
      }
      final category = entry['name']?.toString();
      for (var index = 0; index < tags.length; index++) {
        labels[offset + index] = OnnxTaggerLabel(
          name: tags[index].toString().trim(),
          category: category,
        );
      }
    }
    if (labels.contains(null)) {
      throw const FormatException('Tag map leaves model outputs unnamed');
    }
    return OnnxTaggerLabelSet(labels: labels.cast<OnnxTaggerLabel>());
  }

  static Map<OnnxTaggerLabelCategory, double> _categoryThresholds(Object? raw) {
    if (raw is! Map) return const {};
    final thresholds = <OnnxTaggerLabelCategory, double>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      final category = OnnxTaggerLabelCategory.parse(entry.key.toString());
      if (value is num && category != OnnxTaggerLabelCategory.other) {
        thresholds[category] = value.toDouble();
      }
    }
    return Map.unmodifiable(thresholds);
  }

  static List<OnnxTaggerLabel> _labelsFromJsonList(List<dynamic> decoded) {
    return decoded
        .map((item) {
          if (item is String) {
            return OnnxTaggerLabel(name: item.trim());
          }
          if (item is Map<String, dynamic>) {
            final name = (item['name'] ?? item['tag'] ?? item['label'])
                ?.toString()
                .trim();
            if (name == null || name.isEmpty) {
              return null;
            }
            return OnnxTaggerLabel(
              name: name,
              category: item['category']?.toString(),
            );
          }
          return null;
        })
        .whereType<OnnxTaggerLabel>()
        .toList();
  }

  static List<OnnxTaggerLabel> _parseIndexedOrFlatLabels(
    Map<String, dynamic> decoded,
  ) {
    final numericKeys = decoded.keys.map(int.tryParse).whereType<int>().toList()
      ..sort();
    if (numericKeys.isNotEmpty) {
      return numericKeys
          .map((index) {
            final item = decoded[index.toString()];
            if (item is String) {
              final name = item.trim();
              return name.isEmpty ? null : OnnxTaggerLabel(name: name);
            }
            if (item is Map<String, dynamic>) {
              final name = (item['tag'] ?? item['name'] ?? item['label'])
                  ?.toString()
                  .trim();
              if (name == null || name.isEmpty) {
                return null;
              }
              return OnnxTaggerLabel(
                name: name,
                category: item['category']?.toString(),
              );
            }
            return null;
          })
          .whereType<OnnxTaggerLabel>()
          .toList();
    }

    final labels = decoded['labels'] ?? decoded['tags'];
    if (labels is List) {
      return labels
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .map((item) => OnnxTaggerLabel(name: item))
          .toList();
    }
    return const [];
  }

  static List<OnnxTaggerLabel> _parseVocabularyLabels(
    Map<String, dynamic> decoded,
  ) {
    final labelsByIndex = <int, String>{};
    final idxToTag = decoded['idx_to_tag'];
    if (idxToTag is Map) {
      for (final entry in idxToTag.entries) {
        final index = int.tryParse(entry.key.toString());
        final tag = entry.value?.toString().trim();
        if (index != null && tag != null && tag.isNotEmpty) {
          labelsByIndex[index] = tag;
        }
      }
    } else if (idxToTag is List) {
      for (var i = 0; i < idxToTag.length; i++) {
        final tag = idxToTag[i]?.toString().trim();
        if (tag != null && tag.isNotEmpty) {
          labelsByIndex[i] = tag;
        }
      }
    }

    if (labelsByIndex.isEmpty) {
      final tagToIdx = decoded['tag_to_idx'];
      if (tagToIdx is Map) {
        for (final entry in tagToIdx.entries) {
          final index = int.tryParse(entry.value.toString());
          final tag = entry.key.toString().trim();
          if (index != null && tag.isNotEmpty) {
            labelsByIndex[index] = tag;
          }
        }
      }
    }

    if (labelsByIndex.isEmpty) {
      return const [];
    }

    final tagToCategory = _scalarStringMap(decoded['tag_to_category']);
    final categories = _scalarStringMap(decoded['categories']);
    final sortedIndexes = labelsByIndex.keys.toList()..sort();
    return sortedIndexes.map((index) {
      final name = labelsByIndex[index]!;
      final rawCategory = tagToCategory[name];
      final category = rawCategory == null
          ? null
          : categories[rawCategory] ?? rawCategory;
      return OnnxTaggerLabel(name: name, category: category);
    }).toList();
  }

  static Map<String, String> _scalarStringMap(Object? raw) {
    if (raw is! Map) {
      return const {};
    }
    final result = <String, String>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is String || value is num || value is bool) {
        final normalized = value.toString().trim();
        if (normalized.isNotEmpty) {
          result[entry.key.toString()] = normalized;
        }
      }
    }
    return result;
  }

  static List<OnnxTaggerLabel> _parseCsvLabels(String raw) {
    final rows = const CsvToListConverter(
      shouldParseNumbers: false,
    ).convert(raw).where((row) => row.isNotEmpty).toList();
    final parsed = _labelsFromCsvRows(rows);
    if (parsed.isNotEmpty) {
      return parsed;
    }

    return _labelsFromCsvRows(
      raw
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .map((line) => line.split(',').map((cell) => cell.trim()).toList())
          .toList(),
    );
  }

  static List<OnnxTaggerLabel> _labelsFromCsvRows(List<List<dynamic>> rows) {
    if (rows.isEmpty) {
      return const [];
    }

    final header = rows.first.map((e) => e.toString().toLowerCase()).toList();
    final hasHeader =
        header.contains('name') ||
        header.contains('tag') ||
        header.contains('category');
    final headerNameIndex = hasHeader
        ? math.max(header.indexOf('name'), header.indexOf('tag'))
        : -1;
    final nameIndex = headerNameIndex >= 0
        ? headerNameIndex
        : rows.first.length > 1
        ? 1
        : 0;
    final categoryIndex = hasHeader ? header.indexOf('category') : 2;
    final dataRows = hasHeader ? rows.skip(1) : rows;

    return dataRows
        .map((row) {
          if (row.length <= nameIndex) {
            return null;
          }
          final name = row[nameIndex].toString().trim();
          if (name.isEmpty) {
            return null;
          }
          final category = categoryIndex >= 0 && row.length > categoryIndex
              ? row[categoryIndex].toString().trim()
              : null;
          return OnnxTaggerLabel(name: name, category: category);
        })
        .whereType<OnnxTaggerLabel>()
        .toList();
  }

  static List<OnnxTaggerLabel> _parseTextLabels(String raw) {
    return raw
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .map((line) {
          final parts = line.split(RegExp(r'[\t,]'));
          return OnnxTaggerLabel(name: parts.first.trim());
        })
        .toList();
  }
}
