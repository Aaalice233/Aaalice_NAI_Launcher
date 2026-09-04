import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../providers/tag_library_page_provider.dart';
import '../../../providers/tag_library_selection_provider.dart';
import '../../../widgets/autocomplete/autocomplete_config.dart';
import '../../../widgets/autocomplete/autocomplete_wrapper.dart';
import '../../../widgets/bulk_action_bar.dart';
import '../../../widgets/gallery/gallery_library_toolbar.dart';
import '../../../widgets/gallery/gallery_sidebar.dart';

/// 词库工具栏（搜索、视图切换、批量操作）
class TagLibraryToolbar extends ConsumerStatefulWidget {
  const TagLibraryToolbar({
    super.key,
    this.onShowCategories,
    this.onEnterSelectionMode,
    this.onBulkDelete,
    this.onBulkMoveCategory,
    this.onBulkToggleFavorite,
    this.onBulkCopy,
    this.onImport,
    this.onExport,
    this.onAddEntry,
    this.onOpenCategories,
    this.showPageTitle = true,
  });

  final VoidCallback? onShowCategories;
  final VoidCallback? onEnterSelectionMode;
  final VoidCallback? onBulkDelete;
  final VoidCallback? onBulkMoveCategory;
  final VoidCallback? onBulkToggleFavorite;
  final VoidCallback? onBulkCopy;
  final VoidCallback? onImport;
  final VoidCallback? onExport;
  final VoidCallback? onAddEntry;
  final VoidCallback? onOpenCategories;
  final bool showPageTitle;

  @override
  ConsumerState<TagLibraryToolbar> createState() => _TagLibraryToolbarState();
}

class _TagLibraryToolbarState extends ConsumerState<TagLibraryToolbar> {
  final TextEditingController _searchController = TextEditingController();
  late final FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _searchFocusNode = FocusNode(onKeyEvent: _handleSearchKeyEvent);
    _syncSearchController(ref.read(tagLibraryPageNotifierProvider).searchQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(
      tagLibraryPageNotifierProvider.select((state) => state.searchQuery),
      (_, next) => _syncSearchController(next),
    );
    final state = ref.watch(tagLibraryPageNotifierProvider);
    final selection = ref.watch(tagLibrarySelectionNotifierProvider);
    final theme = Theme.of(context);
    final allEntryIds = state.filteredEntries.map((entry) => entry.id).toList();
    final isAllSelected =
        allEntryIds.isNotEmpty &&
        allEntryIds.every(selection.selectedIds.contains);

    if (selection.isActive) {
      return BulkActionBar(
        selectedCount: selection.selectedIds.length,
        isAllSelected: isAllSelected,
        onExit: () =>
            ref.read(tagLibrarySelectionNotifierProvider.notifier).exit(),
        onSelectAll: () {
          final notifier = ref.read(
            tagLibrarySelectionNotifierProvider.notifier,
          );
          isAllSelected
              ? notifier.clearSelection()
              : notifier.selectAll(allEntryIds);
        },
        actions: [
          BulkActionItem(
            icon: Icons.drive_file_move_outline,
            label: context.l10n.tagLibrary_transferCategory,
            onPressed: widget.onBulkMoveCategory,
            color: theme.colorScheme.secondary,
          ),
          BulkActionItem(
            icon: Icons.copy,
            label: context.l10n.tagLibrary_copyContent,
            onPressed: widget.onBulkCopy,
            color: theme.colorScheme.tertiary,
          ),
          BulkActionItem(
            icon: Icons.favorite_outline,
            label: context.l10n.common_favorite,
            onPressed: widget.onBulkToggleFavorite,
            color: Colors.pink,
          ),
          BulkActionItem(
            icon: Icons.delete_outline,
            label: context.l10n.common_delete,
            onPressed: widget.onBulkDelete,
            color: theme.colorScheme.error,
            isDanger: true,
            showDividerBefore: true,
          ),
        ],
      );
    }

    final openCategories = widget.onShowCategories ?? widget.onOpenCategories;
    final filtered = state.filteredEntries.length != state.entries.length;
    return GalleryLibraryToolbar(
      key: const Key('tag-library-toolbar'),
      title: widget.showPageTitle
          ? GalleryCollectionPageTitle(
              icon: Icons.bookmarks_outlined,
              title: context.l10n.nav_dictionary,
            )
          : const SizedBox.shrink(),
      count: GalleryLibraryCountBadge(
        label: filtered
            ? '${state.filteredEntries.length}/${state.entries.length}'
            : '${state.entries.length}',
      ),
      search: _buildSearchField(),
      actions: [
        GalleryLibrarySortMenu<TagLibrarySortBy>(
          key: const Key('tag-library-sort-menu-anchor'),
          label: _sortLabel(state.sortBy),
          value: state.sortBy,
          options: [
            GalleryLibrarySortOption(
              value: TagLibrarySortBy.order,
              label: context.l10n.tagLibrary_sortCustom,
            ),
            GalleryLibrarySortOption(
              value: TagLibrarySortBy.name,
              label: context.l10n.tagLibrary_sortName,
            ),
            GalleryLibrarySortOption(
              value: TagLibrarySortBy.useCount,
              label: context.l10n.tagLibrary_sortUseCount,
            ),
            GalleryLibrarySortOption(
              value: TagLibrarySortBy.updatedAt,
              label: context.l10n.tagLibrary_sortUpdatedAt,
            ),
          ],
          onSelected: (value) => ref
              .read(tagLibraryPageNotifierProvider.notifier)
              .setSortBy(value),
        ),
        GalleryLibraryViewModeSelector<TagLibraryViewMode>(
          value: state.viewMode,
          options: [
            GalleryLibraryViewModeOption(
              value: TagLibraryViewMode.list,
              icon: Icons.view_list_rounded,
              label: context.l10n.common_list,
            ),
            GalleryLibraryViewModeOption(
              value: TagLibraryViewMode.card,
              icon: Icons.grid_view_rounded,
              label: context.l10n.common_grid,
            ),
            GalleryLibraryViewModeOption(
              value: TagLibraryViewMode.grouped,
              icon: Icons.folder_copy_outlined,
              label: context.l10n.common_grouped,
            ),
          ],
          onSelected: (value) => ref
              .read(tagLibraryPageNotifierProvider.notifier)
              .setViewMode(value),
        ),
        if (openCategories != null)
          GalleryLibraryAction(
            key: const Key('tag-library-categories-button'),
            icon: Icons.account_tree_outlined,
            label: context.l10n.common_categories,
            onPressed: openCategories,
          ),
        GalleryLibraryAction(
          icon: Icons.checklist,
          label: context.l10n.common_multiSelect,
          onPressed: widget.onEnterSelectionMode,
        ),
        GalleryLibraryAction(
          icon: Icons.file_upload_outlined,
          label: context.l10n.common_import,
          onPressed: widget.onImport,
        ),
        GalleryLibraryAction(
          icon: Icons.file_download_outlined,
          label: context.l10n.common_export,
          onPressed: state.entries.isEmpty ? null : widget.onExport,
        ),
      ],
      primaryAction: GalleryLibraryPrimaryAction(
        key: const Key('tag-library-add-entry-button'),
        icon: Icons.add,
        label: context.l10n.tagLibrary_addEntry,
        onPressed: widget.onAddEntry,
      ),
    );
  }

  String _sortLabel(TagLibrarySortBy sortBy) => switch (sortBy) {
    TagLibrarySortBy.order => context.l10n.tagLibrary_sortCustom,
    TagLibrarySortBy.name => context.l10n.tagLibrary_sortName,
    TagLibrarySortBy.useCount => context.l10n.tagLibrary_sortUseCount,
    TagLibrarySortBy.updatedAt => context.l10n.tagLibrary_sortUpdatedAt,
  };

  Widget _buildSearchField() {
    void updateSearch(String value) {
      ref.read(tagLibraryPageNotifierProvider.notifier).setSearchQuery(value);
    }

    return AutocompleteWrapper(
      controller: _searchController,
      focusNode: _searchFocusNode,
      config: const AutocompleteConfig(
        autoInsertComma: false,
        treatSpacesAsSeparators: true,
      ),
      onSuggestionSelected: updateSearch,
      child: GalleryLibrarySearchField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        hintText: context.l10n.tagLibrary_searchHint,
        onChanged: updateSearch,
      ),
    );
  }

  void _syncSearchController(String query) {
    if (_searchController.text == query) return;
    _searchController.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
  }

  KeyEventResult _handleSearchKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.keyA) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    if (!keyboard.isControlPressed && !keyboard.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    _searchController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _searchController.text.length,
    );
    return KeyEventResult.handled;
  }
}
