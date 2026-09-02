import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../adaptive/adaptive_presenter.dart';
import '../../../../adaptive/interaction_policy.dart';
import '../../../../../core/utils/localization_extension.dart';
import '../../../../../data/models/prompt/prompt_tag.dart';
import '../../core/prompt_tag_colors.dart';

/// 移动端标签操作底部面板
/// 长按标签时显示，提供权重滑块和操作按钮
class TagBottomActionSheet extends StatefulWidget {
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

  /// 切换收藏回调
  final VoidCallback? onToggleFavorite;

  /// 是否已收藏
  final bool isFavorite;

  /// 由 [AdaptivePresenter] 提供的面板滚动控制器。
  final ScrollController? scrollController;

  const TagBottomActionSheet({
    super.key,
    required this.tag,
    this.onWeightChanged,
    this.onToggleEnabled,
    this.onEdit,
    this.onDelete,
    this.onCopy,
    this.onToggleFavorite,
    this.isFavorite = false,
    this.scrollController,
  });

  /// 显示底部面板
  static Future<void> show(
    BuildContext context, {
    required PromptTag tag,
    ValueChanged<double>? onWeightChanged,
    VoidCallback? onToggleEnabled,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    VoidCallback? onCopy,
    VoidCallback? onToggleFavorite,
    bool isFavorite = false,
  }) {
    HapticFeedback.mediumImpact();
    return AdaptivePresenter.showPanel<void>(
      context: context,
      titleBuilder: (context) => Text(
        tag.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      builder: (context, scrollController) => TagBottomActionSheet(
        tag: tag,
        onWeightChanged: onWeightChanged,
        onToggleEnabled: onToggleEnabled,
        onEdit: onEdit,
        onDelete: onDelete,
        onCopy: onCopy,
        onToggleFavorite: onToggleFavorite,
        isFavorite: isFavorite,
        scrollController: scrollController,
      ),
    );
  }

  @override
  State<TagBottomActionSheet> createState() => _TagBottomActionSheetState();
}

class _TagBottomActionSheetState extends State<TagBottomActionSheet> {
  late double _currentWeight;

  @override
  void initState() {
    super.initState();
    _currentWeight = widget.tag.weight;
  }

  void _onWeightChanged(double value) {
    setState(() {
      _currentWeight = value;
    });
    widget.onWeightChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tagColor = PromptTagColors.getByCategory(widget.tag.category);

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.only(top: 16, bottom: 16),
      children: [
        _buildTagPreview(theme, tagColor),
        const SizedBox(height: 24),
        _buildWeightSlider(theme),
        const SizedBox(height: 24),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildTagPreview(ThemeData theme, Color tagColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: tagColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tagColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // 标签文本
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getDisplayText(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: widget.tag.enabled
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    decoration: widget.tag.enabled
                        ? null
                        : TextDecoration.lineThrough,
                  ),
                ),
                if (widget.tag.translation != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.tag.translation!,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // 分类标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: tagColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _getCategoryName(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: tagColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getDisplayText() {
    final name = widget.tag.displayName;
    final layers = widget.tag.bracketLayers;

    if (layers > 0) {
      return '${'{' * layers}$name${'}' * layers}';
    } else if (layers < 0) {
      return '${'[' * (-layers)}$name${']' * (-layers)}';
    }
    return name;
  }

  String _getCategoryName() {
    return switch (widget.tag.category) {
      1 => context.l10n.tagCategory_artist,
      3 => context.l10n.tagCategory_copyright,
      4 => context.l10n.tagCategory_character,
      5 => context.l10n.tagCategory_meta,
      _ => context.l10n.tagCategory_general,
    };
  }

  Widget _buildWeightSlider(ThemeData theme) {
    final isIncrease = _currentWeight > 1.0;
    final isDecrease = _currentWeight < 1.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final policyExtent =
                  context.interactionPolicy.minimumControlExtent;
              final minimumControlExtent = policyExtent < 44
                  ? 44.0
                  : policyExtent;
              final valueControls = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isIncrease
                          ? PromptTagColors.weightIncrease.withValues(
                              alpha: 0.15,
                            )
                          : isDecrease
                          ? PromptTagColors.weightDecrease.withValues(
                              alpha: 0.15,
                            )
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${(_currentWeight * 100).round()}%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isIncrease
                            ? PromptTagColors.weightIncrease
                            : isDecrease
                            ? PromptTagColors.weightDecrease
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (_currentWeight != 1.0) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        _onWeightChanged(1.0);
                        HapticFeedback.lightImpact();
                      },
                      style: TextButton.styleFrom(
                        minimumSize: Size.square(minimumControlExtent),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        foregroundColor: theme.colorScheme.onSurfaceVariant,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        context.l10n.weight_reset,
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  ],
                ],
              );
              final title = Text(
                context.l10n.weight_title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              );
              final largeText =
                  MediaQuery.textScalerOf(context).scale(14) >= 20;
              if (constraints.maxWidth < 360 || largeText) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    title,
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: valueControls,
                    ),
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [title, valueControls],
              );
            },
          ),
          const SizedBox(height: 12),
          // 滑块
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 6,
              activeTrackColor: isIncrease
                  ? PromptTagColors.weightIncrease
                  : isDecrease
                  ? PromptTagColors.weightDecrease
                  : theme.colorScheme.primary,
              inactiveTrackColor: theme.colorScheme.surfaceContainerHighest,
              thumbColor: isIncrease
                  ? PromptTagColors.weightIncrease
                  : isDecrease
                  ? PromptTagColors.weightDecrease
                  : theme.colorScheme.primary,
              overlayColor:
                  (isIncrease
                          ? PromptTagColors.weightIncrease
                          : isDecrease
                          ? PromptTagColors.weightDecrease
                          : theme.colorScheme.primary)
                      .withValues(alpha: 0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: _currentWeight,
              min: PromptTag.minWeight,
              max: PromptTag.maxWeight,
              divisions:
                  ((PromptTag.maxWeight - PromptTag.minWeight) /
                          PromptTag.weightStep)
                      .round(),
              onChanged: (value) {
                _onWeightChanged(value);
                HapticFeedback.selectionClick();
              },
            ),
          ),
          // 权重刻度提示
          Row(
            children: [
              for (final entry in <(String, TextAlign)>[
                ('${(PromptTag.minWeight * 100).round()}%', TextAlign.left),
                ('100%', TextAlign.center),
                ('${(PromptTag.maxWeight * 100).round()}%', TextAlign.right),
              ])
                Expanded(
                  child: Text(
                    entry.$1,
                    textAlign: entry.$2,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final actions = <Widget>[
      if (widget.onToggleFavorite != null)
        _ActionButton(
          icon: widget.isFavorite ? Icons.favorite : Icons.favorite_border,
          label: widget.isFavorite
              ? context.l10n.common_unfavorite
              : context.l10n.common_favorite,
          onTap: () {
            widget.onToggleFavorite?.call();
            Navigator.pop(context);
          },
        ),
      _ActionButton(
        icon: widget.tag.enabled
            ? Icons.visibility_off_outlined
            : Icons.visibility_outlined,
        label: widget.tag.enabled
            ? context.l10n.tag_disable
            : context.l10n.tag_enable,
        onTap: () {
          widget.onToggleEnabled?.call();
          Navigator.pop(context);
        },
      ),
      if (widget.onEdit != null)
        _ActionButton(
          icon: Icons.edit_outlined,
          label: context.l10n.tooltip_edit,
          onTap: () {
            Navigator.pop(context);
            widget.onEdit?.call();
          },
        ),
      if (widget.onCopy != null)
        _ActionButton(
          icon: Icons.copy_outlined,
          label: context.l10n.tooltip_copy,
          onTap: () {
            widget.onCopy?.call();
            Navigator.pop(context);
          },
        ),
      _ActionButton(
        icon: Icons.delete_outline,
        label: context.l10n.tag_delete,
        isDestructive: true,
        onTap: () {
          widget.onDelete?.call();
          Navigator.pop(context);
        },
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 12.0;
          final columns = ((constraints.maxWidth + spacing) / 132)
              .floor()
              .clamp(2, actions.length);
          final itemWidth =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final action in actions)
                SizedBox(width: itemWidth, child: action),
            ],
          );
        },
      ),
    );
  }
}

/// 操作按钮
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isDestructive;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isDestructive
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap?.call();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isDestructive
                ? theme.colorScheme.error.withValues(alpha: 0.1)
                : theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDestructive
                  ? theme.colorScheme.error.withValues(alpha: 0.3)
                  : theme.colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: color.withValues(alpha: 0.8)),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
