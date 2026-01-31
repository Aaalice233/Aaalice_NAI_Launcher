import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/alias_parser.dart';
import '../../presentation/providers/tag_library_page_provider.dart';
import '../models/tag_library/tag_library_entry.dart';

part 'alias_resolver_service.g.dart';

/// 别名解析服务
///
/// 负责将别名引用解析为实际的提示词内容
/// 依赖 TagLibraryPageNotifier 获取词库数据
@Riverpod(keepAlive: true)
class AliasResolverService extends _$AliasResolverService {
  @override
  void build() {
    // 初始化时不需要特殊操作
  }

  /// 获取所有词库条目
  List<TagLibraryEntry> get _entries {
    return ref.read(tagLibraryPageNotifierProvider).entries;
  }

  /// 解析文本中的所有别名引用
  ///
  /// [text] 包含别名的原始文本
  /// 返回解析后的文本（别名被替换为实际内容）
  String resolveAliases(String text) {
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
      }
    }

    return result;
  }

  /// 获取别名的详细信息（用于悬停浮窗）
  ///
  /// 返回词库条目，若别名无效则返回 null
  TagLibraryEntry? getAliasEntry(AliasReference reference) {
    if (reference.type != AliasReferenceType.simple) {
      return null;
    }

    final entryName = reference.primaryName;
    return findEntryByName(entryName);
  }

  /// 根据名称查找词库条目（不区分大小写）
  TagLibraryEntry? findEntryByName(String name) {
    if (name.isEmpty) return null;

    final lowerName = name.toLowerCase();
    for (final entry in _entries) {
      if (entry.name.toLowerCase() == lowerName) {
        return entry;
      }
    }
    return null;
  }

  /// 检查别名是否有效（对应的词库条目存在）
  bool isAliasValid(AliasReference reference) {
    return getAliasEntry(reference) != null;
  }

  /// 检查名称对应的词库条目是否存在
  bool isEntryNameValid(String name) {
    return findEntryByName(name) != null;
  }

  /// 搜索词库条目（用于智能补全）
  ///
  /// [query] 搜索关键词
  /// [limit] 最大返回数量
  List<TagLibraryEntry> searchEntries(String query, {int limit = 15}) {
    final entries = _entries;

    if (query.isEmpty) {
      // 返回最近使用的条目
      final sorted = entries.toList()
        ..sort((a, b) {
          // 先按收藏排序
          if (a.isFavorite != b.isFavorite) {
            return a.isFavorite ? -1 : 1;
          }
          // 再按使用次数排序
          return b.useCount.compareTo(a.useCount);
        });
      return sorted.take(limit).toList();
    }

    final lowerQuery = query.toLowerCase();

    // 搜索名称匹配的条目
    final matches = <(TagLibraryEntry, int)>[];
    for (final entry in entries) {
      final lowerName = entry.name.toLowerCase();

      // 计算匹配分数
      int score = 0;

      // 完全匹配
      if (lowerName == lowerQuery) {
        score = 100;
      }
      // 前缀匹配
      else if (lowerName.startsWith(lowerQuery)) {
        score = 80;
      }
      // 包含匹配
      else if (lowerName.contains(lowerQuery)) {
        score = 60;
      }
      // 内容匹配
      else if (entry.content.toLowerCase().contains(lowerQuery)) {
        score = 40;
      }
      // 标签匹配
      else {
        for (final tag in entry.tags) {
          if (tag.toLowerCase().contains(lowerQuery)) {
            score = 30;
            break;
          }
        }
      }

      if (score > 0) {
        // 收藏条目加分
        if (entry.isFavorite) score += 10;
        matches.add((entry, score));
      }
    }

    // 按分数排序
    matches.sort((a, b) => b.$2.compareTo(a.$2));

    return matches.take(limit).map((m) => m.$1).toList();
  }

  /// 记录词库条目使用（当别名被解析时调用）
  Future<void> recordEntryUsage(String entryName) async {
    final entry = findEntryByName(entryName);
    if (entry != null) {
      final notifier = ref.read(tagLibraryPageNotifierProvider.notifier);
      await notifier.recordUsage(entry.id);
    }
  }

  /// 解析单个引用
  String? _resolveReference(AliasReference ref) {
    switch (ref.type) {
      case AliasReferenceType.simple:
        return _resolveSimpleReference(ref.primaryName);
      case AliasReferenceType.random:
        // 预留：随机选择一个词库
        return _resolveRandomReference(ref.entryNames);
      case AliasReferenceType.weighted:
        // 预留：按权重随机选择
        return _resolveWeightedReference(ref.entryNames, ref.weights);
    }
  }

  /// 解析简单引用
  String? _resolveSimpleReference(String entryName) {
    final entry = findEntryByName(entryName);
    return entry?.content;
  }

  /// 解析随机引用（预留）
  String? _resolveRandomReference(List<String> entryNames) {
    // 随机选择一个有效的词库
    final validEntries = <TagLibraryEntry>[];
    for (final name in entryNames) {
      final entry = findEntryByName(name);
      if (entry != null) {
        validEntries.add(entry);
      }
    }

    if (validEntries.isEmpty) return null;

    // 随机选择
    final random = DateTime.now().microsecondsSinceEpoch % validEntries.length;
    return validEntries[random].content;
  }

  /// 解析带权重的随机引用（预留）
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
      final entry = findEntryByName(name);
      if (entry != null) {
        final weight = weights[name] ?? 1.0;
        validEntries.add((entry, weight));
        totalWeight += weight;
      }
    }

    if (validEntries.isEmpty || totalWeight <= 0) return null;

    // 按权重随机选择
    final randomValue =
        (DateTime.now().microsecondsSinceEpoch % 10000) / 10000 * totalWeight;
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
}
