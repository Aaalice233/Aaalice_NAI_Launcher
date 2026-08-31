import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../providers/gallery_album_provider.dart';
import '../../providers/gallery_category_provider.dart';
import '../../providers/local_gallery_provider.dart';
import '../../widgets/gallery/gallery_album_tree_view.dart';
import '../../widgets/gallery/gallery_category_tree_view.dart';

/// 本地图库左栏组织面板：相簿（逻辑引用）+ 文件夹（物理分类）
class LocalGalleryCategoryPanel extends StatelessWidget {
  const LocalGalleryCategoryPanel({
    super.key,
    required this.galleryState,
    required this.categoryState,
    required this.albumState,
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
    required this.onCreateAlbum,
    required this.onAlbumSelected,
    required this.onAlbumRenameRequest,
    required this.onAlbumDeleteRequest,
    required this.onAddAlbumRequest,
    required this.onAlbumMove,
    required this.onImageDropToAlbum,
    this.modal = false,
    this.afterSelection,
  });

  final LocalGalleryState galleryState;
  final GalleryCategoryState categoryState;
  final GalleryAlbumState albumState;
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
  final Future<void> Function(String? parentId) onCreateAlbum;
  final ValueChanged<String?> onAlbumSelected;
  final Future<void> Function(String albumId) onAlbumRenameRequest;
  final Future<void> Function(String albumId) onAlbumDeleteRequest;
  final Future<void> Function(String? parentId) onAddAlbumRequest;
  final Future<bool> Function(String albumId, String? newParentId) onAlbumMove;
  final Future<void> Function(String imagePath, String albumId)
  onImageDropToAlbum;
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
          _PanelSectionHeader(
            modal: modal,
            icon: Icons.photo_album_outlined,
            title: context.l10n.localGallery_albumSectionTitle,
            onCreate: () => onCreateAlbum(null),
          ),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          Expanded(
            flex: 2,
            child: FutureBuilder<int>(
              future: favoriteCount,
              builder: (context, snapshot) => GalleryAlbumTreeView(
                albums: albumState.albums,
                totalImageCount: galleryState.totalCount,
                favoriteCount: snapshot.data ?? 0,
                selectedAlbumId: albumState.selectedAlbumId,
                onAlbumSelected: (id) {
                  onAlbumSelected(id);
                  afterSelection?.call();
                },
                onAlbumRenameRequest: onAlbumRenameRequest,
                onAlbumDeleteRequest: onAlbumDeleteRequest,
                onAddAlbumRequest: onAddAlbumRequest,
                onAlbumMove: onAlbumMove,
                onImageDrop: onImageDropToAlbum,
                onCreateAlbumRequest: () => onCreateAlbum(null),
              ),
            ),
          ),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          _PanelSectionHeader(
            modal: modal,
            icon: Icons.folder_outlined,
            title: context.l10n.localGallery_folderSectionTitle,
            onCreate: onCreateCategory,
          ),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          Expanded(
            flex: 3,
            child: GalleryCategoryTreeView(
              categories: categoryState.categories,
              totalImageCount: galleryState.totalCount,
              selectedCategoryId: categoryState.selectedCategoryId,
              includeRootNodes: false,
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
        ],
      ),
    );
  }
}

class _PanelSectionHeader extends StatelessWidget {
  const _PanelSectionHeader({
    required this.modal,
    required this.icon,
    required this.title,
    required this.onCreate,
  });

  final bool modal;
  final IconData icon;
  final String title;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      constraints: const BoxConstraints(minHeight: 62),
      child: Row(
        children: [
          if (!modal) ...[
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
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
            onPressed: onCreate,
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
