import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../providers/gallery_category_provider.dart';
import '../../providers/local_gallery_provider.dart';
import '../../widgets/gallery/gallery_category_tree_view.dart';

class LocalGalleryCategoryPanel extends StatelessWidget {
  const LocalGalleryCategoryPanel({
    super.key,
    required this.galleryState,
    required this.categoryState,
    required this.favoriteCount,
    required this.onCreateCategory,
    required this.onCategorySelected,
    required this.onCategoryRename,
    required this.onCategoryDelete,
    required this.onAddSubCategory,
    required this.onCategoryMove,
    required this.onCategoryReorder,
    required this.onImageDrop,
    required this.onSyncWithFileSystem,
    this.modal = false,
    this.afterSelection,
  });

  final LocalGalleryState galleryState;
  final GalleryCategoryState categoryState;
  final Future<int> favoriteCount;
  final VoidCallback onCreateCategory;
  final ValueChanged<String?> onCategorySelected;
  final Future<void> Function(String id, String newName) onCategoryRename;
  final Future<void> Function(String id) onCategoryDelete;
  final Future<void> Function(String? parentId) onAddSubCategory;
  final Future<void> Function(String categoryId, String? newParentId)
  onCategoryMove;
  final Future<void> Function(String? parentId, int oldIndex, int newIndex)
  onCategoryReorder;
  final Future<void> Function(String imagePath, String? categoryId) onImageDrop;
  final Future<void> Function() onSyncWithFileSystem;
  final bool modal;
  final VoidCallback? afterSelection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: modal ? double.infinity : 250,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: modal
            ? null
            : Border(
                right: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
                  width: 1,
                ),
              ),
      ),
      child: Column(
        children: [
          _CategoryPanelHeader(
            modal: modal,
            onCreateCategory: onCreateCategory,
          ),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          Expanded(
            child: FutureBuilder<int>(
              future: favoriteCount,
              builder: (context, snapshot) => GalleryCategoryTreeView(
                categories: categoryState.categories,
                totalImageCount: galleryState.totalCount,
                favoriteCount: snapshot.data ?? 0,
                selectedCategoryId: categoryState.selectedCategoryId,
                onCategorySelected: (id) {
                  onCategorySelected(id);
                  afterSelection?.call();
                },
                onCategoryRename: onCategoryRename,
                onCategoryDelete: onCategoryDelete,
                onAddSubCategory: onAddSubCategory,
                onCategoryMove: onCategoryMove,
                onCategoryReorder: onCategoryReorder,
                onImageDrop: onImageDrop,
                onSyncWithFileSystem: onSyncWithFileSystem,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPanelHeader extends StatelessWidget {
  const _CategoryPanelHeader({
    required this.modal,
    required this.onCreateCategory,
  });

  final bool modal;
  final VoidCallback onCreateCategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      constraints: const BoxConstraints(minHeight: 62),
      child: Row(
        children: [
          if (!modal) ...[
            Icon(
              Icons.folder_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.localGallery_categoryPanelTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ] else
            const Spacer(),
          FilledButton.tonalIcon(
            onPressed: onCreateCategory,
            icon: const Icon(Icons.add, size: 18),
            label: Text(
              context.l10n.common_new,
              style: const TextStyle(fontSize: 13),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}
