import 'package:flutter/material.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../../data/models/vibe/vibe_library_category.dart';
import '../../../../widgets/common/context_menu_anchor.dart';
import '../../../../widgets/gallery/gallery_album_tree_view.dart';
import '../../../../widgets/gallery/gallery_sidebar.dart';
import 'vibe_category_item.dart';

/// Flat collection navigation for the Vibe library.
///
/// Vibes use lightweight logical categories rather than a filesystem tree, so
/// the sidebar intentionally exposes only All, Favorites and user categories.
class VibeCategoryTreeView extends StatelessWidget {
  const VibeCategoryTreeView({
    super.key,
    required this.categories,
    required this.totalEntryCount,
    required this.favoriteCount,
    required this.onCategorySelected,
    this.categoryEntryCounts = const {},
    this.includeAll = true,
    this.selectedCategoryId,
    this.onCategoryRename,
    this.onCategoryDelete,
    this.onCreateCategory,
  });

  final List<VibeLibraryCategory> categories;
  final int totalEntryCount;
  final int favoriteCount;
  final Map<String, int> categoryEntryCounts;
  final bool includeAll;
  final String? selectedCategoryId;
  final ValueChanged<String?> onCategorySelected;
  final void Function(String id, String newName)? onCategoryRename;
  final ValueChanged<String>? onCategoryDelete;
  final VoidCallback? onCreateCategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedCategories = [...categories]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapUp: onCreateCategory == null
          ? null
          : (details) => _showCreateMenu(context, details.globalPosition),
      child: ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        children: [
          if (includeAll)
            GalleryAllImagesItem(
              key: const ValueKey('vibe-library-all'),
              label: context.l10n.vibeLibrary_allVibes,
              icon: Icons.auto_awesome_outlined,
              selectedIcon: Icons.auto_awesome_rounded,
              count: totalEntryCount,
              isSelected: selectedCategoryId == null,
              onTap: () => onCategorySelected(null),
            ),
          GallerySidebarNavigationItem(
            key: const ValueKey('vibe-library-favorites'),
            label: context.l10n.vibeLibrary_favorites,
            icon: Icons.favorite_border,
            selectedIcon: Icons.favorite,
            iconColor: theme.colorScheme.error,
            count: favoriteCount,
            isSelected: selectedCategoryId == 'favorites',
            onTap: () => onCategorySelected('favorites'),
          ),
          for (final category in sortedCategories)
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
        ],
      ),
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
