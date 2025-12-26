import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/datasources/local/pool_cache_service.dart';
import '../../../data/datasources/local/tag_group_cache_service.dart';
import '../../../data/datasources/remote/danbooru_pool_service.dart';
import '../../../data/datasources/remote/danbooru_tag_group_service.dart';
import '../../../data/models/prompt/tag_group.dart';

/// 缓存管理对话框
///
/// 显示本地已缓存的 Tag Group 和 Pool 数据，
/// 支持查看详情、刷新单项和刷新全部
class CacheManagementDialog extends ConsumerStatefulWidget {
  const CacheManagementDialog({super.key});

  /// 显示缓存管理对话框
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const CacheManagementDialog(),
    );
  }

  @override
  ConsumerState<CacheManagementDialog> createState() =>
      _CacheManagementDialogState();
}

class _CacheManagementDialogState extends ConsumerState<CacheManagementDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Tag Group 缓存数据
  Map<String, TagGroup> _tagGroupCache = {};
  bool _isLoadingTagGroups = true;

  // Pool 缓存数据
  Map<int, PoolCacheEntry> _poolCache = {};
  bool _isLoadingPools = true;

  // 刷新状态
  final Set<String> _refreshingTagGroups = {};
  final Set<int> _refreshingPools = {};
  bool _isRefreshingAll = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCacheData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCacheData() async {
    await Future.wait([
      _loadTagGroupCache(),
      _loadPoolCache(),
    ]);
  }

  Future<void> _loadTagGroupCache() async {
    setState(() => _isLoadingTagGroups = true);
    try {
      final cacheService = ref.read(tagGroupCacheServiceProvider);
      final groups = await cacheService.getAllCachedGroups();
      if (mounted) {
        setState(() {
          _tagGroupCache = groups;
          _isLoadingTagGroups = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTagGroups = false);
      }
    }
  }

  Future<void> _loadPoolCache() async {
    setState(() => _isLoadingPools = true);
    try {
      final cacheService = ref.read(poolCacheServiceProvider);
      final pools = await cacheService.getAllCachedPools();
      if (mounted) {
        setState(() {
          _poolCache = pools;
          _isLoadingPools = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPools = false);
      }
    }
  }

  Future<void> _refreshTagGroup(String groupTitle) async {
    if (_refreshingTagGroups.contains(groupTitle)) return;

    setState(() => _refreshingTagGroups.add(groupTitle));
    try {
      final tagGroupService = ref.read(danbooruTagGroupServiceProvider);
      await tagGroupService.syncTagGroup(
        groupTitle: groupTitle,
        minPostCount: 0, // 获取全部
        includeChildren: true,
      );
      await _loadTagGroupCache();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('刷新失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _refreshingTagGroups.remove(groupTitle));
      }
    }
  }

  Future<void> _refreshPool(int poolId, String poolName) async {
    if (_refreshingPools.contains(poolId)) return;

    setState(() => _refreshingPools.add(poolId));
    try {
      final poolService = ref.read(danbooruPoolServiceProvider);
      final poolCacheService = ref.read(poolCacheServiceProvider);

      final tags = await poolService.extractTagsFromPool(
        poolId: poolId,
        poolName: poolName,
        maxPosts: 100,
        minOccurrence: 3,
      );

      final pool = _poolCache[poolId];
      await poolCacheService.savePool(
        poolId,
        poolName,
        tags,
        pool?.postCount ?? 0,
      );
      await _loadPoolCache();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('刷新失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _refreshingPools.remove(poolId));
      }
    }
  }

  Future<void> _refreshAll() async {
    if (_isRefreshingAll) return;

    setState(() => _isRefreshingAll = true);
    try {
      // 刷新所有 Tag Group
      for (final groupTitle in _tagGroupCache.keys) {
        await _refreshTagGroup(groupTitle);
      }
      // 刷新所有 Pool
      for (final entry in _poolCache.entries) {
        await _refreshPool(entry.key, entry.value.poolName);
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshingAll = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    final totalCacheCount = _tagGroupCache.length + _poolCache.length;
    var totalTags = 0;
    for (final group in _tagGroupCache.values) {
      totalTags += group.tagCount;
    }
    for (final pool in _poolCache.values) {
      totalTags += pool.tagCount;
    }

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.storage_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(l10n.cache_title),
        ],
      ),
      content: SizedBox(
        width: 500,
        height: 450,
        child: Column(
          children: [
            // Tab 栏
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text(l10n.cache_tabTagGroup),
                      if (_tagGroupCache.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_tagGroupCache.length}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.collections_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text(l10n.cache_tabPool),
                      if (_poolCache.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_poolCache.length}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Tab 内容
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTagGroupList(theme),
                  _buildPoolList(theme),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // 底部统计和刷新按钮
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.cache_totalStats(totalCacheCount, totalTags),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                  if (totalCacheCount > 0)
                    TextButton.icon(
                      onPressed: _isRefreshingAll ? null : _refreshAll,
                      icon: _isRefreshingAll
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh, size: 16),
                      label: Text(l10n.cache_refreshAll),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.addGroup_cancel),
        ),
      ],
    );
  }

  Widget _buildTagGroupList(ThemeData theme) {
    final l10n = context.l10n;

    if (_isLoadingTagGroups) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tagGroupCache.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.cache_noTagGroups,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    final groups = _tagGroupCache.values.toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));

    return ListView.builder(
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        final isRefreshing = _refreshingTagGroups.contains(group.title);

        return ListTile(
          leading: Icon(
            Icons.cloud_outlined,
            color: theme.colorScheme.primary,
          ),
          title: Text(group.displayName),
          subtitle: Text(
            group.title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标签数量徽章
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${group.tagCount} ${l10n.cache_tags}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 刷新按钮
              IconButton(
                onPressed:
                    isRefreshing ? null : () => _refreshTagGroup(group.title),
                icon: isRefreshing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 20),
                tooltip: l10n.cache_refresh,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPoolList(ThemeData theme) {
    final l10n = context.l10n;

    if (_isLoadingPools) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_poolCache.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.collections_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.cache_noPools,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    final pools = _poolCache.values.toList()
      ..sort((a, b) => a.poolName.compareTo(b.poolName));

    return ListView.builder(
      itemCount: pools.length,
      itemBuilder: (context, index) {
        final pool = pools[index];
        final isRefreshing = _refreshingPools.contains(pool.poolId);
        final lastSynced = _formatLastSynced(pool.lastSyncedAt);

        return ListTile(
          leading: Icon(
            Icons.collections_outlined,
            color: theme.colorScheme.primary,
          ),
          title: Text(pool.poolName.replaceAll('_', ' ')),
          subtitle: Text(
            'Pool #${pool.poolId} · $lastSynced',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标签数量徽章
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${pool.tagCount} ${l10n.cache_tags}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 刷新按钮
              IconButton(
                onPressed: isRefreshing
                    ? null
                    : () => _refreshPool(pool.poolId, pool.poolName),
                icon: isRefreshing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 20),
                tooltip: l10n.cache_refresh,
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatLastSynced(DateTime lastSynced) {
    final now = DateTime.now();
    final diff = now.difference(lastSynced);

    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes} 分钟前';
    } else if (diff.inDays < 1) {
      return '${diff.inHours} 小时前';
    } else if (diff.inDays < 30) {
      return '${diff.inDays} 天前';
    } else {
      return '${lastSynced.month}/${lastSynced.day}';
    }
  }
}
