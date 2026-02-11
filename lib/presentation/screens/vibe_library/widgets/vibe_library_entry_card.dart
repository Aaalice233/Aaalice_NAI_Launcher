import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../widgets/common/animated_favorite_button.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/pro_context_menu.dart';

/// Vibe 库条目卡片组件（支持右键菜单和长按）
class VibeLibraryEntryCard extends StatefulWidget {
  final VibeLibraryEntry entry;
  final double itemWidth;
  final double aspectRatio;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback? onSelectionToggle;
  final VoidCallback? onLongPress;
  final VoidCallback? onDeleted;
  final void Function(VibeLibraryEntry)? onSendToGeneration;
  final void Function(VibeLibraryEntry)? onExport;
  final void Function(VibeLibraryEntry)? onEdit;
  final void Function(VibeLibraryEntry)? onFavoriteToggle;

  const VibeLibraryEntryCard({
    super.key,
    required this.entry,
    required this.itemWidth,
    required this.aspectRatio,
    this.selectionMode = false,
    this.isSelected = false,
    this.onSelectionToggle,
    this.onLongPress,
    this.onDeleted,
    this.onSendToGeneration,
    this.onExport,
    this.onEdit,
    this.onFavoriteToggle,
  });

  @override
  State<VibeLibraryEntryCard> createState() => _VibeLibraryEntryCardState();
}

class _VibeLibraryEntryCardState extends State<VibeLibraryEntryCard>
    with AutomaticKeepAliveClientMixin {
  Timer? _longPressTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  /// 显示上下文菜单
  void _showContextMenu([Offset? position]) {
    final menuPosition = position ?? const Offset(100, 100);

    final items = <ProMenuItem>[
      if (widget.onSendToGeneration != null)
        ProMenuItem(
          id: 'send_to_generation',
          label: '发送到生成',
          icon: Icons.send,
          onTap: () {
            widget.onSendToGeneration?.call(widget.entry);
          },
        ),
      if (widget.onExport != null)
        ProMenuItem(
          id: 'export',
          label: '导出',
          icon: Icons.download,
          onTap: () {
            widget.onExport?.call(widget.entry);
          },
        ),
      if (widget.onEdit != null)
        ProMenuItem(
          id: 'edit',
          label: '编辑',
          icon: Icons.edit,
          onTap: () {
            widget.onEdit?.call(widget.entry);
          },
        ),
      if (widget.onSendToGeneration != null ||
          widget.onExport != null ||
          widget.onEdit != null)
        const ProMenuItem.divider(),
      ProMenuItem(
        id: 'copy_strength',
        label: '复制 Strength',
        icon: Icons.tune,
        onTap: () {
          Clipboard.setData(
            ClipboardData(text: widget.entry.strength.toStringAsFixed(2)),
          );
          if (mounted) {
            AppToast.success(context, 'Strength 已复制');
          }
        },
      ),
      ProMenuItem(
        id: 'copy_info_extracted',
        label: '复制 Info Extracted',
        icon: Icons.auto_fix_high,
        onTap: () {
          Clipboard.setData(
            ClipboardData(text: widget.entry.infoExtracted.toStringAsFixed(2)),
          );
          if (mounted) {
            AppToast.success(context, 'Info Extracted 已复制');
          }
        },
      ),
      const ProMenuItem.divider(),
      ProMenuItem(
        id: 'delete',
        label: '删除',
        icon: Icons.delete_outline,
        isDanger: true,
        onTap: () {
          if (mounted) {
            _showDeleteConfirmationDialog();
          }
        },
      ),
    ];

    Navigator.of(context).push(
      _ContextMenuRoute(
        position: menuPosition,
        items: items,
        onSelect: (item) {
          // Item onTap is already called
        },
      ),
    );
  }

  /// 显示删除确认对话框
  Future<void> _showDeleteConfirmationDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text(
          '确定要删除 Vibe 条目「${widget.entry.displayName}」吗？\n\n此操作不可恢复。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      widget.onDeleted?.call();
    }
  }

  /// 获取缩略图数据
  Uint8List? get _thumbnailData {
    if (widget.entry.thumbnail != null &&
        widget.entry.thumbnail!.isNotEmpty) {
      return widget.entry.thumbnail;
    }
    if (widget.entry.vibeThumbnail != null &&
        widget.entry.vibeThumbnail!.isNotEmpty) {
      return widget.entry.vibeThumbnail;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cacheWidth = (widget.itemWidth * pixelRatio).toInt();
    final maxHeight = widget.itemWidth * 3;
    final itemHeight =
        (widget.itemWidth / widget.aspectRatio).clamp(0.0, maxHeight);

    // 构建卡片主体内容
    final cardContent = RepaintBoundary(
      child: MouseRegion(
        cursor: widget.selectionMode
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: GestureDetector(
          // 点击
          onTap: () {
            if (widget.selectionMode) {
              widget.onSelectionToggle?.call();
            }
          },

          // 桌面端：右键菜单
          onSecondaryTapDown: (details) {
            if (!widget.selectionMode) {
              _showContextMenu(details.globalPosition);
            }
          },

          // 移动端：长按
          onLongPressStart: (details) {
            if (!widget.selectionMode) {
              _longPressTimer = Timer(const Duration(milliseconds: 500), () {
                if (widget.onLongPress != null) {
                  widget.onLongPress!();
                } else {
                  _showContextMenu(details.globalPosition);
                }
              });
            }
          },
          onLongPressEnd: (details) {
            _longPressTimer?.cancel();
          },
          onLongPressCancel: () {
            _longPressTimer?.cancel();
          },

          child: Stack(
            children: [
              SizedBox(
                width: widget.itemWidth,
                height: itemHeight,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                        color: Colors.black.withOpacity(0.12),
                      ),
                    ],
                    border: widget.isSelected
                        ? Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 3,
                          )
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        // 缩略图
                        _thumbnailData != null
                            ? Image.memory(
                                _thumbnailData!,
                                cacheWidth: cacheWidth,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                gaplessPlayback: true,
                                frameBuilder: (
                                  context,
                                  child,
                                  frame,
                                  wasSynchronouslyLoaded,
                                ) {
                                  if (wasSynchronouslyLoaded) return child;
                                  return AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: frame != null
                                        ? child
                                        : _ImagePlaceholder(
                                            width: widget.itemWidth,
                                            aspectRatio: widget.aspectRatio,
                                          ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return _ImageError(
                                    width: widget.itemWidth,
                                    aspectRatio: widget.aspectRatio,
                                  );
                                },
                              )
                            : _ImagePlaceholder(
                                width: widget.itemWidth,
                                aspectRatio: widget.aspectRatio,
                              ),
                        // 底部渐变遮罩和信息
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.8),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            padding: const EdgeInsets.fromLTRB(10, 20, 10, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 名称
                                Text(
                                  widget.entry.displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                // Strength 进度条
                                _buildProgressBar(
                                  context,
                                  label: 'Strength',
                                  value: widget.entry.strength,
                                  color: Colors.blue,
                                ),
                                const SizedBox(height: 4),
                                // Info Extracted 进度条
                                _buildProgressBar(
                                  context,
                                  label: 'Info',
                                  value: widget.entry.infoExtracted,
                                  color: Colors.green,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // 预编码标识
                        if (widget.entry.isPreEncoded)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 2),
                                  Text(
                                    '预编码',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              // Selection Overlay and Checkbox
              if (widget.selectionMode)
                _SelectionIndicator(
                  isSelected: widget.isSelected,
                ),
              // Hover overlay (only shown when not in selection mode)
              if (!widget.selectionMode)
                _HoverOverlay(
                  entry: widget.entry,
                  onFavoriteToggle: widget.onFavoriteToggle != null
                      ? () => widget.onFavoriteToggle!(widget.entry)
                      : null,
                  onSendToGeneration: widget.onSendToGeneration != null
                      ? () => widget.onSendToGeneration!(widget.entry)
                      : null,
                  onExport: widget.onExport != null
                      ? () => widget.onExport!(widget.entry)
                      : null,
                  onEdit: widget.onEdit != null
                      ? () => widget.onEdit!(widget.entry)
                      : null,
                  onDelete: () => _showDeleteConfirmationDialog(),
                ),
            ],
          ),
        ),
      ),
    );

    // 包装为 Draggable，支持拖拽到生成页面
    if (!widget.selectionMode) {
      return Draggable<VibeLibraryEntry>(
        data: widget.entry,
        feedback: _buildDragFeedback(context, itemHeight),
        childWhenDragging: Opacity(
          opacity: 0.4,
          child: cardContent,
        ),
        onDragStarted: HapticFeedback.mediumImpact,
        child: cardContent,
      );
    }

    return cardContent;
  }

  /// 构建拖拽时的反馈组件
  Widget _buildDragFeedback(BuildContext context, double height) {
    final theme = Theme.of(context);
    final thumbnailData = _thumbnailData;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: Colors.transparent,
      child: Container(
        width: widget.itemWidth,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // 缩略图
              if (thumbnailData != null)
                Image.memory(
                  thumbnailData,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                )
              else
                Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Center(
                    child: Icon(
                      Icons.auto_fix_high,
                      size: 32,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
              // 名称标签
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.8),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
                  child: Text(
                    widget.entry.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // 拖拽指示器边框
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.8),
                      width: 3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建进度条
  Widget _buildProgressBar(
    BuildContext context, {
    required String label,
    required double value,
    required Color color,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 9,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${(value * 100).toInt()}%',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

/// 图片加载占位符（带 shimmer 效果）
class _ImagePlaceholder extends StatelessWidget {
  final double width;
  final double aspectRatio;

  const _ImagePlaceholder({
    required this.width,
    required this.aspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width / aspectRatio,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
        ),
      ),
    );
  }
}

/// 图片加载错误显示
class _ImageError extends StatelessWidget {
  final double width;
  final double aspectRatio;

  const _ImageError({
    required this.width,
    required this.aspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width / aspectRatio,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            size: 32,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 4),
          Text(
            '加载失败',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

/// Selection indicator widget
class _SelectionIndicator extends StatefulWidget {
  final bool isSelected;

  const _SelectionIndicator({
    required this.isSelected,
  });

  @override
  State<_SelectionIndicator> createState() => _SelectionIndicatorState();
}

class _SelectionIndicatorState extends State<_SelectionIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    if (widget.isSelected) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _SelectionIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        // Selection Overlay
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? colorScheme.primary.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        // Checkbox
        Positioned(
          top: 8,
          right: 8,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isSelected
                    ? colorScheme.primary
                    : Colors.black.withOpacity(0.5),
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.check,
                size: 18,
                color: widget.isSelected
                    ? colorScheme.onPrimary
                    : Colors.transparent,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 悬浮操作按钮组件
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool isDanger;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(left: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDanger
                  ? colorScheme.error.withOpacity(0.9)
                  : Colors.white.withOpacity(0.9),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 16,
              color: isDanger ? colorScheme.onError : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}

/// Hover overlay widget with separate state management
class _HoverOverlay extends StatefulWidget {
  final VibeLibraryEntry entry;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onSendToGeneration;
  final VoidCallback? onExport;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _HoverOverlay({
    required this.entry,
    this.onFavoriteToggle,
    this.onSendToGeneration,
    this.onExport,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<_HoverOverlay> createState() => _HoverOverlayState();
}

class _HoverOverlayState extends State<_HoverOverlay> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Stack(
        children: [
          // 主体内容
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            transform: Matrix4.identity()..scale(_isHovering ? 1.02 : 1.0),
            transformAlignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: _isHovering
                  ? Border.all(
                      color: colorScheme.primary.withOpacity(0.25),
                      width: 2,
                    )
                  : null,
              boxShadow: _isHovering
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: _isHovering ? 1.0 : 0.0,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Colors.transparent, Colors.black87],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.3, 1.0],
                  ),
                ),
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.entry.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.tune,
                          size: 11,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'S: ${widget.entry.strength.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.auto_fix_high,
                          size: 11,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'I: ${widget.entry.infoExtracted.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    if (widget.entry.tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: widget.entry.tags.take(3).map((tag) {
                            final displayTag = tag.length > 12
                                ? '${tag.substring(0, 12)}...'
                                : tag;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                displayTag,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // 左上角收藏按钮（悬浮时显示）
          if (_isHovering && widget.onFavoriteToggle != null)
            Positioned(
              top: 8,
              left: 8,
              child: CardFavoriteButton(
                isFavorite: widget.entry.isFavorite,
                onToggle: widget.onFavoriteToggle,
                size: 18,
              ),
            ),
          // 右上角操作按钮行（悬浮时显示）
          if (_isHovering)
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.onSendToGeneration != null)
                    _ActionButton(
                      icon: Icons.send,
                      tooltip: '发送到生成',
                      onTap: widget.onSendToGeneration,
                    ),
                  if (widget.onExport != null)
                    _ActionButton(
                      icon: Icons.download,
                      tooltip: '导出',
                      onTap: widget.onExport,
                    ),
                  if (widget.onEdit != null)
                    _ActionButton(
                      icon: Icons.edit,
                      tooltip: '编辑',
                      onTap: widget.onEdit,
                    ),
                  if (widget.onDelete != null)
                    _ActionButton(
                      icon: Icons.delete,
                      tooltip: '删除',
                      onTap: widget.onDelete,
                      isDanger: true,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Custom route for displaying ProContextMenu
class _ContextMenuRoute extends PopupRoute {
  final Offset position;
  final List<ProMenuItem> items;
  final void Function(ProMenuItem) onSelect;

  _ContextMenuRoute({
    required this.position,
    required this.items,
    required this.onSelect,
  });

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      removeLeft: true,
      removeRight: true,
      removeBottom: true,
      child: Builder(
        builder: (context) {
          // Calculate adjusted position to keep menu within screen bounds
          final screenSize = MediaQuery.of(context).size;
          const menuWidth = 180.0;
          final menuHeight = items.where((i) => !i.isDivider).length * 36.0 +
              items.where((i) => i.isDivider).length * 1.0;

          double left = position.dx;
          double top = position.dy;

          // Adjust horizontal position if menu goes off screen
          if (left + menuWidth > screenSize.width) {
            left = screenSize.width - menuWidth - 16;
          }

          // Adjust vertical position if menu goes off screen
          if (top + menuHeight > screenSize.height) {
            top = screenSize.height - menuHeight - 16;
          }

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => Navigator.of(context).pop(),
            child: Stack(
              children: [
                ProContextMenu(
                  position: Offset(left, top),
                  items: items,
                  onSelect: (item) {
                    onSelect(item);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        ),
        child: child,
      ),
    );
  }
}
