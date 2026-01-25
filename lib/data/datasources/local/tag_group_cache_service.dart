import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/app_logger.dart';
import '../../models/prompt/tag_group.dart';

part 'tag_group_cache_service.g.dart';

/// Tag Group 持久化缓存服务
///
/// 使用 Hive 存储完整的 TagGroup 数据（包含所有标签，不进行热度过滤）
/// 用于支持热度滑块的实时过滤功能
class TagGroupCacheService {
  static const String _boxName = 'tag_group_full_cache';

  /// 最大递归深度，防止循环引用导致无限递归
  static const int _maxRecursionDepth = 10;

  Box? _box;
  Future<void>? _initFuture;
  bool _isInitialized = false;

  /// 内存缓存（避免频繁反序列化）
  final Map<String, TagGroup> _memoryCache = {};

  /// 初始化服务
  Future<void> init() async {
    if (_isInitialized) return;
    _box = await Hive.openBox(_boxName);
    _isInitialized = true;
    AppLogger.d('TagGroupCacheService initialized', 'TagGroupCache');
  }

  /// 确保已初始化（线程安全）
  Future<void> _ensureInit() async {
    if (_isInitialized && _box != null && _box!.isOpen) return;

    _initFuture ??= init();
    await _initFuture;
  }

  /// 检查服务是否已初始化
  bool get isInitialized => _isInitialized;

  /// 生成缓存 key
  String _cacheKey(String groupTitle) {
    // 使用 base64 编码避免特殊字符问题
    return 'group_${base64Url.encode(utf8.encode(groupTitle))}';
  }

  /// 保存 TagGroup 到持久化缓存
  ///
  /// 如果保存失败会抛出异常。调用方可捕获异常进行处理。
  Future<void> saveTagGroup(String groupTitle, TagGroup group) async {
    await _ensureInit();
    try {
      final key = _cacheKey(groupTitle);
      final json = jsonEncode(group.toJson());
      await _box?.put(key, json);

      // 同时更新内存缓存
      _memoryCache[groupTitle] = group;

      AppLogger.d(
        'Saved TagGroup to cache: $groupTitle (${group.tagCount} tags)',
        'TagGroupCache',
      );
    } catch (e, stack) {
      AppLogger.e(
          'Failed to save TagGroup: $groupTitle', e, stack, 'TagGroupCache',);
      rethrow; // 重新抛出异常让调用方处理
    }
  }

  /// 批量保存 TagGroup
  ///
  /// 如果保存失败会抛出异常。调用方可捕获异常进行处理。
  Future<void> saveTagGroups(Map<String, TagGroup> groups) async {
    await _ensureInit();
    try {
      for (final entry in groups.entries) {
        final key = _cacheKey(entry.key);
        final json = jsonEncode(entry.value.toJson());
        await _box?.put(key, json);
        _memoryCache[entry.key] = entry.value;
      }

      AppLogger.d(
        'Saved ${groups.length} TagGroups to cache',
        'TagGroupCache',
      );
    } catch (e, stack) {
      AppLogger.e('Failed to batch save TagGroups', e, stack, 'TagGroupCache');
      rethrow;
    }
  }

  /// 从持久化缓存读取 TagGroup
  Future<TagGroup?> getTagGroup(String groupTitle) async {
    // 优先检查内存缓存
    if (_memoryCache.containsKey(groupTitle)) {
      return _memoryCache[groupTitle];
    }

    await _ensureInit();
    try {
      final key = _cacheKey(groupTitle);
      final json = _box?.get(key) as String?;
      if (json != null) {
        final data = jsonDecode(json) as Map<String, dynamic>;
        final group = TagGroup.fromJson(data);
        // 加载到内存缓存
        _memoryCache[groupTitle] = group;
        return group;
      }
    } catch (e) {
      AppLogger.e(
          'Failed to load TagGroup: $groupTitle', e, null, 'TagGroupCache',);
    }
    return null;
  }

  /// 批量读取 TagGroup
  Future<Map<String, TagGroup>> getTagGroups(List<String> groupTitles) async {
    final result = <String, TagGroup>{};
    for (final title in groupTitles) {
      final group = await getTagGroup(title);
      if (group != null) {
        result[title] = group;
      }
    }
    return result;
  }

  /// 获取所有已缓存的 TagGroup
  Future<Map<String, TagGroup>> getAllCachedGroups() async {
    await _ensureInit();
    final result = <String, TagGroup>{};

    try {
      final keys =
          _box?.keys.where((k) => k.toString().startsWith('group_')) ?? [];
      for (final key in keys) {
        final json = _box?.get(key) as String?;
        if (json != null) {
          final data = jsonDecode(json) as Map<String, dynamic>;
          final group = TagGroup.fromJson(data);
          result[group.title] = group;
          _memoryCache[group.title] = group;
        }
      }
    } catch (e) {
      AppLogger.e('Failed to load all cached groups', e, null, 'TagGroupCache');
    }

    return result;
  }

  /// 检查缓存是否存在（同步方法）
  ///
  /// 注意：此方法仅检查内存缓存和已初始化的 Hive Box。
  /// 如果服务尚未初始化，将返回 false（即使磁盘上存在缓存）。
  /// 对于需要确保检查磁盘缓存的场景，请使用 [hasCachedAsync]。
  bool hasCached(String groupTitle) {
    if (_memoryCache.containsKey(groupTitle)) {
      return true;
    }
    if (!_isInitialized || _box == null || !_box!.isOpen) {
      return false;
    }
    final key = _cacheKey(groupTitle);
    return _box!.containsKey(key);
  }

  /// 检查缓存是否存在（异步方法，确保已初始化）
  ///
  /// 此方法会先确保服务已初始化，然后再检查缓存。
  /// 在需要可靠检查磁盘缓存的场景下使用此方法。
  Future<bool> hasCachedAsync(String groupTitle) async {
    if (_memoryCache.containsKey(groupTitle)) {
      return true;
    }
    await _ensureInit();
    final key = _cacheKey(groupTitle);
    return _box?.containsKey(key) ?? false;
  }

  /// 获取符合热度阈值的标签数量（从缓存实时计算）
  ///
  /// 返回 null 表示缓存中没有该组的数据
  int? getFilteredTagCount(String groupTitle, int minPostCount) {
    final group = _memoryCache[groupTitle];
    if (group == null) {
      return null;
    }
    return group.getTagCountAboveThreshold(minPostCount);
  }

  /// 批量获取过滤后的标签数量（同步方法，仅从内存缓存计算）
  ///
  /// 返回已缓存组的过滤后数量，未缓存的组不包含在结果中
  Map<String, int> getFilteredTagCounts(
    List<String> groupTitles,
    int minPostCount,
  ) {
    final result = <String, int>{};
    for (final title in groupTitles) {
      final count = getFilteredTagCount(title, minPostCount);
      if (count != null) {
        result[title] = count;
      }
    }
    return result;
  }

  /// 异步批量获取过滤后的标签数量（包含子组）
  ///
  /// [includeChildren] 是否包含子组的标签
  Future<Map<String, int>> getFilteredTagCountsAsync(
    List<String> groupTitles,
    int minPostCount, {
    bool includeChildren = true,
  }) async {
    final result = <String, int>{};
    final processedGroups = <String>{};

    for (final title in groupTitles) {
      final count = await _calculateFilteredCount(
        title,
        minPostCount,
        includeChildren,
        processedGroups,
        0, // 初始深度
      );
      result[title] = count;
    }

    return result;
  }

  /// 递归计算过滤后的标签数量（包含子组）
  ///
  /// [depth] 当前递归深度，用于防止无限递归
  Future<int> _calculateFilteredCount(
    String groupTitle,
    int minPostCount,
    bool includeChildren,
    Set<String> processedGroups,
    int depth,
  ) async {
    // 防止无限递归
    if (depth >= _maxRecursionDepth) {
      AppLogger.w(
        'Max recursion depth reached for group: $groupTitle',
        'TagGroupCache',
      );
      return 0;
    }

    // 防止重复计算（循环引用保护）
    if (processedGroups.contains(groupTitle)) {
      return 0;
    }
    processedGroups.add(groupTitle);

    final group = await getTagGroup(groupTitle);
    if (group == null) {
      return 0;
    }

    // 计算当前组的过滤数量
    int count = group.getTagCountAboveThreshold(minPostCount);

    // 递归计算子组
    if (includeChildren && group.hasChildren) {
      for (final childTitle in group.childGroupTitles) {
        count += await _calculateFilteredCount(
          childTitle,
          minPostCount,
          includeChildren, // 使用传入的参数，而非硬编码
          processedGroups,
          depth + 1,
        );
      }
    }

    return count;
  }

  /// 获取符合热度阈值的标签列表
  List<TagGroupEntry>? getFilteredTags(String groupTitle, int minPostCount) {
    final group = _memoryCache[groupTitle];
    if (group == null) {
      return null;
    }
    return group.getTagsAboveThreshold(minPostCount);
  }

  /// 清除指定组的缓存
  Future<void> removeTagGroup(String groupTitle) async {
    await _ensureInit();
    final key = _cacheKey(groupTitle);
    await _box?.delete(key);
    _memoryCache.remove(groupTitle);
  }

  /// 清除所有缓存
  Future<void> clearCache() async {
    await _ensureInit();
    await _box?.clear();
    _memoryCache.clear();
    AppLogger.d('TagGroup cache cleared', 'TagGroupCache');
  }

  /// 获取缓存统计信息
  Future<Map<String, dynamic>> getCacheStats() async {
    await _ensureInit();
    final groups = await getAllCachedGroups();
    var totalTags = 0;
    for (final group in groups.values) {
      totalTags += group.tagCount;
    }

    return {
      'groupCount': groups.length,
      'totalTags': totalTags,
      'memoryCacheSize': _memoryCache.length,
    };
  }
}

/// Provider
@Riverpod(keepAlive: true)
TagGroupCacheService tagGroupCacheService(Ref ref) {
  return TagGroupCacheService();
}
