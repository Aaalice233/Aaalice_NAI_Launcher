import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/datasources/local/pool_cache_service.dart';
import '../../../../data/datasources/local/tag_group_cache_service.dart';
import '../../../../data/models/prompt/default_categories.dart';
import '../../../../data/models/prompt/tag_category.dart';
import '../../../../data/models/prompt/tag_group.dart';
import 'custom_group_search_dialog.dart';

/// 添加分组类型
enum AddGroupType {
  /// 内置词库
  builtin,

  /// 远程 Tag Group
  tagGroup,

  /// Danbooru Pools
  danbooruPool,
}

/// 添加分组结果
class AddGroupResult {
  final AddGroupType type;
  final String? groupTitle;
  final String? displayName;
  final bool includeChildren;
  final TagSubCategory? targetCategory;
  final String? emoji;

  /// Pool 相关字段
  final int? poolId;
  final String? poolName;
  final int? postCount;

  /// 内置类别相关字段
  final String? builtinCategoryKey;

  const AddGroupResult({
    required this.type,
    this.groupTitle,
    this.displayName,
    this.includeChildren = true,
    this.targetCategory,
    this.emoji,
    this.poolId,
    this.poolName,
    this.postCount,
    this.builtinCategoryKey,
  });

  /// 创建内置词库结果
  factory AddGroupResult.builtin({String? categoryKey}) =>
      AddGroupResult(type: AddGroupType.builtin, builtinCategoryKey: categoryKey);

  /// 创建 Tag Group 结果
  factory AddGroupResult.tagGroup({
    required String groupTitle,
    required String displayName,
    bool includeChildren = true,
    TagSubCategory? targetCategory,
    String? emoji,
  }) =>
      AddGroupResult(
        type: AddGroupType.tagGroup,
        groupTitle: groupTitle,
        displayName: displayName,
        includeChildren: includeChildren,
        targetCategory: targetCategory,
        emoji: emoji,
      );

  /// 创建 Danbooru Pool 结果
  factory AddGroupResult.danbooruPool({
    required int poolId,
    required String poolName,
    required int postCount,
    TagSubCategory? targetCategory,
    String? emoji,
  }) =>
      AddGroupResult(
        type: AddGroupType.danbooruPool,
        poolId: poolId,
        poolName: poolName,
        postCount: postCount,
        targetCategory: targetCategory,
        emoji: emoji,
      );
}

/// 统一的缓存列表项（TagGroup 或 Pool）
class _CachedGroupItem {
  final String displayName;
  final int tagCount;
  final String emoji;
  final bool isPool;

  // TagGroup 相关
  final TagGroup? tagGroup;

  // Pool 相关
  final PoolCacheEntry? poolEntry;

  _CachedGroupItem._({
    required this.displayName,
    required this.tagCount,
    required this.emoji,
    required this.isPool,
    this.tagGroup,
    this.poolEntry,
  });

  factory _CachedGroupItem.fromTagGroup(TagGroup group, BuildContext context) {
    return _CachedGroupItem._(
      displayName: TagGroup.titleToDisplayName(group.title, context),
      tagCount: group.tagCount,
      emoji: '☁️',
      isPool: false,
      tagGroup: group,
    );
  }

  factory _CachedGroupItem.fromPool(PoolCacheEntry pool) {
    return _CachedGroupItem._(
      displayName: pool.poolName.replaceAll('_', ' '),
      tagCount: pool.cachedPostCount,
      emoji: '🖼️',
      isPool: true,
      poolEntry: pool,
    );
  }

  /// 获取唯一标识（用于判断是否已存在）
  String get uniqueKey =>
      isPool ? 'pool:${poolEntry!.poolId}' : tagGroup!.title;
}

/// 内置类别项
class _BuiltinCategoryItem {
  final String key;
  final String name;
  final String emoji;
  final int tagCount;

  const _BuiltinCategoryItem({
    required this.key,
    required this.name,
    required this.emoji,
    required this.tagCount,
  });
}

/// 添加分组对话框（支持内置词库、Tag Group 和 Danbooru Pool）
class AddGroupDialog extends ConsumerStatefulWidget {
  final ThemeData theme;
  final TagSubCategory category;
  final bool isBuiltinEnabled;
  final Set<String> existingGroupTitles;
  final String locale;

  const AddGroupDialog({
    super.key,
    required this.theme,
    required this.category,
    required this.isBuiltinEnabled,
    required this.existingGroupTitles,
    required this.locale,
  });

  /// 显示添加分组对话框
  static Future<AddGroupResult?> show(
    BuildContext context, {
    required ThemeData theme,
    required TagSubCategory category,
    required bool isBuiltinEnabled,
    required Set<String> existingGroupTitles,
    required String locale,
  }) {
    return showDialog<AddGroupResult>(
      context: context,
      builder: (context) => AddGroupDialog(
        theme: theme,
        category: category,
        isBuiltinEnabled: isBuiltinEnabled,
        existingGroupTitles: existingGroupTitles,
        locale: locale,
      ),
    );
  }

  @override
  ConsumerState<AddGroupDialog> createState() => _AddGroupDialogState();
}

class _AddGroupDialogState extends ConsumerState<AddGroupDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 搜索过滤控制器
  final _filterController = TextEditingController();
  String _filterQuery = '';

  // 本地缓存的 Tag Group 列表
  Map<String, TagGroup> _cachedTagGroups = {};
  bool _isLoadingTagGroups = true;

  // 本地缓存的 Pool 列表
  Map<int, PoolCacheEntry> _cachedPools = {};
  bool _isLoadingPools = true;

  // 内置类别列表
  List<_BuiltinCategoryItem> _builtinCategories = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCachedData();
    _loadBuiltinCategories();
    _filterController.addListener(_onFilterChanged);
  }

  void _loadBuiltinCategories() {
    final defaultCategories = DefaultCategories.createDefault();
    _builtinCategories = defaultCategories.map((category) {
      final tagCount = category.groups.isNotEmpty
          ? category.groups.first.tags.length
          : 0;
      return _BuiltinCategoryItem(
        key: category.key,
        name: category.name,
        emoji: category.emoji,
        tagCount: tagCount,
      );
    }).toList();
  }

  void _onFilterChanged() {
    setState(() {
      _filterQuery = _filterController.text.trim().toLowerCase();
    });
  }

  Future<void> _loadCachedData() async {
    await Future.wait([
      _loadCachedTagGroups(),
      _loadCachedPools(),
    ]);
  }

  Future<void> _loadCachedTagGroups() async {
    setState(() => _isLoadingTagGroups = true);
    try {
      final cacheService = ref.read(tagGroupCacheServiceProvider);
      final groups = await cacheService.getAllCachedGroups();
      if (mounted) {
        setState(() {
          _cachedTagGroups = groups;
          _isLoadingTagGroups = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTagGroups = false);
      }
    }
  }

  Future<void> _loadCachedPools() async {
    setState(() => _isLoadingPools = true);
    try {
      final cacheService = ref.read(poolCacheServiceProvider);
      final pools = await cacheService.getAllCachedPools();
      if (mounted) {
        setState(() {
          _cachedPools = pools;
          _isLoadingPools = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPools = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _filterController.removeListener(_onFilterChanged);
    _filterController.dispose();
    super.dispose();
  }

  void _selectBuiltin(String categoryKey) {
    Navigator.of(context).pop(AddGroupResult.builtin(categoryKey: categoryKey));
  }

  void _selectTagGroup(TagGroup group) {
    final displayName = TagGroup.titleToDisplayName(group.title, context);
    Navigator.of(context).pop(
      AddGroupResult.tagGroup(
        groupTitle: group.title,
        displayName: displayName,
        includeChildren: true,
        targetCategory: widget.category,
      ),
    );
  }

  void _selectPool(PoolCacheEntry pool) {
    Navigator.of(context).pop(
      AddGroupResult.danbooruPool(
        poolId: pool.poolId,
        poolName: pool.poolName,
        postCount: pool.cachedPostCount,
        targetCategory: widget.category,
      ),
    );
  }

  Future<void> _openCustomGroupSearch() async {
    final result = await CustomGroupSearchDialog.show(context);
    if (result == null || !mounted) return;

    // 刷新缓存列表
    await _loadCachedData();

    if (!mounted) return;

    // 根据结果类型返回
    if (result.type == CustomGroupType.tagGroup) {
      Navigator.of(context).pop(
        AddGroupResult.tagGroup(
          groupTitle: result.groupTitle!,
          displayName: result.name,
          includeChildren: true,
          targetCategory: widget.category,
          emoji: result.emoji,
        ),
      );
    } else {
      Navigator.of(context).pop(
        AddGroupResult.danbooruPool(
          poolId: result.poolId!,
          poolName: result.name,
          postCount: result.postCount ?? 0,
          targetCategory: widget.category,
          emoji: result.emoji,
        ),
      );
    }
  }

  /// 获取过滤后的内置类别
  List<_BuiltinCategoryItem> _getFilteredBuiltinCategories() {
    if (_filterQuery.isEmpty) {
      return _builtinCategories;
    }
    return _builtinCategories
        .where((item) => item.name.toLowerCase().contains(_filterQuery))
        .toList();
  }

  /// 获取过滤后的 TagGroups
  List<_CachedGroupItem> _getFilteredTagGroups() {
    final items = <_CachedGroupItem>[];
    for (final group in _cachedTagGroups.values) {
      final item = _CachedGroupItem.fromTagGroup(group, context);
      if (_filterQuery.isEmpty ||
          item.displayName.toLowerCase().contains(_filterQuery)) {
        items.add(item);
      }
    }
    items.sort((a, b) => a.displayName.compareTo(b.displayName));
    return items;
  }

  /// 获取过滤后的 Pools
  List<_CachedGroupItem> _getFilteredPools() {
    final items = <_CachedGroupItem>[];
    for (final pool in _cachedPools.values) {
      final item = _CachedGroupItem.fromPool(pool);
      if (_filterQuery.isEmpty ||
          item.displayName.toLowerCase().contains(_filterQuery)) {
        items.add(item);
      }
    }
    items.sort((a, b) => a.displayName.compareTo(b.displayName));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final categoryName = TagSubCategoryHelper.getDisplayName(widget.category);
    final l10n = context.l10n;

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(l10n.addGroup_dialogTitle(categoryName)),
          ),
          FilledButton.icon(
            onPressed: _openCustomGroupSearch,
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.addGroup_addCustom),
          ),
        ],
      ),
      content: SizedBox(
        width: 550,
        height: 520,
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
                      const Icon(Icons.home_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text(l10n.addGroup_builtinTab),
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
                          '${_builtinCategories.length}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text(l10n.addGroup_tagGroupTab),
                      if (_cachedTagGroups.isNotEmpty) ...[
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
                            '${_cachedTagGroups.length}',
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
                      Text(l10n.addGroup_poolTab),
                      if (_cachedPools.isNotEmpty) ...[
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
                            '${_cachedPools.length}',
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
            const SizedBox(height: 12),
            // 搜索框
            TextField(
              controller: _filterController,
              decoration: InputDecoration(
                hintText: l10n.addGroup_filterHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _filterQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _filterController.clear();
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Tab 内容
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBuiltinList(theme),
                  _buildTagGroupList(theme),
                  _buildPoolList(theme),
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

  /// 构建内置词库列表
  Widget _buildBuiltinList(ThemeData theme) {
    final l10n = context.l10n;
    final items = _getFilteredBuiltinCategories();

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.addGroup_noFilterResults,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isExisting = widget.existingGroupTitles.contains('builtin:${item.key}');

        return ListTile(
          leading: Text(
            item.emoji,
            style: const TextStyle(fontSize: 20),
          ),
          title: Text(
            item.name,
            style: TextStyle(
              color: isExisting ? theme.colorScheme.outline : null,
            ),
          ),
          subtitle: Text(
            '${item.tagCount} ${l10n.cache_tags}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          trailing: isExisting
              ? Text(
                  l10n.tagGroup_alreadyAdded,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                )
              : Icon(Icons.add, color: theme.colorScheme.primary),
          enabled: !isExisting,
          onTap: isExisting ? null : () => _selectBuiltin(item.key),
        );
      },
    );
  }

  /// 构建标签词库列表
  Widget _buildTagGroupList(ThemeData theme) {
    final l10n = context.l10n;

    if (_isLoadingTagGroups) {
      return const Center(child: CircularProgressIndicator());
    }

    final items = _getFilteredTagGroups();

    if (items.isEmpty) {
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
              _filterQuery.isNotEmpty
                  ? l10n.addGroup_noFilterResults
                  : l10n.addGroup_noCachedTagGroups,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            if (_filterQuery.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                l10n.addGroup_noCachedTagGroupsHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildItemTile(theme, l10n, item);
      },
    );
  }

  /// 构建图集列表
  Widget _buildPoolList(ThemeData theme) {
    final l10n = context.l10n;

    if (_isLoadingPools) {
      return const Center(child: CircularProgressIndicator());
    }

    final items = _getFilteredPools();

    if (items.isEmpty) {
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
              _filterQuery.isNotEmpty
                  ? l10n.addGroup_noFilterResults
                  : l10n.addGroup_noCachedPools,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            if (_filterQuery.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                l10n.addGroup_noCachedPoolsHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildItemTile(theme, l10n, item);
      },
    );
  }

  /// 构建列表项
  Widget _buildItemTile(
    ThemeData theme,
    dynamic l10n,
    _CachedGroupItem item,
  ) {
    final isExisting = widget.existingGroupTitles.contains(item.uniqueKey);

    return ListTile(
      leading: Text(
        item.emoji,
        style: const TextStyle(fontSize: 20),
      ),
      title: Text(
        item.displayName,
        style: TextStyle(
          color: isExisting ? theme.colorScheme.outline : null,
        ),
      ),
      subtitle: Text(
        item.isPool
            ? '${item.tagCount} ${l10n.cache_posts}'
            : '${item.tagCount} ${l10n.cache_tags}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
      trailing: isExisting
          ? Text(
              l10n.tagGroup_alreadyAdded,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            )
          : Icon(Icons.add, color: theme.colorScheme.primary),
      enabled: !isExisting,
      onTap: isExisting
          ? null
          : () {
              if (item.isPool) {
                _selectPool(item.poolEntry!);
              } else {
                _selectTagGroup(item.tagGroup!);
              }
            },
    );
  }
}
