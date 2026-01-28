import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/localization_extension.dart';
import '../../data/models/gallery/image_collection.dart';
import '../providers/collection_provider.dart';
import 'common/inset_shadow_container.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';

/// 集合选择结果
class CollectionSelectResult {
  final String collectionId;
  final String collectionName;

  const CollectionSelectResult({
    required this.collectionId,
    required this.collectionName,
  });
}

/// 集合选择对话框
///
/// 用于选择一个集合以添加图片
class CollectionSelectDialog extends ConsumerStatefulWidget {
  final ThemeData theme;

  const CollectionSelectDialog({
    super.key,
    required this.theme,
  });

  /// 显示集合选择对话框
  ///
  /// 返回选中的集合ID，如果取消则返回null
  static Future<CollectionSelectResult?> show(
    BuildContext context, {
    required ThemeData theme,
  }) {
    return showDialog<CollectionSelectResult>(
      context: context,
      builder: (context) => CollectionSelectDialog(
        theme: theme,
      ),
    );
  }

  @override
  ConsumerState<CollectionSelectDialog> createState() =>
      _CollectionSelectDialogState();
}

class _CollectionSelectDialogState
    extends ConsumerState<CollectionSelectDialog> {
  // 搜索过滤控制器
  final _filterController = TextEditingController();
  String _filterQuery = '';

  @override
  void initState() {
    super.initState();
    // 初始化加载集合
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(collectionNotifierProvider.notifier).initialize();
    });
    _filterController.addListener(_onFilterChanged);
  }

  void _onFilterChanged() {
    setState(() {
      _filterQuery = _filterController.text.trim().toLowerCase();
    });
  }

  @override
  void dispose() {
    _filterController.removeListener(_onFilterChanged);
    _filterController.dispose();
    super.dispose();
  }

  void _selectCollection(ImageCollection collection) {
    Navigator.of(context).pop(
      CollectionSelectResult(
        collectionId: collection.id,
        collectionName: collection.name,
      ),
    );
  }

  /// 获取过滤后的集合列表
  List<ImageCollection> _getFilteredCollections(
    List<ImageCollection> collections,
  ) {
    if (_filterQuery.isEmpty) {
      return collections;
    }
    return collections.where((collection) {
      final nameMatch = collection.name.toLowerCase().contains(_filterQuery);
      final descMatch =
          collection.description?.toLowerCase().contains(_filterQuery) ?? false;
      return nameMatch || descMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final l10n = context.l10n;

    // 监听集合状态
    final collectionState = ref.watch(collectionNotifierProvider);
    final collections = collectionState.collections;
    final isLoading = collectionState.isLoading;

    return AlertDialog(
      title: Text(l10n.collectionSelect_dialogTitle),
      content: SizedBox(
        width: 450,
        height: 500,
        child: Column(
          children: [
            // 搜索框
            InsetShadowContainer(
              borderRadius: 8,
              child: ThemedInput(
                controller: _filterController,
                decoration: InputDecoration(
                  hintText: l10n.collectionSelect_filterHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _filterQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _filterController.clear();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // 集合列表
            Expanded(
              child: _buildCollectionList(theme, l10n, collections, isLoading),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_cancel),
        ),
      ],
    );
  }

  /// 构建集合列表
  Widget _buildCollectionList(
    ThemeData theme,
    AppLocalizations l10n,
    List<ImageCollection> collections,
    bool isLoading,
  ) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredCollections = _getFilteredCollections(collections);

    if (collections.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.collectionSelect_noCollections,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.collectionSelect_createCollectionHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (filteredCollections.isEmpty) {
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
              l10n.collectionSelect_noFilterResults,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredCollections.length,
      itemBuilder: (context, index) {
        final collection = filteredCollections[index];
        return _buildCollectionTile(theme, l10n, collection);
      },
    );
  }

  /// 构建集合列表项
  Widget _buildCollectionTile(
    ThemeData theme,
    AppLocalizations l10n,
    ImageCollection collection,
  ) {
    return ListTile(
      leading: Icon(
        Icons.folder_outlined,
        color: theme.colorScheme.primary,
      ),
      title: Text(
        collection.name,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (collection.description != null)
            Text(
              collection.description!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          Text(
            l10n.collectionSelect_imageCount(collection.imageCount),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
      trailing: Icon(
        Icons.add_circle_outline,
        color: theme.colorScheme.primary,
      ),
      onTap: () => _selectCollection(collection),
    );
  }
}
