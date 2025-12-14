import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/app_logger.dart';
import '../../../data/datasources/remote/danbooru_pool_service.dart';
import '../../../data/models/danbooru/danbooru_pool.dart';
import '../../../data/models/prompt/default_pool_mappings.dart';
import '../../../data/models/prompt/pool_mapping.dart';
import '../../../data/models/prompt/pool_sync_config.dart';
import '../../../data/models/prompt/tag_category.dart';
import '../../../data/services/tag_library_service.dart';
import 'tag_library_provider.dart';

part 'pool_mapping_provider.g.dart';

/// Pool 映射状态
class PoolMappingState {
  final PoolSyncConfig config;
  final bool isLoading;
  final bool isSyncing;
  final PoolSyncProgress? syncProgress;
  final String? error;

  const PoolMappingState({
    this.config = const PoolSyncConfig(),
    this.isLoading = false,
    this.isSyncing = false,
    this.syncProgress,
    this.error,
  });

  PoolMappingState copyWith({
    PoolSyncConfig? config,
    bool? isLoading,
    bool? isSyncing,
    PoolSyncProgress? syncProgress,
    String? error,
  }) {
    return PoolMappingState(
      config: config ?? this.config,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      syncProgress: syncProgress ?? this.syncProgress,
      error: error,
    );
  }
}

/// Pool 映射状态管理
@Riverpod(keepAlive: true)
class PoolMappingNotifier extends _$PoolMappingNotifier {
  TagLibraryService get _libraryService => ref.read(tagLibraryServiceProvider);
  DanbooruPoolService get _poolService => ref.read(danbooruPoolServiceProvider);

  /// 帖子数量缓存有效期（7天）
  static const _cacheValidDuration = Duration(days: 7);

  @override
  PoolMappingState build() {
    _loadConfig();
    return const PoolMappingState(isLoading: true);
  }

  /// 加载配置
  Future<void> _loadConfig() async {
    try {
      final config = await _libraryService.loadPoolSyncConfig();

      // 检查是否有需要更新帖子数量的映射
      final needsUpdate = config.mappings.any(_needsPostCountUpdate);
      if (needsUpdate && config.mappings.isNotEmpty) {
        // 后台更新帖子数量，不阻塞加载
        _updatePoolPostCounts(config.mappings);
      }

      state = state.copyWith(
        config: config,
        isLoading: false,
      );
    } catch (e) {
      AppLogger.e('Failed to load pool mapping config: $e', 'PoolMapping');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 检查映射是否需要更新帖子数量
  bool _needsPostCountUpdate(PoolMapping mapping) {
    // 如果帖子数量为0，需要更新
    if (mapping.postCount == 0) return true;

    // 如果从未同步过，需要更新
    if (mapping.lastSyncedAt == null) return true;

    // 如果缓存已过期（超过7天），需要更新
    final now = DateTime.now();
    final elapsed = now.difference(mapping.lastSyncedAt!);
    return elapsed > _cacheValidDuration;
  }

  /// 批量更新 Pool 帖子数量
  Future<void> _updatePoolPostCounts(List<PoolMapping> mappings) async {
    try {
      AppLogger.d('Updating pool post counts for ${mappings.length} pools', 'PoolMapping');

      final updatedMappings = <PoolMapping>[];
      var hasChanges = false;

      for (final mapping in mappings) {
        if (!_needsPostCountUpdate(mapping)) {
          updatedMappings.add(mapping);
          continue;
        }

        // 从 API 获取最新的 Pool 信息
        final pool = await _poolService.getPool(mapping.poolId);
        if (pool != null && pool.postCount != mapping.postCount) {
          updatedMappings.add(mapping.copyWith(
            postCount: pool.postCount,
            lastSyncedAt: DateTime.now(),
          ),);
          hasChanges = true;
          AppLogger.d(
            'Updated pool ${mapping.poolName}: ${mapping.postCount} -> ${pool.postCount} posts',
            'PoolMapping',
          );
        } else {
          // 即使数量相同，也更新同步时间以刷新缓存
          updatedMappings.add(mapping.copyWith(
            lastSyncedAt: DateTime.now(),
          ),);
          hasChanges = true;
        }
      }

      if (hasChanges) {
        final newConfig = state.config.copyWith(mappings: updatedMappings);
        await _saveConfig(newConfig);
        AppLogger.i('Pool post counts updated successfully', 'PoolMapping');
      }
    } catch (e) {
      AppLogger.w('Failed to update pool post counts: $e', 'PoolMapping');
      // 更新失败不影响正常使用
    }
  }

  /// 强制刷新所有 Pool 的帖子数量
  Future<void> refreshPoolPostCounts() async {
    if (state.config.mappings.isEmpty) return;

    // 重置所有映射的同步时间以强制更新
    final mappingsToUpdate = state.config.mappings.map((m) {
      return m.copyWith(lastSyncedAt: null);
    }).toList();

    await _updatePoolPostCounts(mappingsToUpdate);
  }

  /// 设置是否启用 Pool 同步
  Future<void> setEnabled(bool enabled) async {
    final newConfig = state.config.copyWith(enabled: enabled);
    await _saveConfig(newConfig);
  }

  /// 添加 Pool 映射
  Future<void> addMapping({
    required int poolId,
    required String poolName,
    required int postCount,
    required TagSubCategory targetCategory,
  }) async {
    // 检查是否已存在
    if (state.config.hasPool(poolId)) {
      throw Exception('Pool 已添加');
    }

    final mapping = PoolMapping(
      id: const Uuid().v4(),
      poolId: poolId,
      poolName: poolName,
      postCount: postCount,
      targetCategory: targetCategory,
      createdAt: DateTime.now(),
    );

    final newMappings = [...state.config.mappings, mapping];
    final newConfig = state.config.copyWith(mappings: newMappings);
    await _saveConfig(newConfig);

    AppLogger.d('Added pool mapping: $poolName -> ${targetCategory.name}', 'PoolMapping');
  }

  /// 更新 Pool 映射
  Future<void> updateMapping(PoolMapping mapping) async {
    final index = state.config.mappings.indexWhere((m) => m.id == mapping.id);
    if (index == -1) return;

    final newMappings = List<PoolMapping>.from(state.config.mappings);
    newMappings[index] = mapping;
    final newConfig = state.config.copyWith(mappings: newMappings);
    await _saveConfig(newConfig);
  }

  /// 切换映射启用状态
  Future<void> toggleMappingEnabled(String mappingId) async {
    final mapping = state.config.findMappingById(mappingId);
    if (mapping == null) return;

    await updateMapping(mapping.copyWith(enabled: !mapping.enabled));
  }

  /// 删除 Pool 映射
  Future<void> removeMapping(String mappingId) async {
    final newMappings = state.config.mappings
        .where((m) => m.id != mappingId)
        .toList();
    final newConfig = state.config.copyWith(mappings: newMappings);
    await _saveConfig(newConfig);

    AppLogger.d('Removed pool mapping: $mappingId', 'PoolMapping');
  }

  /// 恢复默认配置
  Future<void> resetToDefault() async {
    final defaultConfig = DefaultPoolMappings.getDefaultConfig();
    await _saveConfig(defaultConfig);
    AppLogger.i('Pool mapping reset to default', 'PoolMapping');

    // 后台更新帖子数量
    _updatePoolPostCounts(defaultConfig.mappings);
  }

  /// 搜索 Pools
  Future<List<DanbooruPool>> searchPools(String query) async {
    if (query.trim().isEmpty) return [];
    return _poolService.searchPools(query, limit: 20);
  }

  /// 同步 Pool 标签
  Future<bool> syncPools() async {
    if (state.isSyncing) return false;

    final enabledMappings = state.config.enabledMappings;
    if (enabledMappings.isEmpty) {
      return true;
    }

    state = state.copyWith(isSyncing: true, error: null);

    try {
      // 获取 Pool 标签
      final syncResult = await _poolService.syncPoolMappings(
        mappings: enabledMappings,
        maxPostsPerPool: state.config.maxPostsPerPool,
        minOccurrence: state.config.minTagOccurrence,
        onProgress: (progress) {
          state = state.copyWith(syncProgress: progress);
        },
      );

      if (syncResult.isEmpty) {
        state = state.copyWith(isSyncing: false, syncProgress: null);
        return true;
      }

      // 合并到词库
      final libraryNotifier = ref.read(tagLibraryNotifierProvider.notifier);
      await libraryNotifier.mergePoolTags(syncResult.categoryTags);

      // 更新映射的同步信息（使用每个 Pool 自己的标签数）
      final now = DateTime.now();
      final updatedMappings = state.config.mappings.map((m) {
        if (!m.enabled) return m;
        final tagCount = syncResult.poolTagCounts[m.poolId] ?? 0;
        return m.copyWith(
          lastSyncedAt: now,
          lastSyncedTagCount: tagCount,
        );
      }).toList();

      final newConfig = state.config.copyWith(
        mappings: updatedMappings,
        lastFullSyncTime: now,
      );
      await _saveConfig(newConfig);

      state = state.copyWith(isSyncing: false, syncProgress: null);
      AppLogger.i('Pool sync completed successfully', 'PoolMapping');
      return true;
    } catch (e, stack) {
      AppLogger.e('Pool sync failed: $e', e, stack, 'PoolMapping');
      state = state.copyWith(
        isSyncing: false,
        syncProgress: null,
        error: e.toString(),
      );
      return false;
    }
  }

  /// 保存配置
  Future<void> _saveConfig(PoolSyncConfig config) async {
    await _libraryService.savePoolSyncConfig(config);
    state = state.copyWith(config: config);
  }
}
