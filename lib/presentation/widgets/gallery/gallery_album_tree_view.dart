import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../core/platform/platform_capabilities.dart';
import '../../../core/utils/localization_extension.dart';
import '../../adaptive/interaction_policy.dart';
import '../../../data/models/gallery/gallery_album.dart';
import '../../../data/models/gallery/gallery_tree_drop_slot.dart';
import '../../../data/models/gallery/local_image_record.dart';
import '../common/context_menu_anchor.dart';
import '../common/themed_input.dart';
import 'gallery_category_tree_view.dart'
    show galleryFilePathFromDataReader, galleryInternalDragPathFromLocalData;

enum _AlbumAction { rename, addSubAlbum, moveUp, moveToRoot, delete }

/// 顶部系统节点与可嵌套的用户相簿树。
///
/// 拖拽图片到相簿 = 加入相簿（逻辑引用，不移动物理文件）。
class GalleryAlbumTreeView extends StatefulWidget {
  final List<GalleryAlbum> albums;
  final int totalImageCount;
  final int favoriteCount;
  final String? selectedAlbumId;
  final bool includeAllImages;
  final bool embedded;
  final ValueChanged<String?> onAlbumSelected;
  final Future<void> Function(String albumId, String newName)? onAlbumRename;
  final Future<void> Function(String albumId)? onAlbumDeleteRequest;
  final Future<void> Function(String? parentId)? onAddAlbumRequest;
  final Future<bool> Function(String albumId, String? newParentId)? onAlbumMove;
  final Future<bool> Function(
    String albumId,
    String targetId,
    GalleryTreeDropSlot slot,
  )?
  onAlbumMoveToSlot;
  final void Function(String imagePath, String albumId)? onImageDrop;
  final VoidCallback? onCreateAlbumRequest;

  const GalleryAlbumTreeView({
    super.key,
    required this.albums,
    required this.totalImageCount,
    this.favoriteCount = 0,
    this.selectedAlbumId,
    this.includeAllImages = true,
    this.embedded = false,
    required this.onAlbumSelected,
    this.onAlbumRename,
    this.onAlbumDeleteRequest,
    this.onAddAlbumRequest,
    this.onAlbumMove,
    this.onAlbumMoveToSlot,
    this.onImageDrop,
    this.onCreateAlbumRequest,
  });

  @override
  State<GalleryAlbumTreeView> createState() => _GalleryAlbumTreeViewState();
}

class _GalleryAlbumTreeViewState extends State<GalleryAlbumTreeView> {
  final Set<String> _expandedIds = {};
  final Set<String> _superDraggingAlbumIds = {};
  String? _hoveredAlbumId;
  final Map<String, GalleryTreeDropSlot> _slotStates = {};
  Timer? _autoExpandTimer;

  @override
  void dispose() {
    _autoExpandTimer?.cancel();
    super.dispose();
  }

  void _startAutoExpandTimer(String albumId) {
    _autoExpandTimer?.cancel();
    _autoExpandTimer = Timer(const Duration(milliseconds: 800), () {
      if (_hoveredAlbumId == albumId && mounted) {
        setState(() => _expandedIds.add(albumId));
      }
    });
  }

  @override
  void didUpdateWidget(covariant GalleryAlbumTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 新出现的相簿（新建子相簿/云恢复/导入）自动展开其祖先链，
    // 保证新节点立即可见；与分类树行为保持一致
    if (oldWidget.albums == widget.albums) return;
    final oldIds = {for (final album in oldWidget.albums) album.id};
    final parentOf = {
      for (final album in widget.albums) album.id: album.parentId,
    };
    var changed = false;
    for (final album in widget.albums) {
      if (oldIds.contains(album.id)) continue;
      var parentId = album.parentId;
      while (parentId != null && !_expandedIds.contains(parentId)) {
        changed = true;
        _expandedIds.add(parentId);
        parentId = parentOf[parentId];
      }
    }
    if (changed) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: widget.embedded,
      physics: widget.embedded ? const NeverScrollableScrollPhysics() : null,
      padding: EdgeInsets.symmetric(vertical: widget.embedded ? 0 : 8),
      children: [
        if (widget.includeAllImages)
          GalleryAllImagesItem(
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
        if (widget.albums.isEmpty)
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
      onRename: widget.onAlbumRename == null
          ? null
          : (newName) => widget.onAlbumRename!(album.id, newName),
      onAddSubAlbum: widget.onAddAlbumRequest == null
          ? null
          : () => widget.onAddAlbumRequest!(album.id),
      onMoveUp:
          (depth < 2 || widget.onAlbumMove == null || album.parentId == null)
          ? null
          : () {
              final grandParent = widget.albums
                  .findById(album.parentId!)
                  ?.parentId;
              widget.onAlbumMove!(album.id, grandParent);
            },
      onMoveToRoot: (depth == 0 || widget.onAlbumMove == null)
          ? null
          : () => widget.onAlbumMove!(album.id, null),
      onDelete: widget.onAlbumDeleteRequest == null
          ? null
          : () => widget.onAlbumDeleteRequest!(album.id),
    );

    // 节点自身：可拖动 + 三槽放置目标（before/after=排序或跨层上移，child=移入）
    Widget node = item;
    if (widget.onAlbumMoveToSlot != null) {
      node = _buildDraggableAlbum(album, node);
      node = _buildAlbumSlotTarget(album, node);
    }

    // 图片拖放目标包整棵子树（图片拖到子树任意处=加入该相簿）
    if (!isExpanded || children.isEmpty) {
      return _wrapDropTarget(album, [node]);
    }
    return _wrapDropTarget(album, [
      node,
      for (final child in children) _buildAlbumNode(child, depth + 1),
    ]);
  }

  Widget _buildDraggableAlbum(GalleryAlbum album, Widget child) {
    final theme = Theme.of(context);
    return Draggable<GalleryAlbum>(
      data: album,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        color: theme.colorScheme.surfaceContainerHigh,
        child: Container(
          width: 180,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.photo_album_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  album.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: child),
      onDragStarted: () => HapticFeedback.mediumImpact(),
      onDragEnd: (_) {
        _autoExpandTimer?.cancel();
        setState(() => _hoveredAlbumId = null);
      },
      child: child,
    );
  }

  Widget _buildAlbumSlotTarget(GalleryAlbum target, Widget child) {
    final theme = Theme.of(context);
    final childKey = GlobalKey();

    return DragTarget<GalleryAlbum>(
      onWillAcceptWithDetails: (details) {
        final dragged = details.data;
        if (dragged.id == target.id) return false;
        final slot = _slotStates[target.id];
        final chainHead = slot == GalleryTreeDropSlot.child
            ? target.id
            : target.parentId;
        var ancestor = chainHead;
        while (ancestor != null) {
          if (ancestor == dragged.id) return false;
          ancestor = widget.albums.findById(ancestor)?.parentId;
        }
        return true;
      },
      onMove: (details) {
        final box = childKey.currentContext?.findRenderObject() as RenderBox?;
        final slot = box == null
            ? GalleryTreeDropSlot.child
            : _slotFor(
                details.offset,
                box.localToGlobal(Offset.zero) & box.size,
              );
        if (_hoveredAlbumId != target.id || _slotStates[target.id] != slot) {
          setState(() {
            _hoveredAlbumId = target.id;
            _slotStates[target.id] = slot;
          });
        }
        if (slot == GalleryTreeDropSlot.child &&
            widget.albums.getChildren(target.id).isNotEmpty &&
            !_expandedIds.contains(target.id)) {
          _startAutoExpandTimer(target.id);
        }
      },
      onLeave: (_) {
        if (_hoveredAlbumId == target.id) {
          _autoExpandTimer?.cancel();
          setState(() {
            _hoveredAlbumId = null;
            _slotStates.remove(target.id);
          });
        }
      },
      onAcceptWithDetails: (details) {
        HapticFeedback.heavyImpact();
        final slot = _slotStates[target.id] ?? GalleryTreeDropSlot.child;
        _autoExpandTimer?.cancel();
        setState(() {
          _hoveredAlbumId = null;
          _slotStates.remove(target.id);
          if (slot == GalleryTreeDropSlot.child) {
            _expandedIds.add(target.id);
          }
        });
        widget.onAlbumMoveToSlot?.call(details.data.id, target.id, slot);
      },
      builder: (context, candidate, rejected) {
        final dragging = candidate.isNotEmpty;
        final slot = _slotStates[target.id];
        final showLineBefore = dragging && slot == GalleryTreeDropSlot.before;
        final showLineAfter = dragging && slot == GalleryTreeDropSlot.after;
        final showChild = dragging && slot == GalleryTreeDropSlot.child;
        final rejectedHint = rejected.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: showChild
                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            border: showChild
                ? Border.all(color: theme.colorScheme.primary, width: 2)
                : rejectedHint
                ? Border.all(
                    color: theme.colorScheme.error.withValues(alpha: 0.5),
                    width: 1,
                  )
                : null,
            borderRadius: showChild || rejectedHint
                ? BorderRadius.circular(8)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showLineBefore)
                Container(height: 2, color: theme.colorScheme.primary),
              KeyedSubtree(key: childKey, child: child),
              if (showLineAfter)
                Container(height: 2, color: theme.colorScheme.primary),
            ],
          ),
        );
      },
    );
  }

  GalleryTreeDropSlot _slotFor(Offset globalOffset, Rect rect) {
    final local = globalOffset.dy - rect.top;
    if (local < rect.height * 0.25) return GalleryTreeDropSlot.before;
    if (local > rect.height * 0.75) return GalleryTreeDropSlot.after;
    return GalleryTreeDropSlot.child;
  }

  Widget _wrapDropTarget(GalleryAlbum album, List<Widget> children) {
    if (widget.onImageDrop == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    // 内层：应用内卡片拖拽（Flutter 原生 Draggable/DragTarget 协议）
    final dragTarget = DragTarget<LocalImageRecord>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        HapticFeedback.heavyImpact();
        widget.onImageDrop?.call(details.data.path, album.id);
      },
      builder: (context, candidate, rejected) {
        final dragging =
            candidate.isNotEmpty || _superDraggingAlbumIds.contains(album.id);
        return AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
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

    // 外层：系统级文件拖放（文件管理器拖图入相簿），与分类树同一协议；
    // 不支持平台（如 Android 应用内拖动已由内层覆盖）保持内层即可
    if (!PlatformCapabilities.current.supportsExternalFileDrop) {
      return dragTarget;
    }

    return DropRegion(
      formats: const [Formats.fileUri],
      onDropOver: (event) {
        if (event.session.allowedOperations.contains(DropOperation.copy)) {
          if (!_superDraggingAlbumIds.contains(album.id)) {
            setState(() => _superDraggingAlbumIds.add(album.id));
          }
          return DropOperation.copy;
        }
        return DropOperation.none;
      },
      onDropLeave: (event) {
        if (_superDraggingAlbumIds.contains(album.id)) {
          setState(() => _superDraggingAlbumIds.remove(album.id));
        }
      },
      onPerformDrop: (event) async {
        if (_superDraggingAlbumIds.contains(album.id)) {
          setState(() => _superDraggingAlbumIds.remove(album.id));
        }
        for (final item in event.session.items) {
          final internalPath = galleryInternalDragPathFromLocalData(
            item.localData,
          );
          if (internalPath != null) {
            HapticFeedback.heavyImpact();
            widget.onImageDrop?.call(internalPath, album.id);
            continue;
          }

          final reader = item.dataReader;
          if (reader == null) continue;
          if (reader.canProvide(Formats.fileUri)) {
            final filePath = await galleryFilePathFromDataReader(reader);
            if (filePath != null) {
              HapticFeedback.heavyImpact();
              widget.onImageDrop?.call(filePath, album.id);
            }
          }
        }
      },
      child: dragTarget,
    );
  }
}

class GalleryAllImagesItem extends StatefulWidget {
  const GalleryAllImagesItem({
    super.key,
    required this.count,
    required this.isSelected,
    required this.onTap,
    this.label,
    this.icon = Icons.photo_library_outlined,
    this.selectedIcon = Icons.photo_library_rounded,
    this.iconColor,
  });

  final int count;
  final bool isSelected;
  final VoidCallback onTap;
  final String? label;
  final IconData icon;
  final IconData selectedIcon;
  final Color? iconColor;

  @override
  State<GalleryAllImagesItem> createState() => _GalleryAllImagesItemState();
}

class _GalleryAllImagesItemState extends State<GalleryAllImagesItem> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = widget.isSelected
        ? colors.onPrimaryContainer
        : colors.onSurface;

    return Semantics(
      button: true,
      selected: widget.isSelected,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            gradient: widget.isSelected
                ? LinearGradient(
                    colors: [
                      colors.primaryContainer,
                      Color.alphaBlend(
                        colors.primary.withValues(alpha: 0.08),
                        colors.primaryContainer,
                      ),
                    ],
                  )
                : null,
            color: widget.isSelected
                ? null
                : colors.onSurface.withValues(
                    alpha: _isHovering ? 0.09 : 0.045,
                  ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 150),
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: widget.isSelected
                            ? colors.primary.withValues(alpha: 0.18)
                            : colors.onSurface.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        widget.isSelected ? widget.selectedIcon : widget.icon,
                        size: 18,
                        color:
                            widget.iconColor ??
                            (widget.isSelected
                                ? colors.primary
                                : colors.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.label ?? context.l10n.localGallery_allImages,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                    Container(
                      constraints: const BoxConstraints(minWidth: 30),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: foreground.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        widget.count.toString(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: foreground.withValues(alpha: 0.78),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
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

class _AlbumItem extends StatefulWidget {
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
    this.onRename,
    this.onAddSubAlbum,
    this.onMoveUp,
    this.onMoveToRoot,
    this.onDelete,
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
  final void Function(String newName)? onRename;
  final VoidCallback? onAddSubAlbum;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveToRoot;
  final VoidCallback? onDelete;

  @override
  State<_AlbumItem> createState() => _AlbumItemState();
}

/// 相簿条目；交互模式与分类树 _CategoryItem 保持一致：
/// 右键/触摸菜单每项自带动作，重命名进入就地编辑。
class _AlbumItemState extends State<_AlbumItem> {
  bool _isEditing = false;
  late TextEditingController _editController;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.label);
  }

  @override
  void didUpdateWidget(covariant _AlbumItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.label != widget.label && !_isEditing) {
      _editController.text = widget.label;
    }
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final interactionPolicy = context.interactionPolicy;
    final isTouch = interactionPolicy.touchAvailable;
    final controlExtent = interactionPolicy.minimumControlExtent;
    final backgroundInset = (24.0 + widget.depth * 12.0)
        .clamp(24.0, 48.0)
        .toDouble();

    final row = Row(
      children: [
        if (widget.hasChildren)
          IconButton(
            onPressed: widget.onExpand,
            tooltip: widget.isExpanded
                ? context.l10n.common_collapse
                : context.l10n.common_expand,
            icon: Icon(
              widget.isExpanded ? Icons.expand_more : Icons.chevron_right,
              size: 18,
              color: theme.colorScheme.outline,
            ),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints.tightFor(
              width: controlExtent,
              height: controlExtent,
            ),
          )
        else
          SizedBox(width: controlExtent, height: controlExtent),
        Icon(
          widget.icon,
          size: 18,
          color:
              widget.iconColor ??
              (widget.isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _isEditing
              ? ThemedInput(
                  controller: _editController,
                  autofocus: true,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      widget.onRename?.call(value.trim());
                    }
                    setState(() => _isEditing = false);
                  },
                  onTapOutside: (_) => setState(() => _isEditing = false),
                )
              : Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: widget.isSelected
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: widget.isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
        ),
        Text(
          widget.count.toString(),
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
          ),
        ),
        if (isTouch &&
            (widget.onRename != null ||
                widget.onAddSubAlbum != null ||
                widget.onMoveToRoot != null ||
                widget.onDelete != null))
          PopupMenuButton<_AlbumAction>(
            tooltip: context.l10n.common_moreActions,
            onSelected: (action) {
              switch (action) {
                case _AlbumAction.rename:
                  setState(() => _isEditing = true);
                case _AlbumAction.addSubAlbum:
                  widget.onAddSubAlbum?.call();
                case _AlbumAction.moveUp:
                  widget.onMoveUp?.call();
                case _AlbumAction.moveToRoot:
                  widget.onMoveToRoot?.call();
                case _AlbumAction.delete:
                  widget.onDelete?.call();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _AlbumAction.rename,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.edit),
                  title: Text(context.l10n.common_rename),
                ),
              ),
              PopupMenuItem(
                value: _AlbumAction.addSubAlbum,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.create_new_folder),
                  title: Text(context.l10n.localGallery_createSubAlbum),
                ),
              ),
              if (widget.onMoveUp != null)
                PopupMenuItem(
                  value: _AlbumAction.moveUp,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.arrow_upward),
                    title: Text(context.l10n.localGallery_moveAlbumUp),
                  ),
                ),
              if (widget.depth > 0)
                PopupMenuItem(
                  value: _AlbumAction.moveToRoot,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.drive_file_move_outline),
                    title: Text(context.l10n.localGallery_moveAlbumToRoot),
                  ),
                ),
              PopupMenuItem(
                value: _AlbumAction.delete,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                  ),
                  title: Text(context.l10n.common_delete),
                ),
              ),
            ],
          ),
      ],
    );

    return Semantics(
      button: true,
      selected: widget.isSelected,
      child: GestureDetector(
        onSecondaryTapUp: widget.onRename != null
            ? (details) => _showContextMenu(context, details.globalPosition)
            : null,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 150),
          margin: EdgeInsets.only(
            left: backgroundInset,
            right: 8,
            top: 1,
            bottom: 1,
          ),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? theme.colorScheme.primaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: widget.onTap,
              hoverColor: theme.colorScheme.onSurface.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: controlExtent),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 4,
                    right: isTouch ? 0 : 8,
                    top: isTouch ? 0 : 8,
                    bottom: isTouch ? 0 : 8,
                  ),
                  child: row,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 桌面右键菜单；各项自带动作（与分类树一致），选择即执行
  void _showContextMenu(BuildContext context, Offset position) {
    showMenu(
      context: context,
      position: contextMenuAnchorAt(context, position),
      items: [
        if (widget.onRename != null)
          PopupMenuItem(
            onTap: () => Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) setState(() => _isEditing = true);
            }),
            child: Row(
              children: [
                const Icon(Icons.edit, size: 18),
                const SizedBox(width: 8),
                Text(context.l10n.common_rename),
              ],
            ),
          ),
        if (widget.onAddSubAlbum != null)
          PopupMenuItem(
            onTap: widget.onAddSubAlbum,
            child: Row(
              children: [
                const Icon(Icons.create_new_folder, size: 18),
                const SizedBox(width: 8),
                Text(context.l10n.localGallery_createSubAlbum),
              ],
            ),
          ),
        if (widget.onMoveUp != null)
          PopupMenuItem(
            onTap: widget.onMoveUp,
            child: Row(
              children: [
                const Icon(Icons.arrow_upward, size: 18),
                const SizedBox(width: 8),
                Text(context.l10n.localGallery_moveAlbumUp),
              ],
            ),
          ),
        if (widget.onMoveToRoot != null)
          PopupMenuItem(
            onTap: widget.onMoveToRoot,
            child: Row(
              children: [
                const Icon(Icons.drive_file_move_outline, size: 18),
                const SizedBox(width: 8),
                Text(context.l10n.localGallery_moveAlbumToRoot),
              ],
            ),
          ),
        if (widget.onDelete != null)
          PopupMenuItem(
            onTap: widget.onDelete,
            child: Row(
              children: [
                Icon(
                  Icons.delete,
                  size: 18,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.common_delete,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
