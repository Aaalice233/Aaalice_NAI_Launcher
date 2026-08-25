import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/tag_library/tag_library_entry.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/thumbnail_display.dart';
import '../../../widgets/tag_library/tag_library_entry_hover_preview.dart';

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

class _EntryCardState extends State<EntryCard> {
  bool _isHovering = false;
  bool _isDragging = false;

  void _onEnter() {
    if (!_isDragging && !widget.isSelectionMode) {
      setState(() => _isHovering = true);
    }
  }

  void _onExit() {
    setState(() => _isHovering = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = widget.entry;

    // 选中/悬停边框色
    final borderColor = widget.isSelected
        ? theme.colorScheme.primary
        : (_isHovering
              ? theme.colorScheme.primary.withValues(alpha: 0.5)
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
      child: SizedBox(
        height: 80,
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

                  // 3. 内容区域（悬浮操作态隐藏，多选时仍保留名称）
                  if (widget.isSelectionMode || !_isHovering)
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
          ],
        ),
      ),
    );

    // 外层包装：MouseRegion + 悬浮按钮层
    final cardVisual = MouseRegion(
      onEnter: (_) => _onEnter(),
      onExit: (_) => _onExit(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        height: 80,
        transform: Matrix4.identity()
          ..translateByDouble(0, _isHovering ? -4 : 0, 0, 1)
          ..scaleByDouble(
            _isHovering ? 1.02 : 1,
            _isHovering ? 1.02 : 1,
            _isHovering ? 1.02 : 1,
            1,
          ),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isHovering
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                  ),
                ],
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: widget.isSelected ? 3 : (_isHovering ? 1.5 : 0),
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            cardBody,
            if (!widget.isSelectionMode)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_isHovering,
                  child: Opacity(
                    opacity: _isHovering ? 1 : 0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.5),
                        child: _buildFloatingButtons(theme, entry),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    final cardContent = TagLibraryEntryHoverPreview(
      entry: entry,
      enabled: !widget.isSelectionMode && !_isDragging,
      child: cardVisual,
    );

    // 保持根节点稳定，避免切换多选模式时重建缩略图子树。
    return Draggable<TagLibraryEntry>(
      data: entry,
      maxSimultaneousDrags: widget.enableDrag ? null : 0,
      feedback: widget.enableDrag
          ? _buildDragFeedback(theme, entry)
          : const SizedBox.shrink(),
      childWhenDragging: Opacity(opacity: 0.4, child: cardContent),
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
      child: cardContent,
    );
  }

  /// 构建背景图片
  Widget _buildBackgroundImage(TagLibraryEntry entry) {
    if (entry.hasThumbnail && entry.thumbnail != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return ThumbnailDisplay(
            imagePath: entry.thumbnail!,
            offsetX: entry.thumbnailOffsetX,
            offsetY: entry.thumbnailOffsetY,
            scale: entry.thumbnailScale,
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            borderRadius: BorderRadius.circular(12),
          );
        },
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
          colors: [Colors.grey.shade700, Colors.grey.shade900],
        ),
      ),
      child: const Center(
        child: Icon(Icons.image_outlined, size: 32, color: Colors.white38),
      ),
    );
  }

  /// 构建轻微暗化遮罩
  Widget _buildDarkenOverlay() {
    return Container(color: Colors.black.withValues(alpha: 0.35));
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
            color: theme.colorScheme.primary.withValues(alpha: 0.8),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
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
                        context.l10n.tagLibrary_moveToCategoryTitle,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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
    final bgColor = Colors.white.withValues(alpha: 0.15);
    final hoverBgColor = Colors.white.withValues(alpha: 0.35);

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
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                widget.icon,
                size: 20,
                color:
                    widget.color ??
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
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: const Icon(Icons.favorite, size: 12, color: Colors.white),
    );
  }
}

/// 选择复选框
class _SelectionCheckbox extends StatelessWidget {
  final bool isSelected;
  final VoidCallback? onTap;

  const _SelectionCheckbox({required this.isSelected, this.onTap});

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
              : Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : Colors.white.withValues(alpha: 0.8),
            width: 2,
          ),
        ),
        child: isSelected
            ? Icon(Icons.check, size: 14, color: theme.colorScheme.onPrimary)
            : null,
      ),
    );
  }
}
