import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../../data/models/prompt/prompt_tag.dart';
import '../../core/prompt_tag_colors.dart';
import '../../core/prompt_tag_config.dart';

/// 标签悬浮操作菜单
/// 桌面端悬浮时显示，提供权重调整和快捷操作
class FloatingActionMenu extends StatelessWidget {
  /// 当前标签
  final PromptTag tag;

  /// 权重变化回调
  final ValueChanged<double>? onWeightChanged;

  /// 切换启用回调
  final VoidCallback? onToggleEnabled;

  /// 编辑回调
  final VoidCallback? onEdit;

  /// 删除回调
  final VoidCallback? onDelete;

  /// 复制回调
  final VoidCallback? onCopy;

  const FloatingActionMenu({
    super.key,
    required this.tag,
    this.onWeightChanged,
    this.onToggleEnabled,
    this.onEdit,
    this.onDelete,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final maxWidth = (MediaQuery.sizeOf(context).width - 24).clamp(
      0.0,
      double.infinity,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        elevation: 8,
        borderRadius: BorderRadius.circular(TagChipSizes.menuBorderRadius),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _WeightControlSection(tag: tag, onWeightChanged: onWeightChanged),
              _buildDivider(theme),
              _ActionButtonsSection(
                tag: tag,
                onToggleEnabled: onToggleEnabled,
                onEdit: onEdit,
                onDelete: onDelete,
                onCopy: onCopy,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: theme.colorScheme.outline.withValues(alpha: 0.2),
    );
  }
}

/// 权重控制区域
class _WeightControlSection extends StatelessWidget {
  final PromptTag tag;
  final ValueChanged<double>? onWeightChanged;

  const _WeightControlSection({required this.tag, this.onWeightChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 减少权重按钮
        _MenuIconButton(
          icon: Icons.remove,
          tooltip: context.l10n.tooltip_decreaseWeight,
          color: PromptTagColors.weightDecrease,
          onTap: () {
            final newWeight = (tag.weight - PromptTag.weightStep).clamp(
              PromptTag.minWeight,
              PromptTag.maxWeight,
            );
            onWeightChanged?.call(newWeight);
            HapticFeedback.lightImpact();
          },
        ),

        // 权重值显示
        Tooltip(
          message: context.l10n.tooltip_resetWeight,
          child: TextButton(
            onPressed: tag.weight == 1.0
                ? null
                : () {
                    onWeightChanged?.call(1.0);
                    HapticFeedback.mediumImpact();
                  },
            style: TextButton.styleFrom(
              minimumSize: const Size(42, TagChipSizes.menuButtonSize),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              tag.weightPercentText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: tag.weight > 1.0
                    ? PromptTagColors.weightIncrease
                    : tag.weight < 1.0
                    ? PromptTagColors.weightDecrease
                    : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),

        // 增加权重按钮
        _MenuIconButton(
          icon: Icons.add,
          tooltip: context.l10n.tooltip_increaseWeight,
          color: PromptTagColors.weightIncrease,
          onTap: () {
            final newWeight = (tag.weight + PromptTag.weightStep).clamp(
              PromptTag.minWeight,
              PromptTag.maxWeight,
            );
            onWeightChanged?.call(newWeight);
            HapticFeedback.lightImpact();
          },
        ),
      ],
    );
  }
}

/// 操作按钮区域
class _ActionButtonsSection extends StatelessWidget {
  final PromptTag tag;
  final VoidCallback? onToggleEnabled;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onCopy;

  const _ActionButtonsSection({
    required this.tag,
    this.onToggleEnabled,
    this.onEdit,
    this.onDelete,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 启用/禁用
        _MenuIconButton(
          icon: tag.enabled
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          tooltip: tag.enabled
              ? context.l10n.tooltip_disable
              : context.l10n.tooltip_enable,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          onTap: () {
            onToggleEnabled?.call();
            HapticFeedback.lightImpact();
          },
        ),

        // 编辑
        if (onEdit != null)
          _MenuIconButton(
            icon: Icons.edit_outlined,
            tooltip: context.l10n.tooltip_edit,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            onTap: () {
              onEdit?.call();
              HapticFeedback.lightImpact();
            },
          ),

        // 复制
        if (onCopy != null)
          _MenuIconButton(
            icon: Icons.copy_outlined,
            tooltip: context.l10n.tooltip_copy,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            onTap: () {
              onCopy?.call();
              HapticFeedback.lightImpact();
            },
          ),

        // 删除
        _MenuIconButton(
          icon: Icons.close,
          tooltip: context.l10n.tooltip_delete,
          color: const Color(0xFFFF3B30),
          onTap: () {
            onDelete?.call();
            HapticFeedback.mediumImpact();
          },
        ),
      ],
    );
  }
}

/// 菜单图标按钮
class _MenuIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;

  const _MenuIconButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon),
      tooltip: tooltip,
      iconSize: TagChipSizes.menuIconSize,
      color: color.withValues(alpha: 0.8),
      hoverColor: color.withValues(alpha: 0.15),
      focusColor: color.withValues(alpha: 0.15),
      highlightColor: color.withValues(alpha: 0.12),
      constraints: const BoxConstraints.tightFor(
        width: TagChipSizes.menuButtonSize,
        height: TagChipSizes.menuButtonSize,
      ),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}

/// 使用 OverlayEntry 显示悬浮菜单的包装器
class FloatingMenuPortal extends StatefulWidget {
  /// 子组件（标签卡片）
  final Widget child;

  /// 是否显示菜单
  final bool showMenu;

  /// 菜单内容
  final WidgetBuilder menuBuilder;

  /// 菜单偏移
  final Offset menuOffset;

  const FloatingMenuPortal({
    super.key,
    required this.child,
    required this.showMenu,
    required this.menuBuilder,
    this.menuOffset = const Offset(0, 4),
  });

  @override
  State<FloatingMenuPortal> createState() => _FloatingMenuPortalState();
}

class _FloatingMenuPortalState extends State<FloatingMenuPortal> {
  final LayerLink _link = LayerLink();
  final GlobalKey _targetKey = GlobalKey();
  final GlobalKey _menuKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  double _horizontalOffset = 0;

  @override
  void initState() {
    super.initState();
    if (widget.showMenu) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.showMenu) _showOverlay();
      });
    }
  }

  @override
  void didUpdateWidget(FloatingMenuPortal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showMenu != oldWidget.showMenu) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.showMenu) {
          _showOverlay();
        } else {
          _hideOverlay();
        }
      });
    } else if (widget.showMenu) {
      _overlayEntry?.markNeedsBuild();
      _scheduleReposition();
    }
  }

  @override
  void dispose() {
    _hideOverlay();
    super.dispose();
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CompositedTransformFollower(
                link: _link,
                targetAnchor: Alignment.topLeft,
                followerAnchor: Alignment.bottomLeft,
                offset: Offset(_horizontalOffset, -widget.menuOffset.dy),
                child: KeyedSubtree(
                  key: _menuKey,
                  child: widget.menuBuilder(context),
                ),
              ),
            ],
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
    _scheduleReposition();
  }

  void _scheduleReposition() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _overlayEntry == null) return;
      final targetBox =
          _targetKey.currentContext?.findRenderObject() as RenderBox?;
      final menuBox = _menuKey.currentContext?.findRenderObject() as RenderBox?;
      if (targetBox == null || menuBox == null || !menuBox.hasSize) return;
      final mediaQuery = MediaQuery.of(context);
      const gap = 12.0;
      final targetX = targetBox.localToGlobal(Offset.zero).dx;
      final safeLeft = mediaQuery.padding.left + gap;
      final safeRight = mediaQuery.size.width - mediaQuery.padding.right - gap;
      final maxLeft = (safeRight - menuBox.size.width).clamp(
        safeLeft,
        double.infinity,
      );
      final nextOffset = targetX.clamp(safeLeft, maxLeft) - targetX;
      if (nextOffset == _horizontalOffset) return;
      _horizontalOffset = nextOffset;
      _overlayEntry?.markNeedsBuild();
    });
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _horizontalOffset = 0;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showMenu) _scheduleReposition();
    return CompositedTransformTarget(
      link: _link,
      child: KeyedSubtree(key: _targetKey, child: widget.child),
    );
  }
}
