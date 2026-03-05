import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../data/models/gallery/gallery_category.dart';
import '../../../data/models/gallery/local_image_record.dart';
import '../common/themed_divider.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';
import 'gallery_scan_progress_panel.dart';

/// Gallery category tree view with drag-drop support
class GalleryCategoryTreeView extends StatefulWidget {
  final List<GalleryCategory> categories;
  final int totalImageCount;
  final int favoriteCount;
  final String? selectedCategoryId;
  final ValueChanged<String?> onCategorySelected;
  final void Function(String id, String newName)? onCategoryRename;
  final ValueChanged<String>? onCategoryDelete;
  final ValueChanged<String?>? onAddSubCategory;
  final void Function(String categoryId, String? newParentId)? onCategoryMove;
  final void Function(String? parentId, int oldIndex, int newIndex)?
      onCategoryReorder;
  final void Function(String imagePath, String? categoryId)? onImageDrop;
  final VoidCallback? onSyncWithFileSystem;

  const GalleryCategoryTreeView({
    super.key,
    required this.categories,
    required this.totalImageCount,
    this.favoriteCount = 0,
    this.selectedCategoryId,
    required this.onCategorySelected,
    this.onCategoryRename,
    this.onCategoryDelete,
    this.onAddSubCategory,
    this.onCategoryMove,
    this.onCategoryReorder,
    this.onImageDrop,
    this.onSyncWithFileSystem,
  });

  @override
  State<GalleryCategoryTreeView> createState() =>
      _GalleryCategoryTreeViewState();
}

class _GalleryCategoryTreeViewState extends State<GalleryCategoryTreeView> {
  final Set<String> _expandedIds = {};
  String? _hoveredCategoryId;
  Timer? _autoExpandTimer;
  final Set<String> _superDraggingCategoryIds = {};

  @override
  void dispose() {
    _autoExpandTimer?.cancel();
    super.dispose();
  }

  void _startAutoExpandTimer(String categoryId) {
    _autoExpandTimer?.cancel();
    _autoExpandTimer = Timer(const Duration(milliseconds: 800), () {
      if (_hoveredCategoryId == categoryId && mounted) {
        setState(() => _expandedIds.add(categoryId));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onSecondaryTapUp: widget.onAddSubCategory != null
          ? (details) =>
              _showEmptyAreaContextMenu(context, details.globalPosition)
          : null,
      behavior: HitTestBehavior.translucent,
      child: Column(
        children: [
          // 分类树列表
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildImageDropTarget(
                  categoryId: null,
                  child: _CategoryItem(
                    icon: Icons.photo_library_outlined,
                    label: '全部图片',
                    count: widget.totalImageCount,
                    isSelected: widget.selectedCategoryId == null,
                    onTap: () => widget.onCategorySelected(null),
                  ),
                ),
                _CategoryItem(
                  icon: widget.selectedCategoryId == 'favorites'
                      ? Icons.favorite
                      : Icons.favorite_border,
                  iconColor: Colors.red.shade400,
                  label: '收藏',
                  count: widget.favoriteCount,
                  isSelected: widget.selectedCategoryId == 'favorites',
                  onTap: () => widget.onCategorySelected('favorites'),
                ),
                if (widget.categories.isNotEmpty)
                  const ThemedDivider(height: 16, indent: 12, endIndent: 12),
                ...widget.categories.rootCategories.sortedByOrder().map(
                      (category) => _buildCategoryNode(theme, category, 0),
                    ),
              ],
            ),
          ),
          // 扫描进度面板（底部）
          const GalleryScanProgressPanel(),
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
          onTap: () => widget.onAddSubCategory?.call(null),
          child: const Row(
            children: [
              Icon(Icons.create_new_folder, size: 18),
              SizedBox(width: 8),
              Text('新建分类'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryNode(
    ThemeData theme,
    GalleryCategory category,
    int depth,
  ) {
    final children = widget.categories.getChildren(category.id).sortedByOrder();
    final hasChildren = children.isNotEmpty;
    final isExpanded = _expandedIds.contains(category.id);

    Widget categoryItem = _CategoryItem(
      icon: hasChildren
          ? (isExpanded ? Icons.folder_open : Icons.folder)
          : Icons.folder_outlined,
      label: category.displayName,
      count: category.imageCount,
      isSelected: widget.selectedCategoryId == category.id,
      depth: depth,
      hasChildren: hasChildren,
      isExpanded: isExpanded,
      onTap: () => widget.onCategorySelected(category.id),
      onExpand: hasChildren
          ? () => setState(() {
                if (isExpanded) {
                  _expandedIds.remove(category.id);
                } else {
                  _expandedIds.add(category.id);
                }
              })
          : null,
      onRename: widget.onCategoryRename != null
          ? (newName) => widget.onCategoryRename!(category.id, newName)
          : null,
      onDelete: widget.onCategoryDelete != null
          ? () => widget.onCategoryDelete!(category.id)
          : null,
      onAddSubCategory: widget.onAddSubCategory != null
          ? () => widget.onAddSubCategory!(category.id)
          : null,
      onMoveToRoot: category.parentId != null && widget.onCategoryMove != null
          ? () => widget.onCategoryMove!(category.id, null)
          : null,
    );

    if (widget.onCategoryMove != null || widget.onCategoryReorder != null) {
      categoryItem = _buildDraggableCategory(category, categoryItem);
    }

    if (widget.onCategoryMove != null) {
      categoryItem = _buildCategoryDragTarget(theme, category, categoryItem);
    }

    categoryItem =
        _buildImageDropTarget(categoryId: category.id, child: categoryItem);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        categoryItem,
        if (hasChildren && isExpanded)
          ...children
              .map((child) => _buildCategoryNode(theme, child, depth + 1)),
      ],
    );
  }

  Widget _buildDraggableCategory(GalleryCategory category, Widget child) {
    final theme = Theme.of(context);

    return Draggable<GalleryCategory>(
      data: category,
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
                  category.displayName,
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
        setState(() => _hoveredCategoryId = null);
      },
      child: child,
    );
  }

  Widget _buildCategoryDragTarget(
    ThemeData theme,
    GalleryCategory targetCategory,
    Widget child,
  ) {
    return DragTarget<GalleryCategory>(
      onWillAcceptWithDetails: (details) {
        final draggedCategory = details.data;
        if (draggedCategory.id == targetCategory.id) return false;
        if (widget.categories
            .wouldCreateCycle(draggedCategory.id, targetCategory.id)) {
          return false;
        }
        if (draggedCategory.parentId == targetCategory.id) return false;
        return true;
      },
      onAcceptWithDetails: (details) {
        HapticFeedback.heavyImpact();
        widget.onCategoryMove?.call(details.data.id, targetCategory.id);
        setState(() {
          _expandedIds.add(targetCategory.id);
          _hoveredCategoryId = null;
        });
        _autoExpandTimer?.cancel();
      },
      onMove: (details) {
        if (_hoveredCategoryId != targetCategory.id) {
          setState(() => _hoveredCategoryId = targetCategory.id);
          final hasChildren =
              widget.categories.getChildren(targetCategory.id).isNotEmpty;
          if (hasChildren && !_expandedIds.contains(targetCategory.id)) {
            _startAutoExpandTimer(targetCategory.id);
          }
        }
      },
      onLeave: (_) {
        if (_hoveredCategoryId == targetCategory.id) {
          setState(() => _hoveredCategoryId = null);
          _autoExpandTimer?.cancel();
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
    required String? categoryId,
    required Widget child,
  }) {
    if (widget.onImageDrop == null) return child;

    // 构建 DragTarget 用于 Flutter 原生拖拽
    final dragTarget = DragTarget<LocalImageRecord>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) {
        HapticFeedback.heavyImpact();
        widget.onImageDrop?.call(details.data.path, categoryId);
      },
      builder: (context, candidateData, rejectedData) {
        final isAccepting = candidateData.isNotEmpty;
        final isSuperDragging = _superDraggingCategoryIds.contains(
          categoryId ?? '__root__',
        );
        final showDropEffect = isAccepting || isSuperDragging;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: showDropEffect
                ? LinearGradient(
                    colors: [
                      Colors.green.withOpacity(0.15),
                      Colors.green.withOpacity(0.05),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            border: showDropEffect
                ? const Border(left: BorderSide(color: Colors.green, width: 4))
                : null,
            borderRadius: showDropEffect ? BorderRadius.circular(8) : null,
          ),
          child: child,
        );
      },
    );

    // 使用 DropRegion 包裹 DragTarget，支持 super_drag_and_drop 跨应用拖拽
    return DropRegion(
      formats: const [Formats.fileUri],
      onDropOver: (event) {
        if (event.session.allowedOperations.contains(DropOperation.copy)) {
          final key = categoryId ?? '__root__';
          if (!_superDraggingCategoryIds.contains(key)) {
            setState(() => _superDraggingCategoryIds.add(key));
          }
          return DropOperation.copy;
        }
        return DropOperation.none;
      },
      onDropLeave: (event) {
        final key = categoryId ?? '__root__';
        if (_superDraggingCategoryIds.contains(key)) {
          setState(() => _superDraggingCategoryIds.remove(key));
        }
      },
      onPerformDrop: (event) async {
        final key = categoryId ?? '__root__';
        if (_superDraggingCategoryIds.contains(key)) {
          setState(() => _superDraggingCategoryIds.remove(key));
        }

        // 处理拖拽的文件
        for (final item in event.session.items) {
          final reader = item.dataReader;
          if (reader == null) continue;

          // 读取文件 URI
          if (reader.canProvide(Formats.fileUri)) {
            final filePath = await _getFilePathFromUri(reader);
            if (filePath != null) {
              HapticFeedback.heavyImpact();
              widget.onImageDrop?.call(filePath, categoryId);
            }
          }
        }
      },
      child: dragTarget,
    );
  }

  /// 从 DataReader 中提取文件路径
  Future<String?> _getFilePathFromUri(DataReader reader) async {
    final completer = Completer<String?>();

    final progress = reader.getValue(
      Formats.fileUri,
      (uri) {
        if (!completer.isCompleted) {
          if (uri == null) {
            completer.complete(null);
            return;
          }
          try {
            final filePath = uri.toFilePath();
            completer.complete(filePath);
          } catch (e) {
            completer.complete(null);
          }
        }
      },
      onError: (e) {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      },
    );

    if (progress == null) {
      return null;
    }

    // 添加超时保护
    try {
      return await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
    } catch (e) {
      return null;
    }
  }
}

class _CategoryItem extends StatefulWidget {
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
  final VoidCallback? onAddSubCategory;
  final VoidCallback? onMoveToRoot;

  const _CategoryItem({
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
    this.onAddSubCategory,
    this.onMoveToRoot,
  });

  @override
  State<_CategoryItem> createState() => _CategoryItemState();
}

class _CategoryItemState extends State<_CategoryItem> {
  bool _isHovering = false;
  bool _isEditing = false;
  late TextEditingController _editController;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.label);
  }

  @override
  void didUpdateWidget(covariant _CategoryItem oldWidget) {
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
                  Icon(
                    widget.icon,
                    size: 18,
                    color: widget.iconColor ??
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
                            onTapOutside: (_) =>
                                setState(() => _isEditing = false),
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
                  if (_isHovering && widget.onRename != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.drag_indicator,
                        size: 14,
                        color: theme.colorScheme.outline.withOpacity(0.5),
                      ),
                    ),
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
            onTap: () => Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) setState(() => _isEditing = true);
            }),
            child: const Row(
              children: [
                Icon(Icons.edit, size: 18),
                SizedBox(width: 8),
                Text('重命名'),
              ],
            ),
          ),
        if (widget.onAddSubCategory != null)
          PopupMenuItem(
            onTap: widget.onAddSubCategory,
            child: const Row(
              children: [
                Icon(Icons.create_new_folder, size: 18),
                SizedBox(width: 8),
                Text('新建子分类'),
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
