import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TagBottomActionSheet(
        tag: tag,
        onWeightChanged: onWeightChanged,
        onToggleEnabled: onToggleEnabled,
        onEdit: onEdit,
        onDelete: onDelete,
        onCopy: onCopy,
        onToggleFavorite: onToggleFavorite,
        isFavorite: isFavorite,
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

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.1),
              ),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 拖动指示条
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // 标签预览
                _buildTagPreview(theme, tagColor),

                const SizedBox(height: 24),

                // 权重调整滑块
                _buildWeightSlider(theme),

                const SizedBox(height: 24),

                // 操作按钮
                _buildActionButtons(theme),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTagPreview(ThemeData theme, Color tagColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: tagColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: tagColor.withOpacity(0.3),
        ),
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
                        : theme.colorScheme.onSurface.withOpacity(0.5),
                    decoration:
                        widget.tag.enabled ? null : TextDecoration.lineThrough,
                  ),
                ),
                if (widget.tag.translation != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.tag.translation!,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
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
              color: tagColor.withOpacity(0.2),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.weight_title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
              // 权重值和重置按钮
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isIncrease
                          ? PromptTagColors.weightIncrease.withOpacity(0.15)
                          : isDecrease
                              ? PromptTagColors.weightDecrease.withOpacity(0.15)
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
                    GestureDetector(
                      onTap: () {
                        _onWeightChanged(1.0);
                        HapticFeedback.lightImpact();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          context.l10n.weight_reset,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
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
              overlayColor: (isIncrease
                      ? PromptTagColors.weightIncrease
                      : isDecrease
                          ? PromptTagColors.weightDecrease
                          : theme.colorScheme.primary)
                  .withOpacity(0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: _currentWeight,
              min: PromptTag.minWeight,
              max: PromptTag.maxWeight,
              divisions: ((PromptTag.maxWeight - PromptTag.minWeight) /
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(PromptTag.minWeight * 100).round()}%',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
              ),
              Text(
                '100%',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
              ),
              Text(
                '${(PromptTag.maxWeight * 100).round()}%',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // 收藏
          if (widget.onToggleFavorite != null) ...[
            Expanded(
              child: _ActionButton(
                icon:
                    widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                label: widget.isFavorite ? 'Unfavorite' : 'Favorite',
                onTap: () {
                  widget.onToggleFavorite?.call();
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(width: 12),
          ],
          // 启用/禁用
          Expanded(
            child: _ActionButton(
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
          ),
          const SizedBox(width: 12),
          // 编辑
          if (widget.onEdit != null) ...[
            Expanded(
              child: _ActionButton(
                icon: Icons.edit_outlined,
                label: context.l10n.tooltip_edit,
                onTap: () {
                  Navigator.pop(context);
                  widget.onEdit?.call();
                },
              ),
            ),
            const SizedBox(width: 12),
          ],
          // 复制
          if (widget.onCopy != null) ...[
            Expanded(
              child: _ActionButton(
                icon: Icons.copy_outlined,
                label: context.l10n.tooltip_copy,
                onTap: () {
                  widget.onCopy?.call();
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(width: 12),
          ],
          // 删除
          Expanded(
            child: _ActionButton(
              icon: Icons.delete_outline,
              label: context.l10n.tag_delete,
              isDestructive: true,
              onTap: () {
                widget.onDelete?.call();
                Navigator.pop(context);
              },
            ),
          ),
        ],
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
    final color =
        isDestructive ? theme.colorScheme.error : theme.colorScheme.onSurface;

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
                ? theme.colorScheme.error.withOpacity(0.1)
                : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDestructive
                  ? theme.colorScheme.error.withOpacity(0.3)
                  : theme.colorScheme.outline.withOpacity(0.1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: color.withOpacity(0.8)),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
