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
    return _loadJson(_libraryKey, TagLibrary.fromJson);
  }

  /// 保存词库到本地
  Future<void> saveLibrary(TagLibrary library) async {
    await _ensureInit();
    await _saveJson(
      _libraryKey,
      library.toJson(),
      onSuccess: () => AppLogger.d('Library saved: ${library.totalTagCount} tags', 'TagLibrary'),
    );
  }

  /// 加载同步配置
  Future<TagLibrarySyncConfig> loadSyncConfig() async {
    await _ensureInit();
    final result = await _loadJson<TagLibrarySyncConfig>(_syncConfigKey, TagLibrarySyncConfig.fromJson);
    return result ?? const TagLibrarySyncConfig();
  }

  /// 保存同步配置
  Future<void> saveSyncConfig(TagLibrarySyncConfig config) async {
    await _ensureInit();
    await _saveJson(_syncConfigKey, config.toJson());
  }

  /// 加载分类过滤配置
  Future<CategoryFilterConfig> loadCategoryFilterConfig() async {
    await _ensureInit();
    final result = await _loadJson<CategoryFilterConfig>(_categoryFilterKey, CategoryFilterConfig.fromJson);
    return result ?? const CategoryFilterConfig();
  }

  /// 保存分类过滤配置
  Future<void> saveCategoryFilterConfig(CategoryFilterConfig config) async {
    await _ensureInit();
    await _saveJson(_categoryFilterKey, config.toJson());
  }

  /// 通用 JSON 加载方法
  Future<T?> _loadJson<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final json = _box?.get(key) as String?;
      if (json != null) {
        return fromJson(jsonDecode(json) as Map<String, dynamic>);
      }
    } catch (e) {
      AppLogger.e('Failed to load $key: $e', 'TagLibrary');
    }
    return null;
  }

  /// 通用 JSON 保存方法
  Future<void> _saveJson(
    String key,
    Map<String, dynamic> data, {
    void Function()? onSuccess,
  }) async {
    try {
      await _box?.put(key, jsonEncode(data));
      onSuccess?.call();
    } catch (e) {
      AppLogger.e('Failed to save $key: $e', 'TagLibrary');
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

    // 发型
    categories[TagSubCategory.hairStyle.name] = [
      WeightedTag.simple('long hair', 8),
      WeightedTag.simple('short hair', 6),
      WeightedTag.simple('medium hair', 5),
      WeightedTag.simple('ponytail', 4),
      WeightedTag.simple('twintails', 3),
      WeightedTag.simple('braid', 3),
      WeightedTag.simple('bob cut', 2),
      WeightedTag.simple('bangs', 5),
    ];

    // 配饰
    categories[TagSubCategory.accessory.name] = [
      WeightedTag.simple('glasses', 4),
      WeightedTag.simple('hat', 3),
      WeightedTag.simple('ribbon', 4),
      WeightedTag.simple('bow', 3),
      WeightedTag.simple('earrings', 2),
      WeightedTag.simple('necklace', 2),
      WeightedTag.simple('hairband', 3),
      WeightedTag.simple('hair ornament', 4),
    ];

    // 女性服装
    categories[TagSubCategory.clothingFemale.name] = [
      WeightedTag.simple('dress', 8),
      WeightedTag.simple('skirt', 7),
      WeightedTag.simple('school uniform', 6),
      WeightedTag.simple('bikini', 4),
      WeightedTag.simple('swimsuit', 4),
      WeightedTag.simple('maid', 3),
      WeightedTag.simple('kimono', 3),
      WeightedTag.simple('wedding dress', 2),
    ];

    // 男性服装
    categories[TagSubCategory.clothingMale.name] = [
      WeightedTag.simple('suit', 6),
      WeightedTag.simple('formal', 4),
      WeightedTag.simple('uniform', 5),
      WeightedTag.simple('armor', 3),
      WeightedTag.simple('cape', 2),
    ];

    // 通用服装
    categories[TagSubCategory.clothingGeneral.name] = [
      WeightedTag.simple('shirt', 6),
      WeightedTag.simple('jacket', 5),
      WeightedTag.simple('hoodie', 4),
      WeightedTag.simple('sweater', 4),
      WeightedTag.simple('coat', 3),
      WeightedTag.simple('t-shirt', 4),
      WeightedTag.simple('jeans', 3),
      WeightedTag.simple('shorts', 3),
    ];

    // 女性体型
    categories[TagSubCategory.bodyFeatureFemale.name] = [
      WeightedTag.simple('slim', 5),
      WeightedTag.simple('curvy', 3),
      WeightedTag.simple('petite', 3),
      WeightedTag.simple('tall', 2),
    ];

    // 男性体型
    categories[TagSubCategory.bodyFeatureMale.name] = [
      WeightedTag.simple('muscular', 4),
      WeightedTag.simple('slim', 4),
      WeightedTag.simple('athletic', 3),
      WeightedTag.simple('tall', 3),
    ];

    // 通用体型
    categories[TagSubCategory.bodyFeatureGeneral.name] = [
      WeightedTag.simple('slim', 5),
      WeightedTag.simple('athletic', 4),
      WeightedTag.simple('tall', 3),
      WeightedTag.simple('short', 2),
      WeightedTag.simple('young', 4),
      WeightedTag.simple('mature', 2),
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

  /// 获取内置词库（直接从 JSON 读取，不使用缓存）
  Future<TagLibrary> getAvailableLibrary() async {
    try {
      final naiTags = await _naiTagsDataSource.loadData();
      final naiCategories = <String, List<WeightedTag>>{};

      for (final categoryName in naiTags.categoryNames) {
        final tags = naiTags.getCategory(categoryName);
        if (tags.isNotEmpty) {
          naiCategories[categoryName] = tags.map((t) {
            return WeightedTag.simple(t.replaceAll('_', ' '), 5);
          }).toList();
        }
      }

      if (naiCategories.isNotEmpty) {
        return TagLibrary(
          id: 'nai_builtin',
          name: 'NAI 内置词库',
          lastUpdated: DateTime.now(),
          version: 1,
          source: TagLibrarySource.nai,
          categories: naiCategories,
        );
      }
    } catch (e) {
      AppLogger.e('Failed to load from local JSON: $e', 'TagLibrary');
    }

    // 回退到硬编码的内置词库
    return getBuiltinLibrary();
  }

  /// 检查是否需要同步
  Future<bool> shouldSync() async {
    final config = await loadSyncConfig();
    return config.shouldSync();
  }

  // ==================== Pool 同步配置 ====================

  // ==================== Pool 同步配置 ====================

  /// 加载 Pool 同步配置
  Future<PoolSyncConfig> loadPoolSyncConfig() async {
    await _ensureInit();
    final result = await _loadJson<PoolSyncConfig>(_poolSyncConfigKey, PoolSyncConfig.fromJson);
    return result ?? DefaultPoolMappings.getDefaultConfig();
  }

  /// 保存 Pool 同步配置
  Future<void> savePoolSyncConfig(PoolSyncConfig config) async {
    await _ensureInit();
    await _saveJson(
      _poolSyncConfigKey,
      config.toJson(),
      onSuccess: () => AppLogger.d('Pool sync config saved', 'TagLibrary'),
    );
  }

  /// 合并 Pool 标签到词库
  TagLibrary mergePoolTags(
    TagLibrary library,
    Map<TagSubCategory, List<WeightedTag>> poolTags,
  ) {
    return _mergeTags(library, poolTags, updateSupplement: false);
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
    final result = await _loadJson<TagGroupSyncConfig>(_tagGroupSyncConfigKey, TagGroupSyncConfig.fromJson);
    return result ?? DefaultTagGroupMappings.getDefaultConfig();
  }

  /// 保存 Tag Group 同步配置
  Future<void> saveTagGroupSyncConfig(TagGroupSyncConfig config) async {
    await _ensureInit();
    await _saveJson(
      _tagGroupSyncConfigKey,
      config.toJson(),
      onSuccess: () => AppLogger.d('Tag group sync config saved', 'TagLibrary'),
    );
  }

  /// 合并 Tag Group 标签到词库
  TagLibrary mergeTagGroupTags(
    TagLibrary library,
    Map<TagSubCategory, List<WeightedTag>> tagGroupTags,
  ) {
    return _mergeTags(library, tagGroupTags, updateSupplement: true);
  }

  /// 通用标签合并逻辑
  TagLibrary _mergeTags(
    TagLibrary library,
    Map<TagSubCategory, List<WeightedTag>> tags, {
    required bool updateSupplement,
  }) {
    if (tags.isEmpty) return library;

    final mergedCategories = Map<String, List<WeightedTag>>.from(library.categories);
    var addedCount = 0;

    for (final entry in tags.entries) {
      final categoryName = entry.key.name;
      final existingTags = mergedCategories[categoryName] ?? [];
      final existingNames = existingTags.map((t) => t.tag.toLowerCase()).toSet();

      for (final tag in entry.value) {
        if (!existingNames.contains(tag.tag.toLowerCase())) {
          existingTags.add(tag);
          existingNames.add(tag.tag.toLowerCase());
          addedCount++;
        }
      }

      mergedCategories[categoryName] = existingTags;
    }

    AppLogger.d('Merged $addedCount tags into library', 'TagLibrary');

    return library.copyWith(
      categories: mergedCategories,
      lastUpdated: DateTime.now(),
      hasDanbooruSupplement: updateSupplement ? true : library.hasDanbooruSupplement,
      danbooruSupplementCount: updateSupplement ? addedCount : library.danbooruSupplementCount,
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
