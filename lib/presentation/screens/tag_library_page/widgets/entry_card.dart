import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/tag_library/tag_library_entry.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/themed_divider.dart';
import '../../../widgets/common/thumbnail_display.dart';

/// 词库条目卡片 - 名称居中 + 互斥显示
///
/// 布局：
/// - 正常：名称水平垂直居中
/// - 悬浮：名称隐藏，操作按钮占满空间居中显示
class EntryCard extends StatefulWidget {
  final TagLibraryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;
  final VoidCallback? onEdit;
  final VoidCallback? onSend;

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

  const EntryCard({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onDelete,
    required this.onToggleFavorite,
    this.onEdit,
    this.onSend,
    this.categoryName,
    this.enableDrag = false,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onToggleSelection,
  });

  @override
  State<EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends State<EntryCard>
    with SingleTickerProviderStateMixin {
  bool _isHovering = false;
  bool _isDragging = false;
  OverlayEntry? _overlayEntry;
  final _layerLink = LayerLink();

  late final AnimationController _animationController;
  late final Animation<double> _elevationAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _elevationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _hidePreviewOverlay();
    _animationController.dispose();
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

  void _onEnter() {
    if (!_isDragging && !widget.isSelectionMode) {
      setState(() => _isHovering = true);
      _animationController.forward();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_isHovering && mounted && !_isDragging) {
          _showPreviewOverlay();
        }
      });
    }
  }

  void _onExit() {
    setState(() => _isHovering = false);
    _animationController.reverse();
    _hidePreviewOverlay();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = widget.entry;

    // 选中/悬停边框色
    final borderColor = widget.isSelected
        ? theme.colorScheme.primary
        : (_isHovering
            ? theme.colorScheme.primary.withOpacity(0.5)
            : Colors.transparent);

    // 构建卡片主体内容（在GestureDetector内）
    final cardBody = GestureDetector(
      onTap: widget.isSelectionMode ? widget.onToggleSelection : widget.onTap,
      onLongPress: widget.isSelectionMode
          ? null
          : () {
              HapticFeedback.mediumImpact();
              widget.onToggleSelection?.call();
            },
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  // 光晕效果
                  if (widget.isSelected || _isHovering)
                    BoxShadow(
                      color: widget.isSelected
                          ? theme.colorScheme.primary.withOpacity(0.5)
                          : theme.colorScheme.primary.withOpacity(0.25),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  // 悬浮阴影（动态）
                  BoxShadow(
                    color: Colors.black.withOpacity(
                      0.15 + (0.15 * _elevationAnimation.value),
                    ),
                    blurRadius: 10 + (12 * _elevationAnimation.value),
                    offset: Offset(
                      0,
                      4 + (8 * _elevationAnimation.value),
                    ),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 背景层（统一背景色，防止白边）
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.grey.shade800,
                    ),
                  ),
                  // 内容层（带ClipRRect）
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // 1. 背景图片
                        _buildBackgroundImage(entry),

                        // 2. 轻微暗化遮罩（仅当有缩略图时显示）
                        if (entry.hasThumbnail) _buildDarkenOverlay(),

                        // 3. 内容区域（仅显示名称，按钮移到外层）
                        if (!widget.isSelectionMode && !_isHovering)
                          _buildNameArea(theme, entry),

                        // 4. 收藏图标（常驻显示在右上角，仅非选择模式、非悬浮且已收藏时）
                        if (!widget.isSelectionMode &&
                            !_isHovering &&
                            widget.entry.isFavorite)
                          const Positioned(
                            top: 8,
                            right: 8,
                            child: _FavoriteIndicator(),
                          ),

                        // 5. 选择模式 Checkbox（右上角）
                        if (widget.isSelectionMode)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: _SelectionCheckbox(
                              isSelected: widget.isSelected,
                              onTap: widget.onToggleSelection,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // 边框层（放在最上层）
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: borderColor,
                        width: widget.isSelected ? 2.5 : 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    // 外层包装：MouseRegion + 悬浮按钮层
    Widget cardContent = CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) => _onEnter(),
        onExit: (_) => _onExit(),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            // 卡片主体（可点击）
            cardBody,

            // 悬浮按钮层（在GestureDetector外面，独立响应事件）
            if (!widget.isSelectionMode && _isHovering)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                    child: _buildFloatingButtons(theme, entry),
                  ),
                ),
              ),
          ],
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
          _animationController.reverse();
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

  /// 构建背景图片
  /// 使用固定尺寸 200x80，与裁剪对话框的比例一致
  Widget _buildBackgroundImage(TagLibraryEntry entry) {
    if (entry.hasThumbnail && entry.thumbnail != null) {
      return ThumbnailDisplay(
        imagePath: entry.thumbnail!,
        offsetX: entry.thumbnailOffsetX,
        offsetY: entry.thumbnailOffsetY,
        scale: entry.thumbnailScale,
        width: 200,
        height: 80,
        borderRadius: BorderRadius.circular(12),
      );
    }
    return _buildPlaceholder();
  }

  /// 构建占位图
  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey.shade700,
            Colors.grey.shade900,
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          size: 32,
          color: Colors.white38,
        ),
      ),
    );
  }

  /// 构建轻微暗化遮罩
  Widget _buildDarkenOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.35),
    );
  }

  /// 构建名称显示区域
  Widget _buildNameArea(ThemeData theme, TagLibraryEntry entry) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          entry.displayName,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.left,
        ),
      ),
    );
  }

  /// 构建悬浮操作按钮
  Widget _buildFloatingButtons(ThemeData theme, TagLibraryEntry entry) {
    final l10n = context.l10n;
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ActionIcon(
            icon: Icons.delete_outline,
            tooltip: l10n.common_delete,
            onTap: widget.onDelete,
            isDestructive: true,
          ),
          const SizedBox(width: 8),
          if (widget.onEdit != null)
            _ActionIcon(
              icon: Icons.edit_outlined,
              tooltip: l10n.common_edit,
              onTap: widget.onEdit!,
            ),
          if (widget.onEdit != null) const SizedBox(width: 8),
          _ActionIcon(
            icon: entry.isFavorite ? Icons.favorite : Icons.favorite_border,
            tooltip: entry.isFavorite
                ? l10n.common_unfavorite
                : l10n.common_favorite,
            onTap: widget.onToggleFavorite,
            color: entry.isFavorite ? Colors.redAccent : null,
          ),
          const SizedBox(width: 8),
          _ActionIcon(
            icon: Icons.content_copy,
            tooltip: l10n.common_copy,
            onTap: () => _copyToClipboard(entry.content),
          ),
        ],
      ),
    );
  }

  /// 构建拖拽反馈UI
  Widget _buildDragFeedback(ThemeData theme, TagLibraryEntry entry) {
    return Material(
      elevation: 16,
      borderRadius: BorderRadius.circular(16),
      color: Colors.transparent,
      shadowColor: Colors.black54,
      child: Container(
        width: 200,
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.primary.withOpacity(0.8),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 背景图
              if (entry.hasThumbnail && entry.thumbnail != null)
                ThumbnailDisplay(
                  imagePath: entry.thumbnail!,
                  offsetX: entry.thumbnailOffsetX,
                  offsetY: entry.thumbnailOffsetY,
                  scale: entry.thumbnailScale,
                  width: 200,
                  height: 80,
                )
              else
                _buildPlaceholder(),
              // 轻微暗化
              _buildDarkenOverlay(),
              // 拖拽提示
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.drive_file_move_outline,
                        size: 12,
                        color: theme.colorScheme.onPrimary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '移到分类',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 名称（靠左）
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    entry.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 20,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 8,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                  ),
                ),
              ),
            ],
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

/// 操作图标按钮（带悬浮动效和Tooltip）
class _ActionIcon extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;
  final Color? color;
  final String tooltip;

  const _ActionIcon({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.isDestructive = false,
    this.color,
  });

  @override
  State<_ActionIcon> createState() => _ActionIconState();
}

class _ActionIconState extends State<_ActionIcon> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = Colors.white.withOpacity(0.15);
    final hoverBgColor = Colors.white.withOpacity(0.35);

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 150),
            scale: _isHovering ? 1.15 : 1.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isHovering ? hoverBgColor : bgColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: _isHovering
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                widget.icon,
                size: 20,
                color: widget.color ??
                    (widget.isDestructive ? Colors.redAccent : Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 收藏指示器（常驻小红心）
class _FavoriteIndicator extends StatelessWidget {
  const _FavoriteIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.redAccent,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: const Icon(
        Icons.favorite,
        size: 12,
        color: Colors.white,
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
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : Colors.white.withOpacity(0.8),
            width: 2,
          ),
        ),
        child: isSelected
            ? Icon(
                Icons.check,
                size: 14,
                color: theme.colorScheme.onPrimary,
              )
            : null,
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

    const previewWidth = 320.0;
    const previewMaxHeight = 400.0;

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
            elevation: 16,
            borderRadius: BorderRadius.circular(16),
            color: theme.colorScheme.surfaceContainerHigh,
            child: Container(
              width: previewWidth,
              constraints: const BoxConstraints(maxHeight: previewMaxHeight),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 预览图
                      if (entry.hasThumbnail && entry.thumbnail != null)
                        ThumbnailDisplay(
                          imagePath: entry.thumbnail!,
                          offsetX: entry.thumbnailOffsetX,
                          offsetY: entry.thumbnailOffsetY,
                          scale: entry.thumbnailScale,
                          width: previewWidth,
                          height: 180,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),

                      // 内容区域
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.displayName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const ThemedDivider(height: 1),
                            const SizedBox(height: 8),
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
                                        color: theme
                                            .colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 12),
                            ],
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
