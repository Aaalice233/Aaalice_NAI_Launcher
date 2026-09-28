import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/gallery/image_collection.dart';
import '../adaptive/adaptive_presenter.dart';
import '../providers/collection_provider.dart';
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
  final ScrollController? scrollController;

  const CollectionSelectDialog({
    super.key,
    required this.theme,
    this.scrollController,
  });

  /// 显示集合选择面板。
  ///
  /// 返回选中的集合ID，如果取消则返回null。
  static Future<CollectionSelectResult?> show(
    BuildContext context, {
    required ThemeData theme,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final effectiveTextScale = mediaQuery.textScaler.scale(16) / 16;
    final availableHeight =
        mediaQuery.size.height -
        mediaQuery.padding.vertical -
        mediaQuery.viewInsets.vertical;
    final needsTallPanel = effectiveTextScale > 1.5 || availableHeight < 500;

    return AdaptivePresenter.showPanel<CollectionSelectResult>(
      context: context,
      title: context.l10n.collectionSelect_dialogTitle,
      initialChildSize: needsTallPanel ? 0.93 : 0.72,
      minChildSize: needsTallPanel ? 0.72 : 0.46,
      maxChildSize: 0.94,
      dialogWidth: 450,
      builder: (panelContext, scrollController) => CollectionSelectDialog(
        theme: theme,
        scrollController: scrollController,
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
    final collectionState = ref.watch(collectionNotifierProvider);

    return CustomScrollView(
      key: const Key('collection-select-scroll'),
      controller: widget.scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          sliver: SliverToBoxAdapter(
            child: ThemedInput(
              controller: _filterController,
              decoration: InputDecoration(
                hintText: l10n.collectionSelect_filterHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _filterQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _filterController.clear,
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ),
        ..._buildCollectionSlivers(
          theme,
          l10n,
          collectionState.collections,
          collectionState.isLoading,
        ),
        SliverSafeArea(
          top: false,
          sliver: SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            sliver: SliverToBoxAdapter(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.common_cancel),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildCollectionSlivers(
    ThemeData theme,
    AppLocalizations l10n,
    List<ImageCollection> collections,
    bool isLoading,
  ) {
    if (isLoading) {
      return [
        SliverToBoxAdapter(
          child: SizedBox(
            height: 120,
            child: Center(
              child: CircularProgressIndicator(
                value: MediaQuery.disableAnimationsOf(context) ? 0.75 : null,
              ),
            ),
          ),
        ),
      ];
    }

    final filteredCollections = _getFilteredCollections(collections);

    if (collections.isEmpty) {
      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          sliver: SliverToBoxAdapter(
            child: Column(
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
          ),
        ),
      ];
    }

    if (filteredCollections.isEmpty) {
      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          sliver: SliverToBoxAdapter(
            child: Column(
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
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ];
    }

    return [
      SliverList.builder(
        itemCount: filteredCollections.length,
        itemBuilder: (context, index) =>
            _buildCollectionTile(theme, l10n, filteredCollections[index]),
      ),
    ];
  }

  /// 构建集合列表项
  Widget _buildCollectionTile(
    ThemeData theme,
    AppLocalizations l10n,
    ImageCollection collection,
  ) {
    return ListTile(
      leading: Icon(Icons.folder_outlined, color: theme.colorScheme.primary),
      title: Text(
        collection.name,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
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
