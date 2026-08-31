import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../providers/gallery_album_provider.dart';
import '../../providers/gallery_category_provider.dart';
import '../../providers/local_gallery_provider.dart';
import '../../widgets/gallery/gallery_album_tree_view.dart';
import '../../widgets/gallery/gallery_category_tree_view.dart';
import '../../widgets/gallery/gallery_scan_progress_panel.dart';

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
    final theme = Theme.of(context);
    return Container(
      width: widget.modal ? double.infinity : 250,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: widget.modal
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
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.only(top: 4),
              children: [
                GalleryAllImagesItem(
                  key: const ValueKey('local-gallery-all-images'),
                  count: widget.galleryState.totalCount,
                  isSelected: _allImagesSelected,
                  onTap: _selectAllImages,
                ),
                _PanelSectionHeader(
                  toggleKey: const ValueKey('local-gallery-albums-toggle'),
                  icon: Icons.photo_album_outlined,
                  title: context.l10n.localGallery_albumSectionTitle,
                  isExpanded: _albumsExpanded,
                  onToggle: () =>
                      setState(() => _albumsExpanded = !_albumsExpanded),
                  onCreate: () => widget.onCreateAlbum(null),
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
                      onAlbumRenameRequest: widget.onAlbumRenameRequest,
                      onAlbumDeleteRequest: widget.onAlbumDeleteRequest,
                      onAddAlbumRequest: widget.onAddAlbumRequest,
                      onAlbumMove: widget.onAlbumMove,
                      onImageDrop: widget.onImageDropToAlbum,
                      onCreateAlbumRequest: () => widget.onCreateAlbum(null),
                    ),
                  ),
                _PanelSectionHeader(
                  toggleKey: const ValueKey('local-gallery-folders-toggle'),
                  icon: Icons.folder_outlined,
                  title: context.l10n.localGallery_folderSectionTitle,
                  isExpanded: _foldersExpanded,
                  onToggle: () =>
                      setState(() => _foldersExpanded = !_foldersExpanded),
                  onCreate: widget.onCreateCategory,
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
                    onCategoryReorder: widget.onCategoryReorder,
                    onImageDrop: widget.onImageDrop,
                    onSyncWithFileSystem: widget.onSyncWithFileSystem,
                  ),
              ],
            ),
          ),
          const GalleryScanProgressPanel(),
        ],
      ),
    );
  }

  void _selectAllImages() {
    widget.onCategorySelected(null);
    widget.afterSelection?.call();
  }
}

class _PanelSectionHeader extends StatefulWidget {
  const _PanelSectionHeader({
    required this.toggleKey,
    required this.icon,
    required this.title,
    required this.isExpanded,
    required this.onToggle,
    required this.onCreate,
  });

  final Key toggleKey;
  final IconData icon;
  final String title;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onCreate;

  @override
  State<_PanelSectionHeader> createState() => _PanelSectionHeaderState();
}

class _PanelSectionHeaderState extends State<_PanelSectionHeader> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toggleLabel = widget.isExpanded
        ? context.l10n.common_collapse
        : context.l10n.common_expand;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        key: widget.toggleKey,
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withValues(
            alpha: _isHovered ? 0.11 : 0.06,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  expanded: widget.isExpanded,
                  label: '${widget.title}，$toggleLabel',
                  child: Tooltip(
                    message: toggleLabel,
                    child: InkWell(
                      onTap: widget.onToggle,
                      borderRadius: BorderRadius.circular(8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Row(
                          children: [
                            const SizedBox(width: 4),
                            Icon(
                              widget.isExpanded
                                  ? Icons.expand_more
                                  : Icons.chevron_right,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              widget.icon,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.title,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: widget.onCreate,
                icon: const Icon(Icons.add, size: 18),
                label: Text(context.l10n.common_new),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  textStyle: theme.textTheme.labelMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
