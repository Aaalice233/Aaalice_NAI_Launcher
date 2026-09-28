import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../../widgets/gallery/gallery_sidebar_sort_control.dart';
import '../../providers/library_sidebar_sort_provider.dart';
import '../../widgets/gallery/library_sidebar_root_drop_target.dart';

/// 本地图库左栏：全部图像 + 相簿（逻辑引用）+ 文件夹（物理分类）。
class LocalGalleryCategoryPanel extends ConsumerStatefulWidget {
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
    required this.onImagesDrop,
    required this.onSyncWithFileSystem,
    required this.onCreateAlbum,
    required this.onAlbumSelected,
    required this.onAlbumRename,
    required this.onAlbumDeleteRequest,
    required this.onAddAlbumRequest,
    required this.onAlbumMove,
    required this.onAlbumMoveToSlot,
    required this.onCategoryMoveToSlot,
    required this.onImagesDropToAlbum,
    this.onImagesFavoriteDrop,
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

  final Future<void> Function(List<String> imagePaths, String? categoryId)
  onImagesDrop;
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
  final Future<void> Function(List<String> imagePaths, String albumId)
  onImagesDropToAlbum;
  final Future<void> Function(List<String> imagePaths)? onImagesFavoriteDrop;
  final bool modal;
  final ScrollController? scrollController;
  final VoidCallback? afterSelection;

  @override
  ConsumerState<LocalGalleryCategoryPanel> createState() =>
      _LocalGalleryCategoryPanelState();
}

class _LocalGalleryCategoryPanelState
    extends ConsumerState<LocalGalleryCategoryPanel> {
  bool _albumsExpanded = true;
  bool _foldersExpanded = true;

  bool get _allImagesSelected =>
      widget.albumState.selectedAlbumId == null &&
      widget.categoryState.selectedCategoryId == null;

  @override
  Widget build(BuildContext context) {
    final albumSort = ref
        .watch(librarySidebarSortProvider(LibrarySidebarSection.albums))
        .sort;
    final folderSort = ref
        .watch(librarySidebarSortProvider(LibrarySidebarSection.folders))
        .sort;
    return GallerySidebarSurface(
      modal: widget.modal,
      footer: const GalleryScanProgressPanel(),
      child: Column(
        children: [
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
                LibrarySidebarRootDropTarget<GalleryAlbum>(
                  canDrop: (album) => album.parentId != null,
                  onDrop: (album) async {
                    await widget.onAlbumMove(album.id, null);
                  },
                  child: GallerySidebarSectionHeader(
                    toggleKey: const ValueKey('local-gallery-albums-toggle'),
                    icon: Icons.photo_album_outlined,
                    title: context.l10n.localGallery_albumSectionTitle,
                    trailing: const GallerySidebarSortControl(
                      section: LibrarySidebarSection.albums,
                    ),
                    isExpanded: _albumsExpanded,
                    onToggle: () =>
                        setState(() => _albumsExpanded = !_albumsExpanded),
                    onCreate: () => widget.onCreateAlbum(null),
                  ),
                ),
                if (_albumsExpanded)
                  FutureBuilder<int>(
                    future: widget.favoriteCount,
                    builder: (context, snapshot) => GalleryAlbumTreeView(
                      albums: widget.albumState.albums,
                      sort: albumSort,
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
                      onImagesDrop: widget.onImagesDropToAlbum,
                      onImagesFavoriteDrop: widget.onImagesFavoriteDrop,
                      onCreateAlbumRequest: () => widget.onCreateAlbum(null),
                    ),
                  ),
                LibrarySidebarRootDropTarget<GalleryCategory>(
                  canDrop: (category) => category.parentId != null,
                  onDrop: (category) =>
                      widget.onCategoryMove(category.id, null),
                  child: GallerySidebarSectionHeader(
                    toggleKey: const ValueKey('local-gallery-folders-toggle'),
                    icon: Icons.folder_outlined,
                    title: context.l10n.localGallery_folderSectionTitle,
                    trailing: const GallerySidebarSortControl(
                      section: LibrarySidebarSection.folders,
                    ),
                    isExpanded: _foldersExpanded,
                    onToggle: () =>
                        setState(() => _foldersExpanded = !_foldersExpanded),
                    onCreate: widget.onCreateCategory,
                  ),
                ),
                if (_foldersExpanded)
                  GalleryCategoryTreeView(
                    categories: widget.categoryState.categories,
                    sort: folderSort,
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
                    onImagesDrop: widget.onImagesDrop,
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
