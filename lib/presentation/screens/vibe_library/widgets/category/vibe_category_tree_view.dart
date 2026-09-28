import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../../data/models/vibe/vibe_library_category.dart';
import '../../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../../widgets/common/library_classification_drag.dart';
import '../../../../providers/vibe_library_provider.dart';
import '../../../../widgets/common/context_menu_anchor.dart';
import '../../../../widgets/gallery/gallery_album_tree_view.dart';
import '../../../../widgets/gallery/gallery_sidebar.dart';
import 'vibe_category_item.dart';
import '../../../../utils/library_sidebar_sort.dart';
import '../../../../providers/library_sidebar_sort_provider.dart';
import '../../../../widgets/gallery/gallery_sidebar_sort_control.dart';
import '../../../../widgets/gallery/library_sidebar_drag_item.dart';
import '../../../../../data/models/gallery/gallery_tree_drop_slot.dart';

/// Flat collection navigation for the Vibe library.
///
/// Vibes use lightweight logical categories rather than a filesystem tree, so
/// the sidebar intentionally exposes only All, Favorites and user categories.
class VibeCategoryTreeView extends ConsumerWidget {
  const VibeCategoryTreeView({
    super.key,
    required this.categories,
    required this.totalEntryCount,
    required this.favoriteCount,
    required this.onCategorySelected,
    this.categoryEntryCounts = const {},
    this.includeAll = true,
    this.showSortHeader = false,
    this.selectedCategoryId,
    this.onCategoryRename,
    this.onCategoryDelete,
    this.onCreateCategory,
    this.onEntryDrop,
    this.onFavoriteDrop,
    this.onCategoryMoveToSlot,
  });

  final List<VibeLibraryCategory> categories;
  final int totalEntryCount;
  final int favoriteCount;
  final Map<String, int> categoryEntryCounts;
  final bool includeAll;
  final bool showSortHeader;
  final String? selectedCategoryId;
  final ValueChanged<String?> onCategorySelected;
  final void Function(String id, String newName)? onCategoryRename;
  final ValueChanged<String>? onCategoryDelete;
  final VoidCallback? onCreateCategory;
  final FutureOr<void> Function(VibeLibraryEntry entry, String? categoryId)?
  onEntryDrop;
  final FutureOr<void> Function(VibeLibraryEntry)? onFavoriteDrop;
  final Future<bool> Function(
    String id,
    String targetId,
    GalleryTreeDropSlot slot,
  )?
  onCategoryMoveToSlot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(vibeLibraryNotifierProvider.notifier);
    Future<VibeLibraryEntry?> resolve(String id) async =>
        (await owner.resolveEntriesByIds([id])).singleOrNull;
    final sort = ref
        .watch(librarySidebarSortProvider(LibrarySidebarSection.vibeCategories))
        .sort;
    final sortedCategories = sortLibrarySidebarItems(
      categories,
      sort: sort,
      idOf: (c) => c.id,
      nameOf: (c) => c.displayName,
      countOf: (c) => categoryEntryCounts[c.id] ?? 0,
      orderOf: (c) => c.sortOrder,
    );
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapUp: onCreateCategory == null
          ? null
          : (details) => _showCreateMenu(context, details.globalPosition),
      child: ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        children: [
          if (includeAll)
            LibraryClassificationDropTarget<VibeLibraryEntry>(
              kind: AgentChatResourceKind.vibeLibraryEntry,
              resolve: resolve,
              enabled: onEntryDrop != null,
              needsChange: (entry) => entry.categoryId != null,
              onAccept: (entry) => onEntryDrop?.call(entry, null),
              child: GalleryAllImagesItem(
                key: const ValueKey('vibe-library-all'),
                label: context.l10n.vibeLibrary_allVibes,
                icon: Icons.auto_awesome_outlined,
                selectedIcon: Icons.auto_awesome_rounded,
                count: totalEntryCount,
                isSelected: selectedCategoryId == null,
                onTap: () => onCategorySelected(null),
              ),
            ),
          if (showSortHeader) _buildSortHeader(context),
          LibraryClassificationDropTarget<VibeLibraryEntry>(
            kind: AgentChatResourceKind.vibeLibraryEntry,
            resolve: resolve,
            enabled: onFavoriteDrop != null,
            needsChange: (entry) => !entry.isFavorite,
            onAccept: (entry) => onFavoriteDrop?.call(entry),
            child: GallerySidebarFavoritesItem(
              key: const ValueKey('vibe-library-favorites'),
              label: context.l10n.vibeLibrary_favorites,
              count: favoriteCount,
              isSelected: selectedCategoryId == 'favorites',
              onTap: () => onCategorySelected('favorites'),
            ),
          ),
          for (final category in sortedCategories)
            LibraryClassificationDropTarget<VibeLibraryEntry>(
              key: ValueKey(('vibe-category', category.id)),
              kind: AgentChatResourceKind.vibeLibraryEntry,
              resolve: resolve,
              enabled: onEntryDrop != null,
              needsChange: (entry) => entry.categoryId != category.id,
              onAccept: (entry) => onEntryDrop?.call(entry, category.id),
              child: _draggable(
                category,
                VibeCategoryItem(
                  key: ValueKey('vibe-library-category-${category.id}'),
                  icon: Icons.label_outline_rounded,
                  label: category.displayName,
                  count: categoryEntryCounts[category.id] ?? 0,
                  isSelected: selectedCategoryId == category.id,
                  onTap: () => onCategorySelected(category.id),
                  onRename: onCategoryRename == null
                      ? null
                      : (name) => onCategoryRename!(category.id, name),
                  onDelete: onCategoryDelete == null
                      ? null
                      : () => onCategoryDelete!(category.id),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSortHeader(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Wrap(
      alignment: WrapAlignment.end,
      children: [
        const GallerySidebarSortControl(
          section: LibrarySidebarSection.vibeCategories,
        ),
        if (onCreateCategory != null)
          IconButton(
            tooltip: context.l10n.common_new,
            onPressed: onCreateCategory,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 48),
            icon: const Icon(Icons.add, size: 18),
          ),
      ],
    ),
  );

  Widget _draggable(VibeLibraryCategory category, Widget child) {
    if (onCategoryMoveToSlot == null) return child;
    return LibrarySidebarDragItem<VibeLibraryCategory>(
      item: category,
      label: category.displayName,
      icon: Icons.label_outline_rounded,
      allowChildren: false,
      canDrop: (source, slot) =>
          source.id != category.id && slot != GalleryTreeDropSlot.child,
      onDrop: (source, slot) =>
          onCategoryMoveToSlot!(source.id, category.id, slot),
      child: child,
    );
  }

  void _showCreateMenu(BuildContext context, Offset position) {
    showMenu<void>(
      context: context,
      position: contextMenuAnchorAt(context, position),
      items: [
        PopupMenuItem<void>(
          onTap: onCreateCategory,
          child: Row(
            children: [
              const Icon(Icons.add, size: 18),
              const SizedBox(width: 8),
              Text(context.l10n.tagLibrary_newCategory),
            ],
          ),
        ),
      ],
    );
  }
}
