import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/tag_library/tag_library_entry.dart';
import '../../../adaptive/interaction_policy.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/library_classification_drag.dart';
import '../../../widgets/common/library_card_badges.dart';
import '../../../widgets/common/thumbnail_display.dart';
import '../../../widgets/tag_library/tag_library_entry_hover_preview.dart';

enum _EntryAction { select, edit, favorite, classify, copy, delete }

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
  final VoidCallback? onClassify;

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
    this.onClassify,
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
    final isTouch = context.interactionPolicy.shouldExposeTouchAlternatives;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final cardHeight = 80 + (textScale.clamp(1.0, 3.0) - 1) * 12;

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
        height: cardHeight,
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
                  if (!isTouch &&
                      !widget.isSelectionMode &&
                      !_isHovering &&
                      widget.entry.isFavorite)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: LibraryCardFavoriteBadge(
                        semanticLabel: context.l10n.common_favorite,
                      ),
                    ),

                  if (isTouch && !widget.isSelectionMode)
                    Positioned(
                      top: 16,
                      right: 0,
                      child: _buildTouchActions(theme, entry),
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
        height: cardHeight,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        transform: Matrix4.identity()
          ..translateByDouble(0, _isHovering ? -2 : 0, 0, 1),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isHovering
              ? [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: widget.isSelected
              ? Border.all(color: theme.colorScheme.primary)
              : null,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            cardBody,
            if (!isTouch && !widget.isSelectionMode)
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

    return LibraryClassificationDragSource<TagLibraryEntry>(
      data: entry,
      label: entry.displayName,
      enabled: widget.enableDrag,
      onDragStarted: () {
        setState(() {
          _isDragging = true;
          _isHovering = false;
        });
      },
      onDragEnded: () {
        if (mounted) setState(() => _isDragging = false);
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
    // 标题固定在左侧；只加强文字所在区域，避免为了可读性整体压暗缩略图。
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xA6000000), Color(0x52000000)],
          stops: [0, 0.72],
        ),
      ),
    );
  }

  /// 构建名称显示区域
  Widget _buildNameArea(ThemeData theme, TagLibraryEntry entry) {
    final isTouch = context.interactionPolicy.shouldExposeTouchAlternatives;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, isTouch ? 52 : 16, 12),
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

  Widget _buildTouchActions(ThemeData theme, TagLibraryEntry entry) {
    final l10n = context.l10n;
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
      ),
      child: PopupMenuButton<_EntryAction>(
        tooltip: l10n.common_moreActions,
        constraints: const BoxConstraints(minWidth: 200),
        icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
        onSelected: (action) {
          switch (action) {
            case _EntryAction.select:
              widget.onToggleSelection?.call();
            case _EntryAction.edit:
              widget.onEdit?.call();
            case _EntryAction.favorite:
              widget.onToggleFavorite();
            case _EntryAction.classify:
              widget.onClassify?.call();
            case _EntryAction.copy:
              _copyToClipboard(entry.content);
            case _EntryAction.delete:
              widget.onDelete();
          }
        },
        itemBuilder: (context) => [
          if (widget.onToggleSelection != null)
            PopupMenuItem(
              value: _EntryAction.select,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_circle_outline),
                title: Text(l10n.common_select),
              ),
            ),
          if (widget.onEdit != null)
            PopupMenuItem(
              value: _EntryAction.edit,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.edit_outlined),
                title: Text(l10n.common_edit),
              ),
            ),
          PopupMenuItem(
            value: _EntryAction.favorite,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                entry.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: entry.isFavorite ? Colors.redAccent : null,
              ),
              title: Text(
                entry.isFavorite
                    ? l10n.common_unfavorite
                    : l10n.common_favorite,
              ),
            ),
          ),
          if (widget.onClassify != null)
            PopupMenuItem(
              value: _EntryAction.classify,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.drive_file_move_outline),
                title: Text(l10n.tagLibrary_moveToCategoryTitle),
              ),
            ),
          PopupMenuItem(
            value: _EntryAction.copy,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.content_copy),
              title: Text(l10n.common_copy),
            ),
          ),
          PopupMenuItem(
            value: _EntryAction.delete,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.delete_outline,
                color: theme.colorScheme.error,
              ),
              title: Text(l10n.common_delete),
            ),
          ),
        ],
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
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isHovering ? hoverBgColor : bgColor,
              borderRadius: BorderRadius.circular(8),
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

    return SizedBox.square(
      dimension: 40,
      child: Checkbox(
        value: isSelected,
        onChanged: onTap == null ? null : (_) => onTap?.call(),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: WidgetStateBorderSide.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.selected)
                ? theme.colorScheme.primary
                : Colors.white70,
            width: 1.5,
          ),
        ),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? theme.colorScheme.primary
              : Colors.black45,
        ),
        checkColor: theme.colorScheme.onPrimary,
      ),
    );
  }
}
