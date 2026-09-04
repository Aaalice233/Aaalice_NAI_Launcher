import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../data/models/tag_library/tag_library_category.dart';
import '../../../../data/models/tag_library/tag_library_entry.dart';
import '../../../adaptive/adaptive_presenter.dart';
import '../../../widgets/autocomplete/autocomplete_config.dart';
import '../../../widgets/autocomplete/autocomplete_wrapper.dart';
import '../../../widgets/common/thumbnail_display.dart';

/// 条目选择对话框
///
/// 用于选择要更新预览图的词条
class EntrySelectorDialog extends ConsumerStatefulWidget {
  /// 所有条目
  final List<TagLibraryEntry> entries;

  /// 所有分类（用于显示分类名称）
  final List<TagLibraryCategory> categories;

  /// 共享自适应容器提供的滚动控制器
  final ScrollController? scrollController;

  const EntrySelectorDialog({
    super.key,
    required this.entries,
    required this.categories,
    this.scrollController,
  });

  /// 显示自适应选择面；取消或系统返回时返回 null。
  static Future<TagLibraryEntry?> show(
    BuildContext context, {
    required List<TagLibraryEntry> entries,
    required List<TagLibraryCategory> categories,
  }) {
    return AdaptivePresenter.showForm<TagLibraryEntry>(
      context: context,
      titleBuilder: (panelContext) => Row(
        children: [
          Icon(
            Icons.image_search_outlined,
            color: Theme.of(panelContext).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              panelContext.l10n.tagLibrary_selectEntryToUpdate,
              style: Theme.of(panelContext).textTheme.titleLarge,
            ),
          ),
        ],
      ),
      width: 500,
      builder: (panelContext, scrollController) => EntrySelectorDialog(
        entries: entries,
        categories: categories,
        scrollController: scrollController,
      ),
    );
  }

  @override
  ConsumerState<EntrySelectorDialog> createState() =>
      _EntrySelectorDialogState();
}

class _EntrySelectorDialogState extends ConsumerState<EntrySelectorDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  String? _selectedEntryId;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _updateSearch(String value) {
    setState(() => _searchQuery = value);
  }

  List<TagLibraryEntry> get _filteredEntries {
    if (_searchQuery.isEmpty) return widget.entries;

    final query = _searchQuery.toLowerCase();
    return widget.entries.where((entry) {
      return entry.name.toLowerCase().contains(query) ||
          entry.content.toLowerCase().contains(query) ||
          entry.tags.any((tag) => tag.toLowerCase().contains(query));
    }).toList();
  }

  String _getCategoryName(BuildContext context, String? categoryId) {
    if (categoryId == null) return context.l10n.tagLibrary_rootCategory;
    final category = widget.categories.cast<TagLibraryCategory?>().firstWhere(
      (c) => c?.id == categoryId,
      orElse: () => null,
    );
    return category?.displayName ?? context.l10n.tagLibrary_unknownCategory;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final filteredEntries = _filteredEntries;

    return RadioGroup<String>(
      groupValue: _selectedEntryId,
      onChanged: (value) {
        if (value != null) setState(() => _selectedEntryId = value);
      },
      child: CustomScrollView(
        key: const Key('entry-selector-scroll'),
        controller: widget.scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            sliver: SliverToBoxAdapter(
              child: AutocompleteWrapper(
                controller: _searchController,
                focusNode: _searchFocusNode,
                config: const AutocompleteConfig(
                  autoInsertComma: false,
                  treatSpacesAsSeparators: true,
                ),
                onSuggestionSelected: _updateSearch,
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  autofocus: true,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    hintText: l10n.tagLibrary_searchHint,
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onChanged: _updateSearch,
                ),
              ),
            ),
          ),
          if (filteredEntries.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(theme),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              sliver: SliverList.builder(
                itemCount: filteredEntries.length,
                itemBuilder: (context, index) {
                  final entry = filteredEntries[index];
                  return _EntryListTile(
                    entry: entry,
                    categoryName: _getCategoryName(context, entry.categoryId),
                    isSelected: _selectedEntryId == entry.id,
                    onTap: () => setState(() => _selectedEntryId = entry.id),
                  );
                },
              ),
            ),
          SliverSafeArea(
            top: false,
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              sliver: SliverToBoxAdapter(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.common_cancel),
                    ),
                    FilledButton.icon(
                      onPressed: _selectedEntryId == null
                          ? null
                          : () {
                              final selectedEntry = widget.entries.firstWhere(
                                (entry) => entry.id == _selectedEntryId,
                              );
                              Navigator.of(context).pop(selectedEntry);
                            },
                      icon: const Icon(Icons.update, size: 18),
                      label: Text(l10n.tagLibrary_updatePreview),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 48,
              color: theme.colorScheme.outline.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.tagLibrary_noSearchResults,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// 条目列表项
class _EntryListTile extends StatelessWidget {
  final TagLibraryEntry entry;
  final String categoryName;
  final bool isSelected;
  final VoidCallback onTap;

  const _EntryListTile({
    required this.entry,
    required this.categoryName,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: isSelected
          ? theme.colorScheme.primaryContainer
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // 选择指示器
              Radio<String>(
                value: entry.id,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),

              const SizedBox(width: 8),

              // 预览图
              _buildThumbnail(theme),

              const SizedBox(width: 12),

              // 信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.displayName,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.folder_outlined,
                          size: 12,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            categoryName,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 是否有预览图标记
              if (entry.thumbnail != null)
                Tooltip(
                  message: context.l10n.tagLibrary_replaceThumbnailHint,
                  child: Icon(
                    Icons.image_outlined,
                    size: 16,
                    color: theme.colorScheme.outline,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(ThemeData theme) {
    final hasThumbnail = entry.thumbnail != null;

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: hasThumbnail
          ? ThumbnailDisplay(
              imagePath: entry.thumbnail!,
              offsetX: entry.thumbnailOffsetX,
              offsetY: entry.thumbnailOffsetY,
              scale: entry.thumbnailScale,
              width: 48,
              height: 48,
              borderRadius: BorderRadius.circular(6),
            )
          : Icon(
              Icons.image_not_supported_outlined,
              size: 24,
              color: theme.colorScheme.outline,
            ),
    );
  }
}
