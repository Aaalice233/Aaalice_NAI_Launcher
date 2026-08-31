import 'package:flutter/material.dart';

import '../../../core/platform/platform_capabilities.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/models/gallery/gallery_album.dart';
import '../../../data/models/gallery/local_image_record.dart';
import '../common/themed_divider.dart';

enum _AlbumAction { rename, addSubAlbum, moveToRoot, delete }

/// 相簿树视图
///
/// 顶部固定「全部图片 / 收藏」系统节点，下方为可嵌套的用户相簿树。
/// 拖拽图片到相簿 = 加入相簿（逻辑引用，不移动物理文件）。
class GalleryAlbumTreeView extends StatefulWidget {
  final List<GalleryAlbum> albums;
  final int totalImageCount;
  final int favoriteCount;
  final String? selectedAlbumId;
  final ValueChanged<String?> onAlbumSelected;
  final Future<void> Function(String albumId)? onAlbumRenameRequest;
  final Future<void> Function(String albumId)? onAlbumDeleteRequest;
  final Future<void> Function(String? parentId)? onAddAlbumRequest;
  final Future<bool> Function(String albumId, String? newParentId)? onAlbumMove;
  final void Function(String imagePath, String albumId)? onImageDrop;
  final VoidCallback? onCreateAlbumRequest;

  const GalleryAlbumTreeView({
    super.key,
    required this.albums,
    required this.totalImageCount,
    this.favoriteCount = 0,
    this.selectedAlbumId,
    required this.onAlbumSelected,
    this.onAlbumRenameRequest,
    this.onAlbumDeleteRequest,
    this.onAddAlbumRequest,
    this.onAlbumMove,
    this.onImageDrop,
    this.onCreateAlbumRequest,
  });

  @override
  State<GalleryAlbumTreeView> createState() => _GalleryAlbumTreeViewState();
}

class _GalleryAlbumTreeViewState extends State<GalleryAlbumTreeView> {
  final Set<String> _expandedIds = {};

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _AlbumItem(
          icon: Icons.photo_library_outlined,
          label: context.l10n.localGallery_allImages,
          count: widget.totalImageCount,
          isSelected: widget.selectedAlbumId == null,
          onTap: () => widget.onAlbumSelected(null),
        ),
        _AlbumItem(
          icon: widget.selectedAlbumId == 'favorites'
              ? Icons.favorite
              : Icons.favorite_border,
          iconColor: Colors.red.shade400,
          label: context.l10n.common_favorite,
          count: widget.favoriteCount,
          isSelected: widget.selectedAlbumId == 'favorites',
          onTap: () => widget.onAlbumSelected('favorites'),
        ),
        if (widget.albums.isNotEmpty)
          const ThemedDivider(height: 16, indent: 12, endIndent: 12)
        else
          _EmptyAlbumHint(onCreate: widget.onCreateAlbumRequest),
        ..._buildRootNodes(),
      ],
    );
  }

  List<Widget> _buildRootNodes() {
    return [
      for (final album in widget.albums.rootAlbums) _buildAlbumNode(album, 0),
    ];
  }

  Widget _buildAlbumNode(GalleryAlbum album, int depth) {
    final children = widget.albums.getChildren(album.id);
    final isExpanded = _expandedIds.contains(album.id);

    final item = _AlbumItem(
      icon: Icons.photo_album_outlined,
      label: album.name,
      count: album.imageCount,
      depth: depth,
      isSelected: widget.selectedAlbumId == album.id,
      hasChildren: children.isNotEmpty,
      isExpanded: isExpanded,
      onExpand: () => setState(
        () => isExpanded
            ? _expandedIds.remove(album.id)
            : _expandedIds.add(album.id),
      ),
      onTap: () => widget.onAlbumSelected(album.id),
      onMenuAction: (action) => _handleAction(album, action),
    );

    // 展开时把子树包进同一个拖放目标，整棵子树都是有效放置区
    if (!isExpanded || children.isEmpty) {
      return _wrapDropTarget(album, [item]);
    }
    return _wrapDropTarget(album, [
      item,
      for (final child in children) _buildAlbumNode(child, depth + 1),
    ]);
  }

  Widget _wrapDropTarget(GalleryAlbum album, List<Widget> children) {
    if (widget.onImageDrop == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    return DragTarget<LocalImageRecord>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        widget.onImageDrop?.call(details.data.path, album.id);
      },
      builder: (context, candidate, rejected) {
        final dragging = candidate.isNotEmpty;
        return Container(
          decoration: dragging
              ? BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        );
      },
    );
  }

  void _handleAction(GalleryAlbum album, _AlbumAction action) {
    switch (action) {
      case _AlbumAction.rename:
        widget.onAlbumRenameRequest?.call(album.id);
      case _AlbumAction.addSubAlbum:
        widget.onAddAlbumRequest?.call(album.id);
      case _AlbumAction.moveToRoot:
        widget.onAlbumMove?.call(album.id, null);
      case _AlbumAction.delete:
        widget.onAlbumDeleteRequest?.call(album.id);
    }
  }
}

class _EmptyAlbumHint extends StatelessWidget {
  const _EmptyAlbumHint({required this.onCreate});

  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.localGallery_albumEmptyHint,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (onCreate != null)
            IconButton(
              onPressed: onCreate,
              icon: const Icon(Icons.add, size: 18),
              tooltip: context.l10n.localGallery_createAlbum,
            ),
        ],
      ),
    );
  }
}

class _AlbumItem extends StatelessWidget {
  const _AlbumItem({
    required this.icon,
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
    this.iconColor,
    this.depth = 0,
    this.hasChildren = false,
    this.isExpanded = false,
    this.onExpand,
    this.onMenuAction,
  });

  final IconData icon;
  final Color? iconColor;
  final String label;
  final int count;
  final bool isSelected;
  final int depth;
  final bool hasChildren;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback? onExpand;
  final ValueChanged<_AlbumAction>? onMenuAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTouch = PlatformCapabilities.current.hasTouchInput;
    final indent = (12.0 + depth * 16.0).clamp(12.0, 44.0).toDouble();

    final row = Row(
      children: [
        if (hasChildren)
          IconButton(
            onPressed: onExpand,
            tooltip: isExpanded
                ? context.l10n.common_collapse
                : context.l10n.common_expand,
            icon: Icon(
              isExpanded ? Icons.expand_more : Icons.chevron_right,
              size: 18,
              color: theme.colorScheme.outline,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          )
        else
          SizedBox(width: isTouch ? 48 : 20, height: isTouch ? 48 : 0),
        Icon(
          icon,
          size: 18,
          color:
              iconColor ??
              (isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          count.toString(),
          style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
        ),
        if (isTouch && onMenuAction != null)
          PopupMenuButton<_AlbumAction>(
            tooltip: context.l10n.common_moreActions,
            onSelected: onMenuAction,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _AlbumAction.rename,
                child: Text(context.l10n.common_rename),
              ),
              PopupMenuItem(
                value: _AlbumAction.addSubAlbum,
                child: Text(context.l10n.localGallery_createSubAlbum),
              ),
              if (depth > 0)
                PopupMenuItem(
                  value: _AlbumAction.moveToRoot,
                  child: Text(context.l10n.localGallery_moveAlbumToRoot),
                ),
              PopupMenuItem(
                value: _AlbumAction.delete,
                child: Text(context.l10n.common_delete),
              ),
            ],
          ),
      ],
    );

    return GestureDetector(
      onSecondaryTapUp: onMenuAction != null
          ? (details) => _showMenu(context, details.globalPosition)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: isTouch ? 48 : 36),
            child: Padding(
              padding: EdgeInsets.only(
                left: indent,
                right: isTouch ? 0 : 8,
                top: isTouch ? 0 : 8,
                bottom: isTouch ? 0 : 8,
              ),
              child: row,
            ),
          ),
        ),
      ),
    );
  }

  void _showMenu(BuildContext context, Offset position) {
    showMenu<_AlbumAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        MediaQuery.sizeOf(context).width - position.dx,
        MediaQuery.sizeOf(context).height - position.dy,
      ),
      items: [
        PopupMenuItem(
          value: _AlbumAction.rename,
          child: Text(context.l10n.common_rename),
        ),
        PopupMenuItem(
          value: _AlbumAction.addSubAlbum,
          child: Text(context.l10n.localGallery_createSubAlbum),
        ),
        if (depth > 0)
          PopupMenuItem(
            value: _AlbumAction.moveToRoot,
            child: Text(context.l10n.localGallery_moveAlbumToRoot),
          ),
        PopupMenuItem(
          value: _AlbumAction.delete,
          child: Text(context.l10n.common_delete),
        ),
      ],
    );
  }
}
