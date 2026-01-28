import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/tag_library/tag_library_entry.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/themed_divider.dart';

/// 词库条目卡片
class EntryCard extends StatefulWidget {
  final TagLibraryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onAddToFixed;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;
  final VoidCallback? onEdit;

  /// 是否启用拖拽到分类功能
  final bool enableDrag;

  const EntryCard({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onAddToFixed,
    required this.onDelete,
    required this.onToggleFavorite,
    this.onEdit,
    this.enableDrag = false,
  });

  @override
  State<EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends State<EntryCard> {
  bool _isHovering = false;
  bool _isDragging = false;
  OverlayEntry? _overlayEntry;
  final _layerLink = LayerLink();

  @override
  void dispose() {
    _hidePreviewOverlay();
    super.dispose();
  }

  void _showPreviewOverlay() {
    if (_overlayEntry != null) return;

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final cardSize = renderBox.size;
    final cardPosition = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => _EntryPreviewOverlay(
        entry: widget.entry,
        layerLink: _layerLink,
        cardSize: cardSize,
        cardPosition: cardPosition,
        onDismiss: _hidePreviewOverlay,
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  void _hidePreviewOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = widget.entry;

    Widget cardContent = CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) {
          if (!_isDragging) {
            setState(() => _isHovering = true);
            // 延迟显示预览，避免快速划过时闪烁
            Future.delayed(const Duration(milliseconds: 500), () {
              if (_isHovering && mounted && !_isDragging) {
                _showPreviewOverlay();
              }
            });
          }
        },
        onExit: (_) {
          setState(() => _isHovering = false);
          _hidePreviewOverlay();
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isHovering
                    ? theme.colorScheme.primary.withOpacity(0.5)
                    : theme.colorScheme.outlineVariant.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: _isHovering
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                        spreadRadius: 2,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 预览图区域
                Expanded(
                  flex: 3,
                  child: _buildThumbnail(theme, entry),
                ),

                // 信息区域
                Expanded(
                  flex: 2,
                  child: _buildInfo(theme, entry),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // 如果启用拖拽，包装为 Draggable
    if (widget.enableDrag) {
      cardContent = Draggable<TagLibraryEntry>(
        data: entry,
        feedback: _buildDragFeedback(theme, entry),
        childWhenDragging: Opacity(
          opacity: 0.4,
          child: cardContent,
        ),
        onDragStarted: () {
          HapticFeedback.mediumImpact();
          _hidePreviewOverlay();
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
        child: cardContent,
      );
    }

    return cardContent;
  }

  /// 构建拖拽反馈UI
  Widget _buildDragFeedback(ThemeData theme, TagLibraryEntry entry) {
    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(12),
      color: theme.colorScheme.surfaceContainerHigh,
      shadowColor: Colors.black54,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.primary.withOpacity(0.5),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 缩略图
            if (entry.hasThumbnail)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(entry.thumbnail!),
                  height: 80,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.image_outlined,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 60,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(
                    Icons.library_books,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            // 名称
            Text(
              entry.displayName,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // 提示
            Row(
              children: [
                Icon(
                  Icons.drive_file_move_outline,
                  size: 12,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '拖到左侧分类归档',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.outline,
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(ThemeData theme, TagLibraryEntry entry) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 背景
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
          child: entry.hasThumbnail
              ? Image.file(
                  File(entry.thumbnail!),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) =>
                      _buildPlaceholder(theme),
                )
              : _buildPlaceholder(theme),
        ),

        // 悬停遮罩和操作按钮
        if (_isHovering)
          Positioned.fill(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 添加到固定词按钮
                      _ActionButton(
                        icon: Icons.add_box_outlined,
                        tooltip: context.l10n.tagLibrary_addToFixed,
                        onTap: widget.onAddToFixed,
                      ),
                      const SizedBox(width: 8),
                      if (widget.onEdit != null)
                        _ActionButton(
                          icon: Icons.edit_outlined,
                          tooltip: context.l10n.common_edit,
                          onTap: widget.onEdit!,
                        ),
                      if (widget.onEdit != null) const SizedBox(width: 8),
                      _ActionButton(
                        icon: Icons.content_copy,
                        tooltip: context.l10n.common_copy,
                        onTap: () => _copyToClipboard(entry.content),
                      ),
                      const SizedBox(width: 8),
                      _ActionButton(
                        icon: Icons.delete_outline,
                        tooltip: context.l10n.common_delete,
                        onTap: widget.onDelete,
                        isDestructive: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // 右上角收藏按钮 - 红心样式
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: widget.onToggleFavorite,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: entry.isFavorite
                    ? Colors.red.shade400
                    : Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: entry.isFavorite
                        ? Colors.red.shade400.withOpacity(0.4)
                        : Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    spreadRadius: entry.isFavorite ? 2 : 0,
                  ),
                ],
              ),
              child: Icon(
                entry.isFavorite ? Icons.favorite : Icons.favorite_border,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 32,
          color: theme.colorScheme.outline.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildInfo(ThemeData theme, TagLibraryEntry entry) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 名称
          Text(
            entry.displayName,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),

          // 内容预览
          Expanded(
            child: Text(
              entry.contentPreview,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // 底部信息
          Row(
            children: [
              if (entry.useCount > 0) ...[
                Icon(
                  Icons.repeat,
                  size: 12,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: 4),
                Text(
                  entry.useCount.toString(),
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              if (entry.tags.isNotEmpty)
                Expanded(
                  child: Text(
                    entry.tags.take(2).join(', '),
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.outline,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String content) {
    Clipboard.setData(ClipboardData(text: content));
    AppToast.success(context, context.l10n.common_copied);
  }
}

/// 操作按钮
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withOpacity(0.9),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              size: 20,
              color: isDestructive ? Colors.red : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}

/// 悬停预览浮层
class _EntryPreviewOverlay extends StatelessWidget {
  final TagLibraryEntry entry;
  final LayerLink layerLink;
  final Size cardSize;
  final Offset cardPosition;
  final VoidCallback onDismiss;

  const _EntryPreviewOverlay({
    required this.entry,
    required this.layerLink,
    required this.cardSize,
    required this.cardPosition,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;

    // 计算浮层位置 - 默认在卡片右侧，如果空间不够则放左侧
    const previewWidth = 320.0;
    const previewMaxHeight = 400.0;

    // 检查右侧是否有足够空间
    final rightSpace = screenSize.width - (cardPosition.dx + cardSize.width);
    final showOnRight = rightSpace >= previewWidth + 16;

    return Positioned(
      left: 0,
      top: 0,
      child: CompositedTransformFollower(
        link: layerLink,
        showWhenUnlinked: false,
        offset: Offset(
          showOnRight ? cardSize.width + 8 : -previewWidth - 8,
          0,
        ),
        child: MouseRegion(
          onExit: (_) => onDismiss(),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.surfaceContainerHigh,
            child: Container(
              width: previewWidth,
              constraints: const BoxConstraints(maxHeight: previewMaxHeight),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 预览图
                    if (entry.hasThumbnail)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        child: Image.file(
                          File(entry.thumbnail!),
                          width: previewWidth,
                          height: 180,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              const SizedBox.shrink(),
                        ),
                      ),

                    // 内容区域
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 名称
                          Text(
                            entry.displayName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 8),
                          const ThemedDivider(height: 1),
                          const SizedBox(height: 8),

                          // 完整内容
                          Text(
                            entry.content,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                            maxLines: 8,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 12),

                          // 标签
                          if (entry.tags.isNotEmpty) ...[
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: entry.tags.map((tag) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer
                                        .withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    tag,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color:
                                          theme.colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // 统计信息
                          Row(
                            children: [
                              Icon(
                                Icons.repeat,
                                size: 14,
                                color: theme.colorScheme.outline,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                context.l10n
                                    .tagLibrary_useCount(entry.useCount),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                              if (entry.lastUsedAt != null) ...[
                                const SizedBox(width: 16),
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: theme.colorScheme.outline,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatLastUsed(context, entry.lastUsedAt!),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
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

  String _formatLastUsed(BuildContext context, DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return context.l10n.common_today;
    } else if (diff.inDays == 1) {
      return context.l10n.common_yesterday;
    } else if (diff.inDays < 7) {
      return context.l10n.common_daysAgo(diff.inDays);
    } else {
      return DateFormat.MMMd().format(date);
    }
  }
}
