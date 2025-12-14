import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/app_logger.dart';
import '../datasources/local/nai_tags_data_source.dart';
import '../models/prompt/category_filter_config.dart';
import '../models/prompt/default_pool_mappings.dart';
import '../models/prompt/default_tag_group_mappings.dart';
import '../models/prompt/pool_sync_config.dart';
import '../models/prompt/sync_config.dart';
import '../models/prompt/tag_category.dart';
import '../models/prompt/tag_group.dart';
import '../models/prompt/tag_group_sync_config.dart';
import '../models/prompt/tag_library.dart';
import '../models/prompt/weighted_tag.dart';

part 'tag_library_service.g.dart';

/// 词库管理服务
///
/// 负责词库的加载、保存、同步等操作
class TagLibraryService {
  static const String _boxName = 'tag_library';
  static const String _libraryKey = 'library';
  static const String _syncConfigKey = 'sync_config';
  static const String _categoryFilterKey = 'category_filter_config';
  static const String _poolSyncConfigKey = 'pool_sync_config';
  static const String _tagGroupSyncConfigKey = 'tag_group_sync_config';

  final NaiTagsDataSource _naiTagsDataSource;
  Box? _box;
  Future<void>? _initFuture;

  TagLibraryService(this._naiTagsDataSource);

  /// 初始化
  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  /// 确保已初始化（线程安全）
  Future<void> _ensureInit() async {
    if (_box != null && _box!.isOpen) return;

    // 使用 Future 锁避免并发初始化
    _initFuture ??= init();
    await _initFuture;
  }

  /// 加载本地词库
  Future<TagLibrary?> loadLocalLibrary() async {
    await _ensureInit();
    try {
      final json = _box?.get(_libraryKey) as String?;
      if (json != null) {
        final data = jsonDecode(json) as Map<String, dynamic>;
        return TagLibrary.fromJson(data);
      }
    } catch (e) {
      AppLogger.e('Failed to load local library: $e', 'TagLibrary');
    }
    return null;
  }

  /// 保存词库到本地
  Future<void> saveLibrary(TagLibrary library) async {
    await _ensureInit();
    try {
      final json = jsonEncode(library.toJson());
      await _box?.put(_libraryKey, json);
      AppLogger.d('Library saved: ${library.totalTagCount} tags', 'TagLibrary');
    } catch (e) {
      AppLogger.e('Failed to save library: $e', 'TagLibrary');
      rethrow;
    }
  }

  /// 加载同步配置
  Future<TagLibrarySyncConfig> loadSyncConfig() async {
    await _ensureInit();
    try {
      final json = _box?.get(_syncConfigKey) as String?;
      if (json != null) {
        final data = jsonDecode(json) as Map<String, dynamic>;
        return TagLibrarySyncConfig.fromJson(data);
      }
    } catch (e) {
      AppLogger.e('Failed to load sync config: $e', 'TagLibrary');
    }
    return const TagLibrarySyncConfig();
  }

  /// 保存同步配置
  Future<void> saveSyncConfig(TagLibrarySyncConfig config) async {
    await _ensureInit();
    try {
      final json = jsonEncode(config.toJson());
      await _box?.put(_syncConfigKey, json);
    } catch (e) {
      AppLogger.e('Failed to save sync config: $e', 'TagLibrary');
      rethrow;
    }
  }

  /// 加载分类过滤配置
  Future<CategoryFilterConfig> loadCategoryFilterConfig() async {
    await _ensureInit();
    try {
      final json = _box?.get(_categoryFilterKey) as String?;
      if (json != null) {
        final data = jsonDecode(json) as Map<String, dynamic>;
        return CategoryFilterConfig.fromJson(data);
      }
    } catch (e) {
      AppLogger.e('Failed to load category filter config: $e', 'TagLibrary');
    }
    return const CategoryFilterConfig();
  }

  /// 保存分类过滤配置
  Future<void> saveCategoryFilterConfig(CategoryFilterConfig config) async {
    await _ensureInit();
    try {
      final json = jsonEncode(config.toJson());
      await _box?.put(_categoryFilterKey, json);
    } catch (e) {
      AppLogger.e('Failed to save category filter config: $e', 'TagLibrary');
      rethrow;
    }
  }

  /// 同步词库
  ///
  /// 仅加载 NAI 固定词库，Danbooru 补充标签由 Pool 同步机制独立处理
  Future<TagLibrary> syncLibrary({
    required DataRange range,
    void Function(SyncProgress progress)? onProgress,
  }) async {
    onProgress?.call(SyncProgress.initial());

    // 加载 NAI 标签数据和同步配置
    final results = await Future.wait([
      _naiTagsDataSource.loadData(),
      loadSyncConfig(),
    ]);

    final naiTags = results[0] as NaiTagsData;
    final syncConfig = results[1] as TagLibrarySyncConfig;

    // 构建 NAI 固定词库
    final naiCategories = <String, List<WeightedTag>>{};
    for (final categoryName in naiTags.categoryNames) {
      final tags = naiTags.getCategory(categoryName);
      if (tags.isNotEmpty) {
        // NAI 固定标签使用较高的默认权重
        naiCategories[categoryName] = tags.map((t) {
          return WeightedTag.simple(t.replaceAll('_', ' '), 5);
        }).toList();
      }
    }

    onProgress?.call(SyncProgress.saving());

    // 创建词库（无 Danbooru 热度标签补充，Pool 标签由独立机制处理）
    final library = TagLibrary(
      id: const Uuid().v4(),
      name: 'NAI 词库',
      lastUpdated: DateTime.now(),
      version: 1,
      source: TagLibrarySource.nai,
      hasDanbooruSupplement: false,
      danbooruSupplementCount: 0,
      categories: naiCategories,
    );

    // 保存词库
    await saveLibrary(library);

    // 更新同步配置
    final newConfig = syncConfig.copyWith(
      lastSyncTime: DateTime.now(),
      status: SyncStatus.success,
      lastSyncTagCount: library.totalTagCount,
      lastError: null,
    );
    await saveSyncConfig(newConfig);

    onProgress?.call(SyncProgress.completed(library.totalTagCount));

    AppLogger.i(
      'Library synced: ${library.totalTagCount} NAI tags',
      'TagLibrary',
    );

    return library;
  }

  /// 获取内置默认词库
  TagLibrary getBuiltinLibrary() {
    final categories = <String, List<WeightedTag>>{};

    // 从 DefaultPresets 转换
    // 发色
    categories[TagSubCategory.hairColor.name] = [
      WeightedTag.simple('blonde hair', 5),
      WeightedTag.simple('blue hair', 4),
      WeightedTag.simple('black hair', 6),
      WeightedTag.simple('brown hair', 5),
      WeightedTag.simple('red hair', 3),
      WeightedTag.simple('white hair', 3),
      WeightedTag.simple('pink hair', 2),
      WeightedTag.simple('green hair', 2),
      WeightedTag.simple('purple hair', 2),
      WeightedTag.simple('silver hair', 2),
      WeightedTag.simple('grey hair', 2),
      WeightedTag.simple('orange hair', 2),
      WeightedTag.simple('multicolored hair', 1),
    ];

    // 瞳色
    categories[TagSubCategory.eyeColor.name] = [
      WeightedTag.simple('blue eyes', 6),
      WeightedTag.simple('red eyes', 5),
      WeightedTag.simple('green eyes', 4),
      WeightedTag.simple('brown eyes', 4),
      WeightedTag.simple('purple eyes', 3),
      WeightedTag.simple('yellow eyes', 3),
      WeightedTag.simple('golden eyes', 3),
      WeightedTag.simple('amber eyes', 3),
      WeightedTag.simple('heterochromia', 1),
    ];

    // 表情
    categories[TagSubCategory.expression.name] = [
      WeightedTag.simple('smile', 10),
      WeightedTag.simple('blush', 8),
      WeightedTag.simple('open mouth', 6),
      WeightedTag.simple('closed eyes', 4),
      WeightedTag.simple('grin', 3),
      WeightedTag.simple('expressionless', 2),
      WeightedTag.simple('frown', 2),
      WeightedTag.simple('crying', 1),
      WeightedTag.simple('angry', 1),
    ];

    // 背景
    categories[TagSubCategory.background.name] = [
      WeightedTag.simple('simple background', 10),
      WeightedTag.simple('white background', 8),
      WeightedTag.simple('grey background', 5),
      WeightedTag.simple('black background', 4),
      WeightedTag.simple('gradient background', 3),
      WeightedTag.simple('blurred background', 3),
      WeightedTag.simple('abstract background', 2),
      WeightedTag.simple('detailed background', 5),
    ];

    // 场景
    categories[TagSubCategory.scene.name] = [
      WeightedTag.simple('outdoors', 8),
      WeightedTag.simple('indoors', 8),
      WeightedTag.simple('scenery', 6),
      WeightedTag.simple('nature', 5),
      WeightedTag.simple('city', 4),
      WeightedTag.simple('sky', 5),
      WeightedTag.simple('clouds', 4),
      WeightedTag.simple('sunset', 3),
      WeightedTag.simple('night', 3),
      WeightedTag.simple('rain', 2),
      WeightedTag.simple('snow', 2),
    ];

    // 姿势
    categories[TagSubCategory.pose.name] = [
      WeightedTag.simple('looking at viewer', 10),
      WeightedTag.simple('standing', 8),
      WeightedTag.simple('sitting', 7),
      WeightedTag.simple('lying', 4),
      WeightedTag.simple('kneeling', 3),
      WeightedTag.simple('walking', 3),
      WeightedTag.simple('running', 2),
      WeightedTag.simple('from above', 3),
      WeightedTag.simple('from below', 2),
      WeightedTag.simple('from side', 3),
      WeightedTag.simple('from behind', 2),
    ];

    // 风格
    categories[TagSubCategory.style.name] = [
      WeightedTag.simple('masterpiece', 10),
      WeightedTag.simple('best quality', 10),
      WeightedTag.simple('high quality', 8),
      WeightedTag.simple('detailed', 6),
      WeightedTag.simple('photorealistic', 2),
      WeightedTag.simple('anime', 5),
    ];

    // 人数
    // 注意: "duo" 和 "trio" 是 Danbooru 已废弃的标签，使用具体的角色组合标签
    // 混合性别组合应该拆分成独立标签，如 "1girl, 1boy"
    categories[TagSubCategory.characterCount.name] = [
      WeightedTag.simple('solo', 70),
      WeightedTag.simple('1girl', 60),
      WeightedTag.simple('1boy', 30),
      WeightedTag.simple('2girls', 20),
      WeightedTag.simple('2boys', 10),
      WeightedTag.simple('multiple girls', 10),
      WeightedTag.simple('no humans', 5),
    ];

    return TagLibrary(
      id: 'builtin',
      name: '内置词库',
      lastUpdated: DateTime(2025, 1, 1),
      version: 1,
      source: TagLibrarySource.builtin,
      categories: categories,
    );
  }

  /// 获取当前可用词库（优先本地，回退内置）
  Future<TagLibrary> getAvailableLibrary() async {
    final local = await loadLocalLibrary();
    if (local != null && local.isValid) {
      return local;
    }
    return getBuiltinLibrary();
  }

  /// 检查是否需要同步
  Future<bool> shouldSync() async {
    final config = await loadSyncConfig();
    return config.shouldSync();
  }

  // ==================== Pool 同步配置 ====================

  /// 加载 Pool 同步配置
  Future<PoolSyncConfig> loadPoolSyncConfig() async {
    await _ensureInit();
    try {
      final json = _box?.get(_poolSyncConfigKey) as String?;
      if (json != null) {
        final data = jsonDecode(json) as Map<String, dynamic>;
        return PoolSyncConfig.fromJson(data);
      }
    } catch (e) {
      AppLogger.e('Failed to load pool sync config: $e', 'TagLibrary');
    }
    // 返回默认配置（包含预设的 Pool 映射）
    return DefaultPoolMappings.getDefaultConfig();
  }

  /// 保存 Pool 同步配置
  Future<void> savePoolSyncConfig(PoolSyncConfig config) async {
    await _ensureInit();
    try {
      final json = jsonEncode(config.toJson());
      await _box?.put(_poolSyncConfigKey, json);
      AppLogger.d('Pool sync config saved', 'TagLibrary');
    } catch (e) {
      AppLogger.e('Failed to save pool sync config: $e', 'TagLibrary');
      rethrow;
    }
  }

  /// 合并 Pool 标签到词库
  ///
  /// [library] 原始词库
  /// [poolTags] Pool 提取的标签（按目标分类）
  ///
  /// 返回合并后的词库
  TagLibrary mergePoolTags(
    TagLibrary library,
    Map<TagSubCategory, List<WeightedTag>> poolTags,
  ) {
    if (poolTags.isEmpty) {
      return library;
    }

    final mergedCategories = Map<String, List<WeightedTag>>.from(library.categories);
    var addedCount = 0;

    for (final entry in poolTags.entries) {
      final categoryName = entry.key.name;
      final existingTags = mergedCategories[categoryName] ?? [];
      final existingNames = existingTags.map((t) => t.tag.toLowerCase()).toSet();

      // 添加不重复的标签
      for (final tag in entry.value) {
        if (!existingNames.contains(tag.tag.toLowerCase())) {
          existingTags.add(tag);
          existingNames.add(tag.tag.toLowerCase());
          addedCount++;
        }
      }

      mergedCategories[categoryName] = existingTags;
    }

    AppLogger.d(
      'Merged $addedCount pool tags into library',
      'TagLibrary',
    );

    return library.copyWith(
      categories: mergedCategories,
      lastUpdated: DateTime.now(),
    );
  }

  /// 清除词库缓存
  Future<void> clearCache() async {
    await _ensureInit();
    await _box?.delete(_libraryKey);
    AppLogger.d('Library cache cleared', 'TagLibrary');
  }

  // ==================== Tag Group 同步配置 ====================

  /// 加载 Tag Group 同步配置
  Future<TagGroupSyncConfig> loadTagGroupSyncConfig() async {
    await _ensureInit();
    try {
      final json = _box?.get(_tagGroupSyncConfigKey) as String?;
      if (json != null) {
        final data = jsonDecode(json) as Map<String, dynamic>;
        return TagGroupSyncConfig.fromJson(data);
      }
    } catch (e) {
      AppLogger.e('Failed to load tag group sync config: $e', 'TagLibrary');
    }
    // 返回默认配置
    return DefaultTagGroupMappings.getDefaultConfig();
  }

  /// 保存 Tag Group 同步配置
  Future<void> saveTagGroupSyncConfig(TagGroupSyncConfig config) async {
    await _ensureInit();
    try {
      final json = jsonEncode(config.toJson());
      await _box?.put(_tagGroupSyncConfigKey, json);
      AppLogger.d('Tag group sync config saved', 'TagLibrary');
    } catch (e) {
      AppLogger.e('Failed to save tag group sync config: $e', 'TagLibrary');
      rethrow;
    }
  }

  /// 合并 Tag Group 标签到词库
  ///
  /// [library] 原始词库
  /// [tagGroupTags] Tag Group 提取的标签（按目标分类）
  ///
  /// 返回合并后的词库
  TagLibrary mergeTagGroupTags(
    TagLibrary library,
    Map<TagSubCategory, List<WeightedTag>> tagGroupTags,
  ) {
    if (tagGroupTags.isEmpty) {
      return library;
    }

    final mergedCategories = Map<String, List<WeightedTag>>.from(library.categories);
    var addedCount = 0;

    for (final entry in tagGroupTags.entries) {
      final categoryName = entry.key.name;
      final existingTags = mergedCategories[categoryName] ?? [];
      final existingNames = existingTags.map((t) => t.tag.toLowerCase()).toSet();

      // 添加不重复的标签
      for (final tag in entry.value) {
        if (!existingNames.contains(tag.tag.toLowerCase())) {
          existingTags.add(tag);
          existingNames.add(tag.tag.toLowerCase());
          addedCount++;
        }
      }

      mergedCategories[categoryName] = existingTags;
    }

    AppLogger.d(
      'Merged $addedCount tag group tags into library',
      'TagLibrary',
    );

    return library.copyWith(
      categories: mergedCategories,
      lastUpdated: DateTime.now(),
      hasDanbooruSupplement: true,
      danbooruSupplementCount: addedCount,
    );
  }

  /// 从 TagGroupEntry 列表转换为 WeightedTag 列表
  ///
  /// [entries] TagGroupEntry 列表
  List<WeightedTag> tagGroupEntriesToWeightedTags(
    List<TagGroupEntry> entries,
  ) {
    return entries.map((entry) {
      // 根据热度计算权重 (1-10)
      final weight = _calculateWeight(entry.postCount);
      return WeightedTag(
        tag: entry.displayName,
        weight: weight,
        source: TagSource.danbooru,
      );
    }).toList();
  }

  /// 根据帖子数量计算权重
  int _calculateWeight(int postCount) {
    if (postCount <= 0) return 1;
    if (postCount < 1000) return 1;
    if (postCount < 5000) return 2;
    if (postCount < 10000) return 3;
    if (postCount < 50000) return 4;
    if (postCount < 100000) return 5;
    if (postCount < 500000) return 6;
    if (postCount < 1000000) return 7;
    if (postCount < 2000000) return 8;
    if (postCount < 5000000) return 9;
    return 10;
  }
}

/// Provider
@Riverpod(keepAlive: true)
TagLibraryService tagLibraryService(Ref ref) {
  final naiTagsDataSource = ref.watch(naiTagsDataSourceProvider);
  return TagLibraryService(naiTagsDataSource);
}
