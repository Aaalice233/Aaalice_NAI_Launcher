import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/app_logger.dart';
import '../datasources/local/nai_tags_data_source.dart';
import '../datasources/remote/danbooru_tag_library_service.dart';
import '../models/prompt/category_filter_config.dart';
import '../models/prompt/sync_config.dart';
import '../models/prompt/tag_category.dart';
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

  final DanbooruTagLibraryService _remoteService;
  final NaiTagsDataSource _naiTagsDataSource;
  Box? _box;
  Future<void>? _initFuture;

  TagLibraryService(this._remoteService, this._naiTagsDataSource);

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
        final library = TagLibrary.fromJson(data);

        // 检查是否需要迁移：有 Danbooru 补充但标签没有 source 字段
        if (library.hasDanbooruSupplement && _needsMigration(library)) {
          AppLogger.i('Library needs migration for source field', 'TagLibrary');
          return null; // 返回 null 触发重新同步
        }

        return library;
      }
    } catch (e) {
      AppLogger.e('Failed to load local library: $e', 'TagLibrary');
    }
    return null;
  }

  /// 检查词库是否需要迁移（旧数据没有 source 字段）
  bool _needsMigration(TagLibrary library) {
    // 如果有 Danbooru 补充，但所有标签的 source 都是 nai
    // 说明是旧数据，需要重新同步
    if (!library.hasDanbooruSupplement) return false;

    for (final tags in library.categories.values) {
      for (final tag in tags) {
        if (tag.source == TagSource.danbooru) {
          return false; // 已经有正确标记的标签，不需要迁移
        }
      }
    }
    return true; // 有补充但没有标记，需要迁移
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

  /// 同步词库（优化：并行加载）
  ///
  /// 基于 NAI 固定词库，始终从 Danbooru 获取补充标签
  /// 分类级过滤由 CategoryFilterConfig 控制，与同步操作解耦
  Future<TagLibrary> syncLibrary({
    required DataRange range,
    void Function(SyncProgress progress)? onProgress,
  }) async {
    onProgress?.call(SyncProgress.initial());

    // 并行执行可独立的初始化步骤
    final results = await Future.wait([
      _naiTagsDataSource.loadData(),
      loadSyncConfig(),
      _remoteService.checkConnectivity(),
    ]);

    final naiTags = results[0] as NaiTagsData;
    final syncConfig = results[1] as TagLibrarySyncConfig;
    final connected = results[2] as bool;

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

    var supplementCount = 0;

    // 始终获取 Danbooru 补充标签（不受过滤开关影响）
    if (connected) {
      try {
        // 获取补充标签
        final supplementTags = await _remoteService.fetchSupplementTags(
          range: range,
          naiTags: naiTags,
          onProgress: onProgress,
        );

        // 合并补充标签到对应类别
        for (final entry in supplementTags.entries) {
          final categoryName = entry.key.name;
          final existingTags = naiCategories[categoryName] ?? [];
          final existingSet = existingTags.map((t) => t.tag.toLowerCase()).toSet();

          // 只添加不存在的标签
          for (final tag in entry.value) {
            if (!existingSet.contains(tag.tag.toLowerCase())) {
              existingTags.add(tag);
              supplementCount++;
            }
          }
          naiCategories[categoryName] = existingTags;
        }

        AppLogger.d(
          'Added $supplementCount supplement tags from Danbooru',
          'TagLibrary',
        );
      } catch (e) {
        AppLogger.w('Failed to fetch supplement tags: $e', 'TagLibrary');
        // 补充失败不影响主流程
      }
    } else {
      AppLogger.w('Danbooru not reachable, skipping supplement', 'TagLibrary');
    }

    onProgress?.call(SyncProgress.saving());

    // 创建词库
    final library = TagLibrary(
      id: const Uuid().v4(),
      name: 'NAI 词库',
      lastUpdated: DateTime.now(),
      version: 1,
      source: TagLibrarySource.nai,
      hasDanbooruSupplement: supplementCount > 0,
      danbooruSupplementCount: supplementCount,
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
      'Library synced: ${library.totalTagCount} tags (NAI: ${library.totalTagCount - supplementCount}, Supplement: $supplementCount)',
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

  /// 清除词库缓存
  Future<void> clearCache() async {
    await _ensureInit();
    await _box?.delete(_libraryKey);
    AppLogger.d('Library cache cleared', 'TagLibrary');
  }
}

/// Provider
@Riverpod(keepAlive: true)
TagLibraryService tagLibraryService(Ref ref) {
  final remoteService = ref.watch(danbooruTagLibraryServiceProvider);
  final naiTagsDataSource = ref.watch(naiTagsDataSourceProvider);
  return TagLibraryService(remoteService, naiTagsDataSource);
}
