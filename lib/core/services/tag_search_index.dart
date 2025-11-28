import 'dart:async';
import 'dart:isolate';

import '../../data/models/tag/local_tag.dart';
import '../utils/app_logger.dart';

/// Trie 节点
class _TrieNode {
  final Map<String, _TrieNode> children = {};
  final List<int> tagIndices = []; // 存储标签在列表中的索引
}

/// 标签搜索索引
/// 使用 Trie（前缀树）+ 倒排索引实现快速搜索
class TagSearchIndex {
  /// 前缀树根节点
  final _TrieNode _root = _TrieNode();

  /// 所有标签（按 count 降序排序）
  List<LocalTag> _allTags = [];

  /// 中文翻译倒排索引：翻译片段 -> 标签索引列表
  final Map<String, List<int>> _chineseIndex = {};

  /// 别名索引：alias -> 标签索引
  final Map<String, int> _aliasIndex = {};

  /// 索引是否已就绪
  bool _isReady = false;

  /// 索引是否正在构建
  bool _isBuilding = false;

  /// 索引是否已就绪
  bool get isReady => _isReady;

  /// 获取所有标签数量
  int get tagCount => _allTags.length;

  /// 构建索引
  /// [tags] 标签列表
  /// [useIsolate] 是否使用 Isolate 在后台构建（默认 true）
  Future<void> buildIndex(List<LocalTag> tags, {bool useIsolate = true}) async {
    if (_isBuilding) return;
    _isBuilding = true;

    final stopwatch = Stopwatch()..start();

    try {
      if (useIsolate) {
        // 在 Isolate 中构建索引数据
        final indexData = await _buildIndexInIsolate(tags);
        _applyIndexData(indexData, tags);
      } else {
        // 直接在主线程构建
        _buildIndexSync(tags);
      }

      _isReady = true;
      stopwatch.stop();
      AppLogger.i(
        'TagSearchIndex built: ${_allTags.length} tags in ${stopwatch.elapsedMilliseconds}ms',
        'TagSearch',
      );
    } catch (e, stack) {
      AppLogger.e('Failed to build tag search index', e, stack, 'TagSearch');
      // 降级：直接使用标签列表
      _allTags = List.from(tags)..sort((a, b) => b.count.compareTo(a.count));
      _isReady = true;
    } finally {
      _isBuilding = false;
    }
  }

  /// 在 Isolate 中构建索引数据
  Future<_IndexData> _buildIndexInIsolate(List<LocalTag> tags) async {
    final receivePort = ReceivePort();

    // 将标签转换为可序列化的格式
    final tagsData = tags
        .map((t) => {
              'tag': t.tag,
              'category': t.category,
              'count': t.count,
              'alias': t.alias,
              'translation': t.translation,
            })
        .toList();

    await Isolate.spawn(
      _isolateBuildIndex,
      _IsolateMessage(tagsData, receivePort.sendPort),
    );

    final result = await receivePort.first as _IndexData;
    return result;
  }

  /// Isolate 入口点
  static void _isolateBuildIndex(_IsolateMessage message) {
    final tags = message.tagsData
        .map((data) => LocalTag(
              tag: data['tag'] as String,
              category: data['category'] as int,
              count: data['count'] as int,
              alias: data['alias'] as String?,
              translation: data['translation'] as String?,
            ))
        .toList();

    // 按 count 降序排序
    tags.sort((a, b) => b.count.compareTo(a.count));

    // 构建 Trie 数据
    final trieData = <String, List<int>>{};
    final chineseIndex = <String, List<int>>{};
    final aliasIndex = <String, int>{};

    for (var i = 0; i < tags.length; i++) {
      final tag = tags[i];

      // 构建英文标签的前缀索引
      final normalizedTag = tag.tag.toLowerCase();
      for (var j = 1; j <= normalizedTag.length && j <= 10; j++) {
        final prefix = normalizedTag.substring(0, j);
        trieData.putIfAbsent(prefix, () => []).add(i);
      }

      // 构建别名索引
      if (tag.alias != null && tag.alias!.isNotEmpty) {
        final normalizedAlias = tag.alias!.toLowerCase();
        aliasIndex[normalizedAlias] = i;

        // 别名也加入前缀索引
        for (var j = 1; j <= normalizedAlias.length && j <= 10; j++) {
          final prefix = normalizedAlias.substring(0, j);
          trieData.putIfAbsent(prefix, () => []).add(i);
        }
      }

      // 构建中文翻译索引（仅高频标签）
      if (tag.translation != null &&
          tag.translation!.isNotEmpty &&
          tag.count > 100) {
        final translation = tag.translation!;
        // 索引每个字符开始的子串
        for (var j = 0; j < translation.length; j++) {
          for (var k = j + 1; k <= translation.length && k - j <= 6; k++) {
            final substring = translation.substring(j, k);
            chineseIndex.putIfAbsent(substring, () => []).add(i);
          }
        }
      }
    }

    // 转换为可序列化的格式
    final serializedTags = tags
        .map((t) => {
              'tag': t.tag,
              'category': t.category,
              'count': t.count,
              'alias': t.alias,
              'translation': t.translation,
            })
        .toList();

    message.sendPort.send(_IndexData(
      sortedTags: serializedTags,
      trieData: trieData,
      chineseIndex: chineseIndex,
      aliasIndex: aliasIndex,
    ));
  }

  /// 应用索引数据
  void _applyIndexData(_IndexData data, List<LocalTag> originalTags) {
    // 重建标签列表（按排序后的顺序）
    _allTags = data.sortedTags
        .map((d) => LocalTag(
              tag: d['tag'] as String,
              category: d['category'] as int,
              count: d['count'] as int,
              alias: d['alias'] as String?,
              translation: d['translation'] as String?,
            ))
        .toList();

    // 重建 Trie
    _root.children.clear();
    for (final entry in data.trieData.entries) {
      _insertIntoTrie(entry.key, entry.value);
    }

    // 应用其他索引
    _chineseIndex.clear();
    _chineseIndex.addAll(data.chineseIndex);

    _aliasIndex.clear();
    _aliasIndex.addAll(data.aliasIndex);
  }

  /// 将前缀插入 Trie
  void _insertIntoTrie(String prefix, List<int> indices) {
    var node = _root;
    for (final char in prefix.split('')) {
      node = node.children.putIfAbsent(char, () => _TrieNode());
    }
    node.tagIndices.addAll(indices);
  }

  /// 同步构建索引（用于降级或小数据集）
  void _buildIndexSync(List<LocalTag> tags) {
    _allTags = List.from(tags)..sort((a, b) => b.count.compareTo(a.count));

    for (var i = 0; i < _allTags.length; i++) {
      final tag = _allTags[i];

      // 构建英文标签的前缀索引
      _insertTagIntoTrie(tag.tag.toLowerCase(), i);

      // 构建别名索引
      if (tag.alias != null && tag.alias!.isNotEmpty) {
        final normalizedAlias = tag.alias!.toLowerCase();
        _aliasIndex[normalizedAlias] = i;
        _insertTagIntoTrie(normalizedAlias, i);
      }

      // 构建中文翻译索引
      if (tag.translation != null &&
          tag.translation!.isNotEmpty &&
          tag.count > 100) {
        _indexChineseTranslation(tag.translation!, i);
      }
    }
  }

  /// 将标签插入 Trie
  void _insertTagIntoTrie(String text, int index) {
    var node = _root;
    final chars = text.split('');
    for (var i = 0; i < chars.length && i < 10; i++) {
      final char = chars[i];
      node = node.children.putIfAbsent(char, () => _TrieNode());
      node.tagIndices.add(index);
    }
  }

  /// 索引中文翻译
  void _indexChineseTranslation(String translation, int index) {
    for (var j = 0; j < translation.length; j++) {
      for (var k = j + 1; k <= translation.length && k - j <= 6; k++) {
        final substring = translation.substring(j, k);
        _chineseIndex.putIfAbsent(substring, () => []).add(index);
      }
    }
  }

  /// 搜索标签
  /// [query] 搜索词
  /// [limit] 最大返回数量
  List<LocalTag> search(String query, {int limit = 20}) {
    if (query.isEmpty) return [];

    final normalizedQuery = query.trim().toLowerCase();

    // 判断是否包含中文
    final containsChinese = _containsChinese(normalizedQuery);

    if (containsChinese) {
      return _searchChinese(normalizedQuery, limit);
    } else {
      return _searchEnglish(normalizedQuery, limit);
    }
  }

  /// 英文前缀搜索
  List<LocalTag> _searchEnglish(String prefix, int limit) {
    if (!_isReady) {
      // 索引未就绪，使用简单搜索
      return _simpleSearch(prefix, limit);
    }

    final resultIndices = <int>{};

    // 从 Trie 搜索
    var node = _root;
    for (final char in prefix.split('')) {
      if (!node.children.containsKey(char)) {
        break;
      }
      node = node.children[char]!;
    }

    // 收集所有匹配的标签索引
    if (node != _root) {
      _collectFromNode(node, resultIndices, limit * 2);
    }

    // 转换为标签列表并排序
    final results = resultIndices
        .where((i) => i < _allTags.length)
        .map((i) => _allTags[i])
        .toList();

    // 按相关性排序：精确匹配 > 前缀匹配 > count
    results.sort((a, b) {
      final aExact = a.tag.toLowerCase() == prefix ||
          (a.alias?.toLowerCase() == prefix);
      final bExact = b.tag.toLowerCase() == prefix ||
          (b.alias?.toLowerCase() == prefix);

      if (aExact && !bExact) return -1;
      if (!aExact && bExact) return 1;

      final aStartsWith = a.tag.toLowerCase().startsWith(prefix) ||
          (a.alias?.toLowerCase().startsWith(prefix) ?? false);
      final bStartsWith = b.tag.toLowerCase().startsWith(prefix) ||
          (b.alias?.toLowerCase().startsWith(prefix) ?? false);

      if (aStartsWith && !bStartsWith) return -1;
      if (!aStartsWith && bStartsWith) return 1;

      return b.count.compareTo(a.count);
    });

    return results.take(limit).toList();
  }

  /// 从节点收集标签索引
  void _collectFromNode(_TrieNode node, Set<int> results, int limit) {
    results.addAll(node.tagIndices.take(limit - results.length));

    if (results.length >= limit) return;

    for (final child in node.children.values) {
      _collectFromNode(child, results, limit);
      if (results.length >= limit) return;
    }
  }

  /// 中文搜索
  List<LocalTag> _searchChinese(String query, int limit) {
    if (!_isReady) {
      return _simpleChineseSearch(query, limit);
    }

    final resultIndices = <int>{};

    // 从倒排索引搜索
    if (_chineseIndex.containsKey(query)) {
      resultIndices.addAll(_chineseIndex[query]!);
    }

    // 如果没有精确匹配，尝试部分匹配
    if (resultIndices.isEmpty) {
      for (final entry in _chineseIndex.entries) {
        if (entry.key.contains(query) || query.contains(entry.key)) {
          resultIndices.addAll(entry.value);
          if (resultIndices.length >= limit * 2) break;
        }
      }
    }

    // 转换为标签列表
    final results = resultIndices
        .where((i) => i < _allTags.length)
        .map((i) => _allTags[i])
        .toList();

    // 按相关性排序
    results.sort((a, b) {
      final aExact = a.translation == query;
      final bExact = b.translation == query;

      if (aExact && !bExact) return -1;
      if (!aExact && bExact) return 1;

      return b.count.compareTo(a.count);
    });

    return results.take(limit).toList();
  }

  /// 简单搜索（索引未就绪时使用）
  List<LocalTag> _simpleSearch(String query, int limit) {
    final results = _allTags.where((tag) {
      final normalizedTag = tag.tag.toLowerCase();
      final normalizedAlias = tag.alias?.toLowerCase() ?? '';
      return normalizedTag.startsWith(query) ||
          normalizedTag.contains(query) ||
          normalizedAlias.startsWith(query) ||
          normalizedAlias.contains(query);
    }).take(limit * 2).toList();

    results.sort((a, b) {
      final aStartsWith = a.tag.toLowerCase().startsWith(query);
      final bStartsWith = b.tag.toLowerCase().startsWith(query);

      if (aStartsWith && !bStartsWith) return -1;
      if (!aStartsWith && bStartsWith) return 1;

      return b.count.compareTo(a.count);
    });

    return results.take(limit).toList();
  }

  /// 简单中文搜索
  List<LocalTag> _simpleChineseSearch(String query, int limit) {
    final results = _allTags.where((tag) {
      return tag.translation?.contains(query) ?? false;
    }).take(limit * 2).toList();

    results.sort((a, b) => b.count.compareTo(a.count));

    return results.take(limit).toList();
  }

  /// 判断字符串是否包含中文
  bool _containsChinese(String text) {
    return RegExp(r'[\u4e00-\u9fa5]').hasMatch(text);
  }

  /// 清空索引
  void clear() {
    _root.children.clear();
    _allTags.clear();
    _chineseIndex.clear();
    _aliasIndex.clear();
    _isReady = false;
  }
}

/// Isolate 消息
class _IsolateMessage {
  final List<Map<String, dynamic>> tagsData;
  final SendPort sendPort;

  _IsolateMessage(this.tagsData, this.sendPort);
}

/// 索引数据
class _IndexData {
  final List<Map<String, dynamic>> sortedTags;
  final Map<String, List<int>> trieData;
  final Map<String, List<int>> chineseIndex;
  final Map<String, int> aliasIndex;

  _IndexData({
    required this.sortedTags,
    required this.trieData,
    required this.chineseIndex,
    required this.aliasIndex,
  });
}

