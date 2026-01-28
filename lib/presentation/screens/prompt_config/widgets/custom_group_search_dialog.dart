import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/datasources/local/pool_cache_service.dart';
import '../../../../data/datasources/local/tag_group_cache_service.dart';
import '../../../../data/datasources/remote/danbooru_pool_service.dart';
import '../../../../data/datasources/remote/danbooru_tag_group_service.dart';
import '../../../../data/models/danbooru/danbooru_pool.dart';
import '../../../../data/models/prompt/tag_group.dart';
import '../../../widgets/common/emoji_picker_dialog.dart';
import '../../../widgets/common/themed_divider.dart';

import '../../../widgets/common/app_toast.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';
/// 自定义词组搜索结果类型
enum CustomGroupType {
  tagGroup,
  pool,
}

/// 自定义词组搜索结果
class CustomGroupResult {
  final CustomGroupType type;
  final String name;
  final String emoji;

  // TagGroup 相关
  final String? groupTitle;

  // Pool 相关
  final int? poolId;
  final int? postCount;

  const CustomGroupResult({
    required this.type,
    required this.name,
    required this.emoji,
    this.groupTitle,
    this.poolId,
    this.postCount,
  });
}

/// 自定义词组搜索对话框
///
/// 用于连接 Danbooru 搜索 TagGroup 或 Pool，并设置 emoji 和名称
class CustomGroupSearchDialog extends ConsumerStatefulWidget {
  /// 固定的搜索类型，如果指定则不显示类型切换器
  final CustomGroupType? fixedType;

  const CustomGroupSearchDialog({
    super.key,
    this.fixedType,
  });

  /// 显示对话框
  ///
  /// [fixedType] 如果指定，则锁定为该类型，不显示类型切换器
  static Future<CustomGroupResult?> show(
    BuildContext context, {
    CustomGroupType? fixedType,
  }) {
    return showDialog<CustomGroupResult>(
      context: context,
      builder: (context) => CustomGroupSearchDialog(fixedType: fixedType),
    );
  }

  @override
  ConsumerState<CustomGroupSearchDialog> createState() =>
      _CustomGroupSearchDialogState();
}

class _CustomGroupSearchDialogState
    extends ConsumerState<CustomGroupSearchDialog> {
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();

  late String _selectedEmoji;
  late CustomGroupType _searchType;

  @override
  void initState() {
    super.initState();
    // 使用固定类型或默认为 tagGroup
    _searchType = widget.fixedType ?? CustomGroupType.tagGroup;
    _selectedEmoji = _searchType == CustomGroupType.pool ? '🖼️' : '✨';
  }

  List<TagGroup> _tagGroupResults = [];
  List<DanbooruPool> _poolResults = [];
  bool _isSearching = false;
  String? _searchError;

  // 选中的项
  TagGroup? _selectedTagGroup;
  DanbooruPool? _selectedPool;

  // 拉取缓存状态
  bool _isFetching = false;

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchError = null;
      _tagGroupResults = [];
      _poolResults = [];
      _selectedTagGroup = null;
      _selectedPool = null;
    });

    try {
      if (_searchType == CustomGroupType.tagGroup) {
        final service = ref.read(danbooruTagGroupServiceProvider);
        final results = await service.searchTagGroups(query: query);
        if (mounted) {
          setState(() {
            _tagGroupResults = results;
            _isSearching = false;
          });
        }
      } else {
        final service = ref.read(danbooruPoolServiceProvider);
        final results = await service.searchPools(query);
        if (mounted) {
          setState(() {
            _poolResults = results;
            _isSearching = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchError = e.toString();
          _isSearching = false;
        });
      }
    }
  }

  void _selectTagGroup(TagGroup group) {
    setState(() {
      _selectedTagGroup = group;
      _selectedPool = null;
      _nameController.text = TagGroup.titleToDisplayName(group.title, context);
    });
  }

  void _selectPool(DanbooruPool pool) {
    setState(() {
      _selectedPool = pool;
      _selectedTagGroup = null;
      _nameController.text = pool.name.replaceAll('_', ' ');
      _selectedEmoji = '🖼️';
    });
  }

  Future<void> _selectEmoji() async {
    final emoji = await EmojiPickerDialog.show(
      context,
      initialEmoji: _selectedEmoji,
    );
    if (emoji != null && mounted) {
      setState(() => _selectedEmoji = emoji);
    }
  }

  Future<void> _submit() async {
    if (_selectedTagGroup == null && _selectedPool == null) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isFetching = true);

    try {
      if (_selectedTagGroup != null) {
        // 拉取 TagGroup 数据并缓存
        final cacheService = ref.read(tagGroupCacheServiceProvider);
        final service = ref.read(danbooruTagGroupServiceProvider);

        final details =
            await service.syncTagGroup(groupTitle: _selectedTagGroup!.title);
        if (details != null) {
          await cacheService.saveTagGroup(_selectedTagGroup!.title, details);
        }

        if (mounted) {
          Navigator.of(context).pop(
            CustomGroupResult(
              type: CustomGroupType.tagGroup,
              name: name,
              emoji: _selectedEmoji,
              groupTitle: _selectedTagGroup!.title,
            ),
          );
        }
      } else if (_selectedPool != null) {
        // 拉取 Pool 数据并缓存
        final poolCacheService = ref.read(poolCacheServiceProvider);
        final poolService = ref.read(danbooruPoolServiceProvider);

        final posts = await poolService.syncAllPoolPosts(
          poolId: _selectedPool!.id,
          poolName: _selectedPool!.name,
        );

        await poolCacheService.savePoolPosts(
          _selectedPool!.id,
          _selectedPool!.name,
          posts,
          _selectedPool!.postCount,
        );

        if (mounted) {
          Navigator.of(context).pop(
            CustomGroupResult(
              type: CustomGroupType.pool,
              name: name,
              emoji: _selectedEmoji,
              poolId: _selectedPool!.id,
              postCount: posts.length,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFetching = false);
        AppToast.error(context, context.l10n.addGroup_fetchFailed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Stack(
      children: [
        AlertDialog(
          title: Text(l10n.customGroup_title),
          content: SizedBox(
            width: 500,
            height: 500,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 搜索类型选择（仅在未固定类型时显示）
                if (widget.fixedType == null) ...[
                  SegmentedButton<CustomGroupType>(
                    segments: [
                      ButtonSegment(
                        value: CustomGroupType.tagGroup,
                        label: Text(l10n.addGroup_tagGroupTab),
                        icon: const Icon(Icons.cloud_outlined, size: 18),
                      ),
                      ButtonSegment(
                        value: CustomGroupType.pool,
                        label: Text(l10n.addGroup_poolTab),
                        icon: const Icon(Icons.collections_outlined, size: 18),
                      ),
                    ],
                    selected: {_searchType},
                    onSelectionChanged: (value) {
                      setState(() {
                        _searchType = value.first;
                        _tagGroupResults = [];
                        _poolResults = [];
                        _selectedTagGroup = null;
                        _selectedPool = null;
                        _selectedEmoji =
                            _searchType == CustomGroupType.pool ? '🖼️' : '✨';
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // 搜索框
                ThemedInput(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: l10n.customGroup_searchHint,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _isSearching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.arrow_forward),
                            onPressed: _search,
                          ),
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _search(),
                ),
                const SizedBox(height: 12),

                // 搜索结果列表
                Expanded(
                  child: _buildSearchResults(theme),
                ),

                // 选中项设置区域
                if (_selectedTagGroup != null || _selectedPool != null) ...[
                  const ThemedDivider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Emoji 选择
                      InkWell(
                        onTap: _selectEmoji,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.outline.withOpacity(0.3),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _selectedEmoji,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 名称输入
                      Expanded(
                        child: ThemedInput(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: l10n.customGroup_nameLabel,
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.common_cancel),
            ),
            FilledButton(
              onPressed: (_selectedTagGroup != null || _selectedPool != null) &&
                      _nameController.text.trim().isNotEmpty
                  ? _submit
                  : null,
              child: Text(l10n.customGroup_add),
            ),
          ],
        ),
        // 拉取数据覆盖层
        if (_isFetching)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(l10n.addGroup_fetchingCache),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchResults(ThemeData theme) {
    final l10n = context.l10n;

    if (_searchError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 8),
            Text(
              _searchError!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
        ),
      );
    }

    if (_searchType == CustomGroupType.tagGroup) {
      if (_tagGroupResults.isEmpty) {
        return Center(
          child: Text(
            l10n.customGroup_searchPrompt,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        );
      }

      return ListView.builder(
        itemCount: _tagGroupResults.length,
        itemBuilder: (context, index) {
          final group = _tagGroupResults[index];
          final isSelected = _selectedTagGroup?.title == group.title;
          return ListTile(
            leading: const Text('☁️', style: TextStyle(fontSize: 20)),
            title: Text(TagGroup.titleToDisplayName(group.title, context)),
            subtitle: Text(
              '${group.tagCount} tags',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            trailing: IconButton(
              icon: Icon(
                Icons.open_in_new,
                size: 18,
                color: theme.colorScheme.outline,
              ),
              tooltip: l10n.common_openInBrowser,
              onPressed: () {
                final url = Uri.parse(
                  'https://danbooru.donmai.us/wiki_pages/${group.title}',
                );
                launchUrl(url, mode: LaunchMode.externalApplication);
              },
            ),
            selected: isSelected,
            selectedTileColor:
                theme.colorScheme.primaryContainer.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            onTap: () => _selectTagGroup(group),
          );
        },
      );
    } else {
      if (_poolResults.isEmpty) {
        return Center(
          child: Text(
            l10n.customGroup_searchPrompt,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        );
      }

      return ListView.builder(
        itemCount: _poolResults.length,
        itemBuilder: (context, index) {
          final pool = _poolResults[index];
          final isSelected = _selectedPool?.id == pool.id;
          return ListTile(
            leading: const Text('🖼️', style: TextStyle(fontSize: 20)),
            title: Text(pool.name.replaceAll('_', ' ')),
            subtitle: Text(
              '${pool.postCount} posts',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            trailing: IconButton(
              icon: Icon(
                Icons.open_in_new,
                size: 18,
                color: theme.colorScheme.outline,
              ),
              tooltip: l10n.common_openInBrowser,
              onPressed: () {
                final url = Uri.parse(
                  'https://danbooru.donmai.us/pools/${pool.id}',
                );
                launchUrl(url, mode: LaunchMode.externalApplication);
              },
            ),
            selected: isSelected,
            selectedTileColor:
                theme.colorScheme.primaryContainer.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            onTap: () => _selectPool(pool),
          );
        },
      );
    }
  }
}
