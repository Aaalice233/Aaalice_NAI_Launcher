import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/localization_extension.dart';
import '../../providers/gallery_album_provider.dart';
import '../../providers/gallery_category_provider.dart';
import '../../providers/local_gallery_provider.dart';
import '../../../data/models/gallery/gallery_album.dart';
import '../../../data/models/gallery/gallery_category.dart';
import '../../../data/models/gallery/gallery_tree_drop_slot.dart';
import '../../widgets/gallery/gallery_album_tree_view.dart';
import '../../widgets/gallery/gallery_category_tree_view.dart';
import '../../widgets/gallery/gallery_scan_progress_panel.dart';
import '../../widgets/gallery/gallery_sidebar.dart';

/// 本地图库左栏：全部图像 + 相簿（逻辑引用）+ 文件夹（物理分类）。
class LocalGalleryCategoryPanel extends StatefulWidget {
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
    required this.onImageDrop,
    required this.onSyncWithFileSystem,
    required this.onCreateAlbum,
    required this.onAlbumSelected,
    required this.onAlbumRename,
    required this.onAlbumDeleteRequest,
    required this.onAddAlbumRequest,
    required this.onAlbumMove,
    required this.onAlbumMoveToSlot,
    required this.onCategoryMoveToSlot,
    required this.onImageDropToAlbum,
    this.modal = false,
    this.scrollController,
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

  final Future<void> Function(String imagePath, String? categoryId) onImageDrop;
  final Future<void> Function() onSyncWithFileSystem;
  final Future<void> Function(String? parentId) onCreateAlbum;
  final ValueChanged<String?> onAlbumSelected;
  final Future<void> Function(String albumId, String newName) onAlbumRename;
  final Future<void> Function(String albumId) onAlbumDeleteRequest;
  final Future<void> Function(String? parentId) onAddAlbumRequest;
  final Future<bool> Function(String albumId, String? newParentId) onAlbumMove;
  final Future<bool> Function(
    String albumId,
    String targetId,
    GalleryTreeDropSlot slot,
  )
  onAlbumMoveToSlot;
  final Future<bool> Function(
    String categoryId,
    String targetId,
    GalleryTreeDropSlot slot,
  )
  onCategoryMoveToSlot;
  final Future<void> Function(String imagePath, String albumId)
  onImageDropToAlbum;
  final bool modal;
  final ScrollController? scrollController;
  final VoidCallback? afterSelection;

  @override
  State<LocalGalleryCategoryPanel> createState() =>
      _LocalGalleryCategoryPanelState();
}

class _LocalGalleryCategoryPanelState extends State<LocalGalleryCategoryPanel> {
  bool _albumsExpanded = true;
  bool _foldersExpanded = true;

  bool get _allImagesSelected =>
      widget.albumState.selectedAlbumId == null &&
      widget.categoryState.selectedCategoryId == null;

  @override
  Widget build(BuildContext context) {
    return GallerySidebarSurface(
      modal: widget.modal,
      footer: const GalleryScanProgressPanel(),
      child: Column(
        children: [
          if (!widget.modal)
            GallerySidebarPageHeader(
              key: const ValueKey('local-gallery-sidebar-page-header'),
              icon: Icons.photo_library_outlined,
              title: context.l10n.localGallery_title,
            ),
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.only(
                top: GalleryCollectionChrome.navigationTopPadding,
              ),
              children: [
                GalleryAllImagesItem(
                  key: const ValueKey('local-gallery-all-images'),
                  count: widget.galleryState.totalCount,
                  isSelected: _allImagesSelected,
                  onTap: _selectAllImages,
                ),
                _wrapRootDropTarget<GalleryAlbum>(
                  GallerySidebarSectionHeader(
                    toggleKey: const ValueKey('local-gallery-albums-toggle'),
                    icon: Icons.photo_album_outlined,
                    title: context.l10n.localGallery_albumSectionTitle,
                    isExpanded: _albumsExpanded,
                    onToggle: () =>
                        setState(() => _albumsExpanded = !_albumsExpanded),
                    onCreate: () => widget.onCreateAlbum(null),
                  ),
                  (album) => album.id,
                  (albumId) => widget.onAlbumMove(albumId, null),
                ),
                if (_albumsExpanded)
                  FutureBuilder<int>(
                    future: widget.favoriteCount,
                    builder: (context, snapshot) => GalleryAlbumTreeView(
                      albums: widget.albumState.albums,
                      totalImageCount: widget.galleryState.totalCount,
                      favoriteCount: snapshot.data ?? 0,
                      selectedAlbumId: widget.albumState.selectedAlbumId,
                      includeAllImages: false,
                      embedded: true,
                      onAlbumSelected: (id) {
                        widget.onAlbumSelected(id);
                        widget.afterSelection?.call();
                      },
                      onAlbumRename: widget.onAlbumRename,
                      onAlbumDeleteRequest: widget.onAlbumDeleteRequest,
                      onAddAlbumRequest: widget.onAddAlbumRequest,
                      onAlbumMove: widget.onAlbumMove,
                      onAlbumMoveToSlot: widget.onAlbumMoveToSlot,
                      onImageDrop: widget.onImageDropToAlbum,
                      onCreateAlbumRequest: () => widget.onCreateAlbum(null),
                    ),
                  ),
                _wrapRootDropTarget<GalleryCategory>(
                  GallerySidebarSectionHeader(
                    toggleKey: const ValueKey('local-gallery-folders-toggle'),
                    icon: Icons.folder_outlined,
                    title: context.l10n.localGallery_folderSectionTitle,
                    isExpanded: _foldersExpanded,
                    onToggle: () =>
                        setState(() => _foldersExpanded = !_foldersExpanded),
                    onCreate: widget.onCreateCategory,
                  ),
                  (category) => category.id,
                  (categoryId) => widget.onCategoryMove(categoryId, null),
                ),
                if (_foldersExpanded)
                  GalleryCategoryTreeView(
                    categories: widget.categoryState.categories,
                    totalImageCount: widget.galleryState.totalCount,
                    selectedCategoryId: widget.categoryState.selectedCategoryId,
                    includeRootNodes: false,
                    embedded: true,
                    showScanProgress: false,
                    onCategorySelected: (id) {
                      widget.onCategorySelected(id);
                      widget.afterSelection?.call();
                    },
                    onCategoryRename: widget.onCategoryRename,
                    onCategoryDelete: widget.onCategoryDelete,
                    onAddSubCategory: widget.onAddSubCategory,
                    onCategoryMove: widget.onCategoryMove,
                    onCategoryMoveToSlot: widget.onCategoryMoveToSlot,
                    onImageDrop: widget.onImageDrop,
                    onSyncWithFileSystem: widget.onSyncWithFileSystem,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _selectAllImages() {
    widget.onCategorySelected(null);
    widget.afterSelection?.call();
  }
}

/// 拖到分区标题 = 移到根级（相簿/分类各自的类型与回调）
Widget _wrapRootDropTarget<T extends Object>(
  Widget child,
  String Function(T item) idOf,
  Future<void> Function(String itemId) onMoveToRoot,
) {
  return Builder(
    builder: (context) {
      return DragTarget<T>(
        onWillAcceptWithDetails: (_) => true,
        onAcceptWithDetails: (details) {
          HapticFeedback.heavyImpact();
          onMoveToRoot(idOf(details.data));
        },
        builder: (context, candidate, rejected) {
          final dragging = candidate.isNotEmpty;
          final theme = Theme.of(context);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: dragging
                ? BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  )
                : null,
            child: child,
          );
        },
      );
    },
  );
}
