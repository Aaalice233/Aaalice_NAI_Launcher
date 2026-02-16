import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models/gallery/gallery_folder.dart';
import '../../../data/models/gallery/local_image_record.dart';
import '../common/themed_divider.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';

/// 文件夹树视图
///
/// 支持：
/// - 无限层级嵌套
/// - 拖拽文件夹（跨层级移动）
/// - 拖拽图片到文件夹
/// - 悬停自动展开
/// - 右键菜单
/// - 触觉反馈
class FolderTreeView extends StatefulWidget {
  final List<GalleryFolder> folders;
  final int totalImageCount;
  final int favoriteCount;
  final String? selectedFolderId;
  final ValueChanged<String?> onFolderSelected;
  final void Function(String id, String newName)? onFolderRename;
  final ValueChanged<String>? onFolderDelete;
  final ValueChanged<String?>? onAddSubFolder;
  final void Function(String folderId, String? newParentId)? onFolderMove;
  final void Function(String? parentId, int oldIndex, int newIndex)?
      onFolderReorder;
  final void Function(String imagePath, String? folderId)? onImageDrop;

  const FolderTreeView({
    super.key,
    required this.folders,
    required this.totalImageCount,
    this.favoriteCount = 0,
    this.selectedFolderId,
    required this.onFolderSelected,
    this.onFolderRename,
    this.onFolderDelete,
    this.onAddSubFolder,
    this.onFolderMove,
    this.onFolderReorder,
    this.onImageDrop,
  });

  @override
  State<FolderTreeView> createState() => _FolderTreeViewState();
}

class _FolderTreeViewState extends State<FolderTreeView> {
  final Set<String> _expandedIds = {};
  String? _hoveredFolderId;
  Timer? _autoExpandTimer;

  @override
  void dispose() {
    _autoExpandTimer?.cancel();
    super.dispose();
  }

  void _startAutoExpandTimer(String folderId) {
    _autoExpandTimer?.cancel();
    _autoExpandTimer = Timer(const Duration(milliseconds: 800), () {
      if (_hoveredFolderId == folderId && mounted) {
        setState(() {
          _expandedIds.add(folderId);
        });
      }
    });
  }

  void _cancelAutoExpandTimer() {
    _autoExpandTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onSecondaryTapUp: widget.onAddSubFolder != null
          ? (details) =>
              _showEmptyAreaContextMenu(context, details.globalPosition)
          : null,
      behavior: HitTestBehavior.translucent,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // 全部图片
          _buildImageDropTarget(
            folderId: null,
            child: _FolderItem(
              icon: Icons.photo_library_outlined,
              label: '全部图片',
              count: widget.totalImageCount,
              isSelected: widget.selectedFolderId == null,
              onTap: () => widget.onFolderSelected(null),
            ),
          ),

          // 收藏
          _FolderItem(
            icon: widget.selectedFolderId == 'favorites'
                ? Icons.favorite
                : Icons.favorite_border,
            iconColor: Colors.red.shade400,
            label: '收藏',
            count: widget.favoriteCount,
            isSelected: widget.selectedFolderId == 'favorites',
            onTap: () => widget.onFolderSelected('favorites'),
          ),

          if (widget.folders.isNotEmpty)
            // 文件夹标题分割线
            const ThemedDivider(height: 16, indent: 12, endIndent: 12),

          // 文件夹树
          ...widget.folders.rootFolders.sortedByOrder().map(
                (folder) => _buildFolderNode(theme, folder, 0),
              ),
        ],
      ),
    );
  }

  void _showEmptyAreaContextMenu(BuildContext context, Offset position) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        PopupMenuItem(
          onTap: () => widget.onAddSubFolder?.call(null),
          child: const Row(
            children: [
              Icon(Icons.create_new_folder, size: 18),
              SizedBox(width: 8),
              Text('新建文件夹'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFolderNode(
    ThemeData theme,
    GalleryFolder folder,
    int depth,
  ) {
    final children = widget.folders.getChildren(folder.id).sortedByOrder();
    final hasChildren = children.isNotEmpty;
    final isExpanded = _expandedIds.contains(folder.id);

    Widget folderItem = _FolderItem(
      icon: hasChildren
          ? (isExpanded ? Icons.folder_open : Icons.folder)
          : Icons.folder_outlined,
      label: folder.displayName,
      count: folder.imageCount,
      isSelected: widget.selectedFolderId == folder.id,
      depth: depth,
      hasChildren: hasChildren,
      isExpanded: isExpanded,
      onTap: () => widget.onFolderSelected(folder.id),
      onExpand: hasChildren
          ? () {
              setState(() {
                if (isExpanded) {
                  _expandedIds.remove(folder.id);
                } else {
                  _expandedIds.add(folder.id);
                }
              });
            }
          : null,
      onRename: widget.onFolderRename != null
          ? (newName) => widget.onFolderRename!(folder.id, newName)
          : null,
      onDelete: widget.onFolderDelete != null
          ? () => widget.onFolderDelete!(folder.id)
          : null,
      onAddSubFolder: widget.onAddSubFolder != null
          ? () => widget.onAddSubFolder!(folder.id)
          : null,
      onMoveToRoot: folder.parentId != null && widget.onFolderMove != null
          ? () => widget.onFolderMove!(folder.id, null)
          : null,
    );

    // 包装为可拖拽
    if (widget.onFolderMove != null || widget.onFolderReorder != null) {
      folderItem = _buildDraggableFolder(folder, folderItem);
    }

    // 包装为拖拽目标
    if (widget.onFolderMove != null) {
      folderItem = _buildFolderDragTarget(theme, folder, folderItem);
    }

    // 包装为图片拖拽目标
    folderItem =
        _buildImageDropTarget(folderId: folder.id, child: folderItem);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        folderItem,
        if (hasChildren && isExpanded)
          ...children
              .map((child) => _buildFolderNode(theme, child, depth + 1)),
      ],
    );
  }

  Widget _buildDraggableFolder(GalleryFolder folder, Widget child) {
    final theme = Theme.of(context);

    return Draggable<GalleryFolder>(
      data: folder,
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
              color: theme.colorScheme.primary.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  folder.displayName,
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
        _cancelAutoExpandTimer();
        setState(() => _hoveredFolderId = null);
      },
      child: child,
    );
  }

  Widget _buildFolderDragTarget(
    ThemeData theme,
    GalleryFolder targetFolder,
    Widget child,
  ) {
    return DragTarget<GalleryFolder>(
      onWillAcceptWithDetails: (details) {
        final draggedFolder = details.data;
        // 不能拖到自己
        if (draggedFolder.id == targetFolder.id) return false;
        // 检查循环引用
        if (widget.folders.wouldCreateCycle(
          draggedFolder.id,
          targetFolder.id,
        )) {
          return false;
        }
        // 已经是子文件夹则不接受
        if (draggedFolder.parentId == targetFolder.id) return false;
        return true;
      },
      onAcceptWithDetails: (details) {
        HapticFeedback.heavyImpact();
        widget.onFolderMove?.call(details.data.id, targetFolder.id);
        setState(() {
          _expandedIds.add(targetFolder.id);
          _hoveredFolderId = null;
        });
        _cancelAutoExpandTimer();
      },
      onMove: (details) {
        if (_hoveredFolderId != targetFolder.id) {
          setState(() => _hoveredFolderId = targetFolder.id);
          final hasChildren =
              widget.folders.getChildren(targetFolder.id).isNotEmpty;
          if (hasChildren && !_expandedIds.contains(targetFolder.id)) {
            _startAutoExpandTimer(targetFolder.id);
          }
        }
      },
      onLeave: (_) {
        if (_hoveredFolderId == targetFolder.id) {
          setState(() => _hoveredFolderId = null);
          _cancelAutoExpandTimer();
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isAccepting = candidateData.isNotEmpty;
        final isRejected = rejectedData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isAccepting
                ? theme.colorScheme.primary.withOpacity(0.1)
                : Colors.transparent,
            border: isAccepting
                ? Border.all(color: theme.colorScheme.primary, width: 2)
                : isRejected
                    ? Border.all(
                        color: theme.colorScheme.error.withOpacity(0.5),
                        width: 1,
                      )
                    : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: child,
        );
      },
    );
  }

  Widget _buildImageDropTarget({
    required String? folderId,
    required Widget child,
  }) {
    if (widget.onImageDrop == null) return child;

    return DragTarget<LocalImageRecord>(
      onWillAcceptWithDetails: (details) {
        // 可以接受任何图片
        return true;
      },
      onAcceptWithDetails: (details) {
        HapticFeedback.heavyImpact();
        widget.onImageDrop?.call(details.data.path, folderId);
      },
      builder: (context, candidateData, rejectedData) {
        final isAccepting = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: isAccepting
                ? LinearGradient(
                    colors: [
                      Colors.green.withOpacity(0.15),
                      Colors.green.withOpacity(0.05),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            border: isAccepting
                ? const Border(left: BorderSide(color: Colors.green, width: 4))
                : null,
            borderRadius: isAccepting ? BorderRadius.circular(8) : null,
          ),
          child: child,
        );
      },
    );
  }
}

/// 文件夹项组件
class _FolderItem extends StatefulWidget {
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
  final void Function(String)? onRename;
  final VoidCallback? onDelete;
  final VoidCallback? onAddSubFolder;
  final VoidCallback? onMoveToRoot;

  const _FolderItem({
    required this.icon,
    this.iconColor,
    required this.label,
    required this.count,
    required this.isSelected,
    this.depth = 0,
    this.hasChildren = false,
    this.isExpanded = false,
    required this.onTap,
    this.onExpand,
    this.onRename,
    this.onDelete,
    this.onAddSubFolder,
    this.onMoveToRoot,
  });

  @override
  State<_FolderItem> createState() => _FolderItemState();
}

class _FolderItemState extends State<_FolderItem> {
  bool _isHovering = false;
  bool _isEditing = false;
  late TextEditingController _editController;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.label);
  }

  @override
  void didUpdateWidget(covariant _FolderItem oldWidget) {
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
    final indent = 12.0 + widget.depth * 16.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onSecondaryTapUp: widget.onRename != null
            ? (details) => _showContextMenu(context, details.globalPosition)
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? theme.colorScheme.primaryContainer
                : (_isHovering
                    ? theme.colorScheme.surfaceContainerHighest
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
          ),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: EdgeInsets.only(
                left: indent,
                right: 8,
                top: 8,
                bottom: 8,
              ),
              child: Row(
                children: [
                  // 展开/折叠按钮
                  if (widget.hasChildren)
                    GestureDetector(
                      onTap: widget.onExpand,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          widget.isExpanded
                              ? Icons.expand_more
                              : Icons.chevron_right,
                          size: 16,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 20),

                  // 图标
                  Icon(
                    widget.icon,
                    size: 18,
                    color: widget.iconColor ??
                        (widget.isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 8),

                  // 名称
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
                            onTapOutside: (_) {
                              setState(() => _isEditing = false);
                            },
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

                  // 拖拽提示图标
                  if (_isHovering && widget.onRename != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.drag_indicator,
                        size: 14,
                        color: theme.colorScheme.outline.withOpacity(0.5),
                      ),
                    ),

                  // 数量
                  Text(
                    widget.count.toString(),
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        if (widget.onRename != null)
          PopupMenuItem(
            onTap: () {
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) {
                  setState(() => _isEditing = true);
                }
              });
            },
            child: const Row(
              children: [
                Icon(Icons.edit, size: 18),
                SizedBox(width: 8),
                Text('重命名'),
              ],
            ),
          ),
        if (widget.onAddSubFolder != null)
          PopupMenuItem(
            onTap: widget.onAddSubFolder,
            child: const Row(
              children: [
                Icon(Icons.create_new_folder, size: 18),
                SizedBox(width: 8),
                Text('新建子文件夹'),
              ],
            ),
          ),
        if (widget.onMoveToRoot != null)
          PopupMenuItem(
            onTap: widget.onMoveToRoot,
            child: const Row(
              children: [
                Icon(Icons.drive_file_move_outline, size: 18),
                SizedBox(width: 8),
                Text('移至根目录'),
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
                  '删除',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
