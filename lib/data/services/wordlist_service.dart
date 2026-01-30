import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/app_logger.dart';
import '../models/prompt/wordlist_entry.dart';

part 'wordlist_service.g.dart';

/// 词库类型
enum WordlistType {
  /// V4 模型词库
  v4('wordlists_v4.csv'),

  /// Legacy 模型词库
  legacy('wordlists_legacy.csv'),

  /// Furry 模型词库
  furry('wordlists_furry.csv');

  const WordlistType(this.fileName);

  /// CSV 文件名
  final String fileName;

  /// 获取资源路径
  String get assetPath => 'assets/data/wordlists/$fileName';
}

/// 词库服务
///
/// 负责加载和管理 CSV 格式的词库数据
/// 支持 V4、Legacy、Furry 三种词库类型
class WordlistService {
  /// 词库缓存（按类型存储）
  final Map<WordlistType, List<WordlistEntry>> _cache = {};

  /// 按变量名索引的缓存（用于快速查找）
  final Map<WordlistType, Map<String, List<WordlistEntry>>> _variableIndex = {};

  /// 按分类索引的缓存
  final Map<WordlistType, Map<String, List<WordlistEntry>>> _categoryIndex = {};

  /// 加载状态
  final Map<WordlistType, bool> _loadingStatus = {};

  /// 是否已初始化
  bool _isInitialized = false;

  /// 是否正在加载
  bool _isLoading = false;

  WordlistService();

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 是否正在加载
  bool get isLoading => _isLoading;

  /// 获取指定类型的词库条目数量
  int getEntryCount(WordlistType type) => _cache[type]?.length ?? 0;

  /// 初始化服务（加载所有词库）
  ///
  /// 默认只加载 V4 词库，其他词库按需加载
  Future<void> initialize({bool loadAll = false}) async {
    if (_isInitialized || _isLoading) return;
    _isLoading = true;

    try {
      AppLogger.i('Initializing WordlistService...', 'Wordlist');

      // 默认加载 V4 词库
      await loadWordlist(WordlistType.v4);

      if (loadAll) {
        // 并行加载其他词库
        await Future.wait([
          loadWordlist(WordlistType.legacy),
          loadWordlist(WordlistType.furry),
        ]);
      }

      _isInitialized = true;
      AppLogger.i(
        'WordlistService initialized: ${getEntryCount(WordlistType.v4)} V4 entries',
        'Wordlist',
      );
    } catch (e, stack) {
      AppLogger.e('Failed to initialize WordlistService', e, stack, 'Wordlist');
      rethrow;
    } finally {
      _isLoading = false;
    }
  }

  /// 加载指定类型的词库
  Future<void> loadWordlist(WordlistType type) async {
    if (_cache.containsKey(type)) return; // 已加载
    if (_loadingStatus[type] == true) return; // 正在加载

    _loadingStatus[type] = true;

    try {
      AppLogger.d('Loading wordlist: ${type.fileName}', 'Wordlist');

      // 从 assets 加载 CSV 文件
      final content = await rootBundle.loadString(type.assetPath);

      // 使用 Isolate 解析，避免阻塞主线程
      final entries = await _parseCsvContentAsync(content);

      // 缓存结果
      _cache[type] = entries;

      // 构建索引
      _buildIndices(type, entries);

      AppLogger.d(
        'Loaded ${entries.length} entries from ${type.fileName}',
        'Wordlist',
      );
    } catch (e, stack) {
      AppLogger.e(
        'Failed to load wordlist: ${type.fileName}',
        e,
        stack,
        'Wordlist',
      );
      rethrow;
    } finally {
      _loadingStatus[type] = false;
    }
  }

  /// 构建索引
  void _buildIndices(WordlistType type, List<WordlistEntry> entries) {
    final variableIndex = <String, List<WordlistEntry>>{};
    final categoryIndex = <String, List<WordlistEntry>>{};

    for (final entry in entries) {
      // 变量名索引
      variableIndex.putIfAbsent(entry.variable, () => []).add(entry);

      // 分类索引
      categoryIndex.putIfAbsent(entry.category, () => []).add(entry);
    }

    _variableIndex[type] = variableIndex;
    _categoryIndex[type] = categoryIndex;
  }

  /// 解析 CSV 内容（在 Isolate 中执行）
  Future<List<WordlistEntry>> _parseCsvContentAsync(String content) async {
    // TODO: Isolate.run 在 Windows 上与 Freezed 对象有兼容性问题，暂时禁用
    // return Isolate.run(() => _parseCsvContentSync(content));
    return _parseCsvContentSync(content);
  }

  /// 同步解析 CSV 内容（供 Isolate 使用）
  static List<WordlistEntry> _parseCsvContentSync(String content) {
    final lines = content.split('\n');
    final entries = <WordlistEntry>[];

    // 跳过标题行
    final startIndex =
        lines.isNotEmpty && lines[0].toLowerCase().contains('variable') ? 1 : 0;

    for (var i = startIndex; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      try {
        final entry = WordlistEntry.fromCsvLine(line);
        entries.add(entry);
      } catch (e) {
        // 忽略解析错误的行
        continue;
      }
    }

    return entries;
  }

  // ========== 查询方法 ==========

  /// 获取所有条目
  List<WordlistEntry> getAllEntries(WordlistType type) {
    return _cache[type] ?? [];
  }

  /// 按变量名获取条目
  List<WordlistEntry> getEntriesByVariable(WordlistType type, String variable) {
    return _variableIndex[type]?[variable] ?? [];
  }

  /// 按分类获取条目
  List<WordlistEntry> getEntriesByCategory(WordlistType type, String category) {
    return _categoryIndex[type]?[category] ?? [];
  }

  /// 获取所有变量名
  List<String> getVariables(WordlistType type) {
    return _variableIndex[type]?.keys.toList() ?? [];
  }

  /// 获取所有分类
  List<String> getCategories(WordlistType type) {
    return _categoryIndex[type]?.keys.toList() ?? [];
  }

  /// 按变量和分类获取条目
  List<WordlistEntry> getEntriesByVariableAndCategory(
    WordlistType type,
    String variable,
    String category,
  ) {
    final entries = getEntriesByVariable(type, variable);
    return entries.where((e) => e.category == category).toList();
  }

  /// 搜索标签
  ///
  /// [query] 搜索词
  /// [type] 词库类型
  /// [limit] 最大返回数量
  List<WordlistEntry> search(
    WordlistType type,
    String query, {
    int limit = 20,
  }) {
    if (query.isEmpty) return [];

    final entries = _cache[type] ?? [];
    final lowerQuery = query.toLowerCase();

    return entries
        .where((e) => e.tag.toLowerCase().contains(lowerQuery))
        .take(limit)
        .toList();
  }

  /// 加权随机选择
  ///
  /// 根据权重随机选择一个条目
  WordlistEntry? weightedRandomSelect(
    List<WordlistEntry> entries,
    int Function() randomInt,
  ) {
    if (entries.isEmpty) return null;

    final totalWeight = entries.fold<int>(0, (sum, e) => sum + e.weight);
    if (totalWeight <= 0) {
      // 无权重，均匀随机
      return entries[randomInt() % entries.length];
    }

    final target = (randomInt() % totalWeight) + 1;
    var cumulative = 0;

    for (final entry in entries) {
      cumulative += entry.weight;
      if (target <= cumulative) {
        return entry;
      }
    }

    return entries.last;
  }

  /// 清除缓存
  void clearCache([WordlistType? type]) {
    if (type != null) {
      _cache.remove(type);
      _variableIndex.remove(type);
      _categoryIndex.remove(type);
    } else {
      _cache.clear();
      _variableIndex.clear();
      _categoryIndex.clear();
      _isInitialized = false;
    }
  }

  /// 强制刷新
  Future<void> refresh([WordlistType? type]) async {
    clearCache(type);
    if (type != null) {
      await loadWordlist(type);
    } else {
      await initialize(loadAll: true);
    }
  }
}

/// WordlistService Provider
@Riverpod(keepAlive: true)
WordlistService wordlistService(Ref ref) {
  return WordlistService();
}
