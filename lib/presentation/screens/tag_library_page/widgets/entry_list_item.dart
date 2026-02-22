import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/tag_library/tag_library_entry.dart';
import '../../../widgets/common/app_toast.dart';

/// 词库条目列表项
class EntryListItem extends StatefulWidget {
  final TagLibraryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;
  final VoidCallback? onEdit;

  /// 所属分类名称
  final String? categoryName;

  /// 是否启用拖拽到分类功能
  final bool enableDrag;

  // ===== 批量选择相关属性 =====
  /// 是否处于选择模式
  final bool isSelectionMode;

  /// 是否被选中
  final bool isSelected;

  /// 切换选择状态回调
  final VoidCallback? onToggleSelection;

  const EntryListItem({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onDelete,
    required this.onToggleFavorite,
    this.onEdit,
    this.categoryName,
    this.enableDrag = false,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onToggleSelection,
  });

  @override
  State<EntryListItem> createState() => _EntryListItemState();
}

class _EntryListItemState extends State<EntryListItem> {
  bool _isHovering = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = widget.entry;

    // 选择模式下的背景色
    final backgroundColor = widget.isSelected
        ? theme.colorScheme.primaryContainer.withOpacity(0.3)
        : (_isHovering && !widget.isSelectionMode
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.surfaceContainerHigh);

    // 选择模式下的边框
    final borderColor =
        widget.isSelected ? theme.colorScheme.primary : Colors.transparent;

    Widget itemContent = MouseRegion(
      onEnter: (_) {
        if (!_isDragging && !widget.isSelectionMode) {
          setState(() => _isHovering = true);
        }
      },
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        // 选择模式下点击切换选择，否则打开详情
        onTap: widget.isSelectionMode ? widget.onToggleSelection : widget.onTap,
        // 长按进入选择模式并选中
        onLongPress: widget.isSelectionMode
            ? null
            : () {
                HapticFeedback.mediumImpact();
                widget.onToggleSelection?.call();
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          padding: const EdgeInsets.all(12),
          // 悬停时微微上移（非选择模式）
          transform: widget.isSelectionMode
              ? null
              : (Matrix4.identity()..translate(0.0, _isHovering ? -2.0 : 0.0)),
          decoration: BoxDecoration(
            // 背景色 - 选中时使用主色容器
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            // 选中时显示边框
            border: Border.all(
              color: borderColor,
              width: widget.isSelected ? 2 : 0,
            ),
            // 阴影（非选择模式）
            boxShadow: _isHovering && !widget.isSelectionMode
                ? [
                    // 主阴影 - 带主题色
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                    // 中层阴影
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                    // 底层阴影
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                    // 静态阴影
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Row(
            children: [
              // 选择模式下的复选框
              if (widget.isSelectionMode) ...[
                _SelectionCheckbox(
                  isSelected: widget.isSelected,
                  onTap: widget.onToggleSelection,
                ),
                const SizedBox(width: 12),
              ],

              // 预览图
              _buildThumbnail(theme, entry),
              const SizedBox(width: 16),

              // 信息
              Expanded(
                child: _buildInfo(theme, entry),
              ),

              // 操作按钮（非选择模式悬停时显示）
              if (!widget.isSelectionMode && _isHovering) ...[
                const SizedBox(width: 12),
                _buildActions(theme),
              ],
            ],
          ),
        ),
      ),
    );

    // 如果启用拖拽，包装为 Draggable
    if (widget.enableDrag) {
      itemContent = Draggable<TagLibraryEntry>(
        data: entry,
        feedback: _buildDragFeedback(theme, entry),
        childWhenDragging: Opacity(
          opacity: 0.4,
          child: itemContent,
        ),
        onDragStarted: () {
          HapticFeedback.mediumImpact();
          setState(() {
            _isDragging = true;
            _isHovering = false;
          });
        },
        onDragEnd: (_) {
          setState(() {
            _isDragging = false;
          });
        },
        child: itemContent,
      );
    }

    return itemContent;
  }

  /// 构建拖拽反馈UI
  Widget _buildDragFeedback(ThemeData theme, TagLibraryEntry entry) {
    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(10),
      color: theme.colorScheme.surfaceContainerHigh,
      shadowColor: Colors.black54,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: theme.colorScheme.primary.withOpacity(0.5),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            // 缩略图
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 48,
                height: 48,
                child: entry.hasThumbnail
                    ? Image.file(
                        File(entry.thumbnail!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.image_outlined,
                            size: 20,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      )
                    : Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.library_books,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // 信息
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.displayName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.drive_file_move_outline,
                        size: 12,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '拖到左侧分类归档',
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(ThemeData theme, TagLibraryEntry entry) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 64,
        height: 64,
        child: entry.hasThumbnail
            ? Image.file(
                File(entry.thumbnail!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) =>
                    _buildPlaceholder(theme),
              )
            : _buildPlaceholder(theme),
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 24,
          color: theme.colorScheme.outline.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildInfo(ThemeData theme, TagLibraryEntry entry) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 名称行
        Row(
          children: [
            // 收藏图标 - 红心徽章
            if (entry.isFavorite)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.red.shade400,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite,
                  size: 12,
                  color: Colors.white,
                ),
              ),

            // 名称
            Expanded(
              child: Text(
                entry.displayName,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),

        const SizedBox(height: 4),

        // 内容预览
        Text(
          entry.contentPreview,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 6),

        // 统计信息行：分类 + 标签数 + 使用次数
        Row(
          children: [
            // 分类标签（始终显示，无分类时显示根目录）
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder_outlined,
                    size: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.categoryName?.isNotEmpty == true
                        ? widget.categoryName!
                        : context.l10n.tagLibrary_rootCategory,
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 标签数量
            Icon(
              Icons.sell_outlined,
              size: 11,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 2),
            Text(
              '${entry.promptTagCount}',
              style: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.outline,
              ),
            ),
            // 使用次数
            if (entry.useCount > 0) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.repeat,
                size: 11,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(width: 2),
              Text(
                '${entry.useCount}',
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ],
        ),

        // 标签
        if (entry.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children:
                entry.tags.take(4).map((tag) => _TagChip(tag: tag)).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildActions(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 收藏按钮 - 红心样式，无文字
        widget.entry.isFavorite
            ? Material(
                color: Colors.red.shade400,
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  onTap: widget.onToggleFavorite,
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.favorite,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
            : _buildActionIcon(
                theme,
                Icons.favorite_border,
                context.l10n.tagLibrary_addFavorite,
                widget.onToggleFavorite,
              ),
        const SizedBox(width: 4),
        // 编辑按钮
        if (widget.onEdit != null) ...[
          _buildActionIcon(
            theme,
            Icons.edit_outlined,
            context.l10n.common_edit,
            widget.onEdit!,
          ),
          const SizedBox(width: 4),
        ],
        // 复制
        _buildActionIcon(
          theme,
          Icons.content_copy,
          context.l10n.common_copy,
          () => _copyToClipboard(widget.entry.content),
        ),
        const SizedBox(width: 4),
        // 删除
        _buildActionIcon(
          theme,
          Icons.delete_outline,
          context.l10n.common_delete,
          widget.onDelete,
          isDestructive: true,
        ),
      ],
    );
  }

  Widget _buildActionIcon(
    ThemeData theme,
    IconData icon,
    String tooltip,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              icon,
              size: 18,
              color: isDestructive
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(String content) {
    Clipboard.setData(ClipboardData(text: content));
    AppToast.success(context, context.l10n.common_copied);
  }
}

/// 标签小芯片
class _TagChip extends StatelessWidget {
  final String tag;

  const _TagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 10,
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

/// 选择复选框
class _SelectionCheckbox extends StatelessWidget {
  final bool isSelected;
  final VoidCallback? onTap;

  const _SelectionCheckbox({
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.surface.withOpacity(0.9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withOpacity(0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isSelected
            ? Icon(
                Icons.check,
                size: 16,
                color: theme.colorScheme.onPrimary,
              )
            : null,
      ),
    );
  }
}
