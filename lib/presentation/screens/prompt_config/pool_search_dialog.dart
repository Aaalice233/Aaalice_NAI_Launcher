import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/danbooru/danbooru_pool.dart';
import '../../../data/models/prompt/tag_category.dart';
import '../../providers/pool_mapping_provider.dart';
import '../../widgets/common/app_toast.dart';

/// Pool 搜索选择对话框
class PoolSearchDialog extends ConsumerStatefulWidget {
  const PoolSearchDialog({super.key});

  @override
  ConsumerState<PoolSearchDialog> createState() => _PoolSearchDialogState();
}

class _PoolSearchDialogState extends ConsumerState<PoolSearchDialog> {
  final _searchController = TextEditingController();
  List<DanbooruPool> _searchResults = [];
  bool _isSearching = false;
  DanbooruPool? _selectedPool;
  TagSubCategory _selectedCategory = TagSubCategory.clothing;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    try {
      final results = await ref
          .read(poolMappingNotifierProvider.notifier)
          .searchPools(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      if (mounted) {
        AppToast.error(context, e.toString());
      }
    }
  }

  void _onAddPressed() async {
    if (_selectedPool == null) return;

    final state = ref.read(poolMappingNotifierProvider);
    if (state.config.hasPool(_selectedPool!.id)) {
      AppToast.warning(context, context.l10n.poolMapping_poolExists);
      return;
    }

    try {
      await ref.read(poolMappingNotifierProvider.notifier).addMapping(
            poolId: _selectedPool!.id,
            poolName: _selectedPool!.name,
            postCount: _selectedPool!.postCount,
            targetCategory: _selectedCategory,
          );
      if (mounted) {
        AppToast.success(context, context.l10n.poolMapping_addSuccess);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(context.l10n.poolMapping_addMapping),
      content: SizedBox(
        width: 450,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 搜索栏
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: context.l10n.poolMapping_searchHint,
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isSearching ? null : _search,
                  child: _isSearching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(context.l10n.common_search),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 搜索结果
            Text(
              context.l10n.poolMapping_selectPool,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _buildSearchResults(theme),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // 目标分类
            Text(
              context.l10n.poolMapping_targetCategory,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<TagSubCategory>(
              value: _selectedCategory,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              items: TagSubCategory.values
                  .where((c) => c != TagSubCategory.other)
                  .map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(TagSubCategoryHelper.getDisplayName(category)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedCategory = value);
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.common_cancel),
        ),
        FilledButton(
          onPressed: _selectedPool == null ? null : _onAddPressed,
          child: Text(context.l10n.poolMapping_addMapping),
        ),
      ],
    );
  }

  Widget _buildSearchResults(ThemeData theme) {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      if (_searchController.text.isNotEmpty) {
        return Center(
          child: Text(
            context.l10n.poolMapping_noResults,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        );
      }
      return Center(
        child: Text(
          context.l10n.poolMapping_searchHint,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final pool = _searchResults[index];
        final isSelected = _selectedPool?.id == pool.id;
        final state = ref.watch(poolMappingNotifierProvider);
        final alreadyAdded = state.config.hasPool(pool.id);

        return Card(
          margin: const EdgeInsets.only(bottom: 4),
          elevation: 0,
          color: isSelected
              ? theme.colorScheme.primaryContainer.withOpacity(0.5)
              : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: isSelected
                ? BorderSide(color: theme.colorScheme.primary, width: 2)
                : BorderSide.none,
          ),
          child: InkWell(
            onTap: alreadyAdded
                ? null
                : () => setState(() => _selectedPool = pool),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Radio<int>(
                    value: pool.id,
                    groupValue: _selectedPool?.id,
                    onChanged: alreadyAdded
                        ? null
                        : (value) => setState(() => _selectedPool = pool),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Opacity(
                      opacity: alreadyAdded ? 0.5 : 1.0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  pool.displayName,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (alreadyAdded)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.outline
                                        .withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    context.l10n.poolMapping_alreadyAdded,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.outline,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${context.l10n.poolMapping_postCount(pool.postCount.toString())} · ${pool.categoryDisplayName}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
