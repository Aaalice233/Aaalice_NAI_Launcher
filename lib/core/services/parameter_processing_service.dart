import 'dart:math';

import '../utils/alias_parser.dart';
import '../utils/app_logger.dart';
import '../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../data/models/tag_library/tag_library_entry.dart';

/// 参数处理结果
///
/// 包含处理后的提示词和负向提示词
class ParameterProcessingResult {
  /// 处理后的正向提示词
  final String prompt;

  /// 处理后的负向提示词
  final String negativePrompt;

  /// 是否应用了别名解析
  final bool aliasesResolved;

  /// 是否应用了固定词
  final bool fixedTagsApplied;

  /// 应用的固定词数量
  final int fixedTagsCount;

  const ParameterProcessingResult({
    required this.prompt,
    required this.negativePrompt,
    this.aliasesResolved = false,
    this.fixedTagsApplied = false,
    this.fixedTagsCount = 0,
  });

  /// 创建未处理的结果
  factory ParameterProcessingResult.unprocessed(String prompt, String negativePrompt) {
    return ParameterProcessingResult(
      prompt: prompt,
      negativePrompt: negativePrompt,
    );
  }
}

/// 参数处理服务
///
/// 负责处理图像生成参数的纯业务逻辑，包括：
/// - 别名解析（将 <词库名> 展开为实际内容）
/// - 固定词应用（将固定词添加到提示词前后）
///
/// 这是一个纯服务类，不依赖 Riverpod，便于单元测试和复用
class ParameterProcessingService {
  /// 词库条目列表（用于别名解析）
  final List<TagLibraryEntry> _tagLibraryEntries;

  /// 固定词条目列表
  final List<FixedTagEntry> _fixedTags;

  /// 随机数生成器（复用实例，避免每次创建）
  static final Random _random = Random();

  /// 创建参数处理服务
  ///
  /// [tagLibraryEntries] 词库条目列表，用于别名解析
  /// [fixedTags] 固定词条目列表
  ParameterProcessingService({
    List<TagLibraryEntry> tagLibraryEntries = const [],
    List<FixedTagEntry> fixedTags = const [],
  })  : _tagLibraryEntries = tagLibraryEntries,
        _fixedTags = fixedTags;

  /// 获取词库条目
  List<TagLibraryEntry> get tagLibraryEntries => List.unmodifiable(_tagLibraryEntries);

  /// 获取固定词条目
  List<FixedTagEntry> get fixedTags => List.unmodifiable(_fixedTags);

  /// 处理生成参数
  ///
  /// 依次执行：
  /// 1. 别名解析（将 <词库名> 展开为实际内容，包括正向和负向提示词）
  /// 2. 固定词应用（将启用的固定词添加到正向提示词前后，负向提示词不应用固定词）
  ///
  /// [prompt] 正向提示词
  /// [negativePrompt] 负向提示词
  /// [resolveAliases] 是否解析别名（默认 true）
  /// [applyFixedTags] 是否应用固定词（默认 true，仅作用于正向提示词）
  ParameterProcessingResult process({
    required String prompt,
    required String negativePrompt,
    bool resolveAliases = true,
    bool applyFixedTags = true,
  }) {
    String processedPrompt = prompt;
    String processedNegativePrompt = negativePrompt;
    bool aliasesWereResolved = false;
    bool fixedTagsWereApplied = false;
    int appliedFixedTagsCount = 0;

    // 1. 解析别名
    if (resolveAliases) {
      final promptResult = _resolveAliases(prompt);
      final negativeResult = _resolveAliases(negativePrompt);

      if (promptResult != prompt || negativeResult != negativePrompt) {
        processedPrompt = promptResult;
        processedNegativePrompt = negativeResult;
        aliasesWereResolved = true;
        AppLogger.d(
          'Resolved aliases in prompts',
          'ParameterProcessingService',
        );
      }
    }

    // 2. 应用固定词
    if (applyFixedTags) {
      final fixedPrompt = _applyFixedTags(processedPrompt);
      if (fixedPrompt != processedPrompt) {
        processedPrompt = fixedPrompt;
        fixedTagsWereApplied = true;
        appliedFixedTagsCount = _enabledFixedTags.length;
        AppLogger.d(
          'Applied $appliedFixedTagsCount fixed tags',
          'ParameterProcessingService',
        );
      }
    }

    return ParameterProcessingResult(
      prompt: processedPrompt,
      negativePrompt: processedNegativePrompt,
      aliasesResolved: aliasesWereResolved,
      fixedTagsApplied: fixedTagsWereApplied,
      fixedTagsCount: appliedFixedTagsCount,
    );
  }

  /// 仅解析别名
  ///
  /// [text] 包含别名的原始文本
  /// 返回解析后的文本
  String resolveAliases(String text) {
    return _resolveAliases(text);
  }

  /// 仅应用固定词
  ///
  /// [prompt] 用户提示词
  /// 返回应用固定词后的提示词
  String applyFixedTags(String prompt) {
    return _applyFixedTags(prompt);
  }

  /// 获取启用的固定词列表
  List<FixedTagEntry> get _enabledFixedTags =>
      _fixedTags.where((e) => e.enabled).toList();

  /// 获取启用的前缀固定词（已排序）
  List<FixedTagEntry> get _enabledPrefixes => _enabledFixedTags
      .where((e) => e.position == FixedTagPosition.prefix)
      .toList()
      .sortedByOrder();

  /// 获取启用的后缀固定词（已排序）
  List<FixedTagEntry> get _enabledSuffixes => _enabledFixedTags
      .where((e) => e.position == FixedTagPosition.suffix)
      .toList()
      .sortedByOrder();

  /// 应用固定词到提示词
  String _applyFixedTags(String userPrompt) {
    final enabledPrefixContents = _enabledPrefixes
        .map((e) => e.weightedContent)
        .where((c) => c.isNotEmpty)
        .toList();

    final enabledSuffixContents = _enabledSuffixes
        .map((e) => e.weightedContent)
        .where((c) => c.isNotEmpty)
        .toList();

    final parts = <String>[
      ...enabledPrefixContents,
      userPrompt,
      ...enabledSuffixContents,
    ].where((s) => s.isNotEmpty).toList();

    return parts.join(', ');
  }

  /// 解析文本中的所有别名引用
  String _resolveAliases(String text) {
    if (text.isEmpty) return text;

    final references = AliasParser.parse(text);
    if (references.isEmpty) return text;

    // 按位置倒序处理（从后往前替换，避免位置偏移）
    final sortedRefs = references.toList()
      ..sort((a, b) => b.start.compareTo(a.start));

    String result = text;
    for (final ref in sortedRefs) {
      final resolvedContent = _resolveReference(ref);
      if (resolvedContent != null) {
        result = result.replaceRange(ref.start, ref.end, resolvedContent);
      } else {
        // 别名未找到，记录警告
        AppLogger.w(
          '别名未找到: ${ref.rawText}，请检查词库中是否存在该条目',
          'ParameterProcessingService',
        );
      }
    }

    return result;
  }

  /// 解析单个引用
  String? _resolveReference(AliasReference ref) {
    switch (ref.type) {
      case AliasReferenceType.simple:
        return _resolveSimpleReference(ref.primaryName);
      case AliasReferenceType.random:
        return _resolveRandomReference(ref.entryNames);
      case AliasReferenceType.weighted:
        return _resolveWeightedReference(ref.entryNames, ref.weights);
    }
  }

  /// 解析简单引用
  String? _resolveSimpleReference(String entryName) {
    final entry = _findEntryByName(entryName);
    return entry?.content;
  }

  /// 解析随机引用
  String? _resolveRandomReference(List<String> entryNames) {
    final validEntries = <TagLibraryEntry>[];
    for (final name in entryNames) {
      final entry = _findEntryByName(name);
      if (entry != null) {
        validEntries.add(entry);
      }
    }

    if (validEntries.isEmpty) return null;

    // 随机选择（使用复用的 Random 实例）
    final randomIndex = _random.nextInt(validEntries.length);
    return validEntries[randomIndex].content;
  }

  /// 解析带权重的随机引用
  String? _resolveWeightedReference(
    List<String> entryNames,
    Map<String, double>? weights,
  ) {
    if (weights == null || weights.isEmpty) {
      return _resolveRandomReference(entryNames);
    }

    // 收集有效条目和权重
    final validEntries = <(TagLibraryEntry, double)>[];
    double totalWeight = 0;

    for (final name in entryNames) {
      final entry = _findEntryByName(name);
      if (entry != null) {
        final weight = weights[name] ?? 1.0;
        validEntries.add((entry, weight));
        totalWeight += weight;
      }
    }

    if (validEntries.isEmpty || totalWeight <= 0) return null;

    // 按权重随机选择（使用复用的 Random 实例）
    final randomValue = _random.nextDouble() * totalWeight;
    double cumulative = 0;

    for (final (entry, weight) in validEntries) {
      cumulative += weight;
      if (randomValue < cumulative) {
        return entry.content;
      }
    }

    // 兜底返回最后一个
    return validEntries.last.$1.content;
  }

  /// 根据名称查找词库条目（不区分大小写）
  TagLibraryEntry? _findEntryByName(String name) {
    if (name.isEmpty) return null;

    final lowerName = name.toLowerCase();
    for (final entry in _tagLibraryEntries) {
      if (entry.name.toLowerCase() == lowerName) {
        return entry;
      }
    }
    return null;
  }

  /// 检查别名是否有效（对应的词库条目存在）
  bool isAliasValid(AliasReference reference) {
    return _findEntryByName(reference.primaryName) != null;
  }

  /// 检查名称对应的词库条目是否存在
  bool isEntryNameValid(String name) {
    return _findEntryByName(name) != null;
  }

  /// 获取固定词统计信息
  FixedTagsStatistics getStatistics() {
    return FixedTagsStatistics(
      totalCount: _fixedTags.length,
      enabledCount: _enabledFixedTags.length,
      prefixCount: _enabledPrefixes.length,
      suffixCount: _enabledSuffixes.length,
    );
  }
}

/// 固定词统计信息
class FixedTagsStatistics {
  /// 总数量
  final int totalCount;

  /// 启用的数量
  final int enabledCount;

  /// 启用的前缀数量
  final int prefixCount;

  /// 启用的后缀数量
  final int suffixCount;

  const FixedTagsStatistics({
    required this.totalCount,
    required this.enabledCount,
    required this.prefixCount,
    required this.suffixCount,
  });

  /// 禁用的数量
  int get disabledCount => totalCount - enabledCount;

  @override
  String toString() {
    return 'FixedTagsStatistics(total: $totalCount, enabled: $enabledCount, '
        'prefix: $prefixCount, suffix: $suffixCount)';
  }
}

