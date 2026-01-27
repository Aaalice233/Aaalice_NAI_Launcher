import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/prompt/prompt_tag.dart';
import '../common/themed_switch.dart';
import '../tag_chip.dart';

/// 权重调节对话框（移动端使用）
class WeightAdjustDialog extends StatefulWidget {
  final PromptTag tag;
  final ValueChanged<double> onWeightChanged;
  final VoidCallback? onToggleEnabled;
  final VoidCallback? onDelete;

  const WeightAdjustDialog({
    super.key,
    required this.tag,
    required this.onWeightChanged,
    this.onToggleEnabled,
    this.onDelete,
  });

  /// 显示权重调节对话框
  static Future<void> show(
    BuildContext context, {
    required PromptTag tag,
    required ValueChanged<double> onWeightChanged,
    VoidCallback? onToggleEnabled,
    VoidCallback? onDelete,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WeightAdjustDialog(
        tag: tag,
        onWeightChanged: onWeightChanged,
        onToggleEnabled: onToggleEnabled,
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<WeightAdjustDialog> createState() => _WeightAdjustDialogState();
}

class _WeightAdjustDialogState extends State<WeightAdjustDialog> {
  late double _currentWeight;

  @override
  void initState() {
    super.initState();
    _currentWeight = widget.tag.weight;
  }

  void _updateWeight(double weight) {
    final clampedWeight =
        weight.clamp(PromptTag.minWeight, PromptTag.maxWeight);
    setState(() {
      _currentWeight = clampedWeight;
    });
    widget.onWeightChanged(clampedWeight);
    HapticFeedback.selectionClick();
  }

  void _incrementWeight() {
    _updateWeight(_currentWeight + PromptTag.weightStep);
  }

  void _decrementWeight() {
    _updateWeight(_currentWeight - PromptTag.weightStep);
  }

  void _resetWeight() {
    _updateWeight(1.0);
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipColor = TagColors.fromCategory(widget.tag.category);
    final weightPercent = (_currentWeight * 100).round();
    final bracketLayers =
        ((_currentWeight - 1.0) / PromptTag.weightStep).round();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 拖动指示器
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 标签名称
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      color: chipColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.tag.displayName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (widget.tag.translation != null)
                          Text(
                            widget.tag.translation!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // 启用/禁用开关
                  if (widget.onToggleEnabled != null)
                    ThemedSwitch(
                      value: widget.tag.enabled,
                      onChanged: (_) {
                        widget.onToggleEnabled?.call();
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // 权重显示
              Center(
                child: Column(
                  children: [
                    Text(
                      '$weightPercent%',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _currentWeight > 1.0
                            ? Colors.orange
                            : _currentWeight < 1.0
                                ? Colors.blue
                                : theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bracketLayers > 0
                          ? '${'{' * bracketLayers}...${'}' * bracketLayers}'
                          : bracketLayers < 0
                              ? '${'[' * (-bracketLayers)}...${'[' * (-bracketLayers)}'
                              : context.l10n.weight_noBrackets,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 权重滑块
              Row(
                children: [
                  // 减少按钮
                  IconButton.filled(
                    onPressed: _decrementWeight,
                    icon: const Icon(Icons.remove),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.blue.withOpacity(0.1),
                      foregroundColor: Colors.blue,
                    ),
                  ),
                  // 滑块
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: _currentWeight > 1.0
                            ? Colors.orange
                            : _currentWeight < 1.0
                                ? Colors.blue
                                : theme.colorScheme.primary,
                        inactiveTrackColor:
                            theme.colorScheme.surfaceContainerHighest,
                        thumbColor: _currentWeight > 1.0
                            ? Colors.orange
                            : _currentWeight < 1.0
                                ? Colors.blue
                                : theme.colorScheme.primary,
                        overlayColor: (_currentWeight > 1.0
                                ? Colors.orange
                                : _currentWeight < 1.0
                                    ? Colors.blue
                                    : theme.colorScheme.primary)
                            .withOpacity(0.2),
                      ),
                      child: Slider(
                        value: _currentWeight,
                        min: PromptTag.minWeight,
                        max: PromptTag.maxWeight,
                        divisions:
                            ((PromptTag.maxWeight - PromptTag.minWeight) /
                                    PromptTag.weightStep)
                                .round(),
                        onChanged: _updateWeight,
                      ),
                    ),
                  ),
                  // 增加按钮
                  IconButton.filled(
                    onPressed: _incrementWeight,
                    icon: const Icon(Icons.add),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.orange.withOpacity(0.1),
                      foregroundColor: Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 快捷权重按钮
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildQuickWeightButton(theme, 0.5, '-50%'),
                  _buildQuickWeightButton(theme, 0.75, '-25%'),
                  _buildQuickWeightButton(theme, 0.9, '-10%'),
                  _buildQuickWeightButton(theme, 1.0, '100%', isReset: true),
                  _buildQuickWeightButton(theme, 1.1, '+10%'),
                  _buildQuickWeightButton(theme, 1.25, '+25%'),
                  _buildQuickWeightButton(theme, 1.5, '+50%'),
                ],
              ),
              const SizedBox(height: 24),

              // 操作按钮
              Row(
                children: [
                  // 删除按钮
                  if (widget.onDelete != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          widget.onDelete?.call();
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: Text(context.l10n.tag_delete),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                          side: BorderSide(color: theme.colorScheme.error),
                        ),
                      ),
                    ),
                  if (widget.onDelete != null) const SizedBox(width: 12),
                  // 重置按钮
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _resetWeight,
                      icon: const Icon(Icons.refresh),
                      label: Text(context.l10n.weight_reset),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 确认按钮
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check),
                      label: Text(context.l10n.weight_done),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickWeightButton(
    ThemeData theme,
    double weight,
    String label, {
    bool isReset = false,
  }) {
    final isSelected = (_currentWeight - weight).abs() < 0.01;

    return ActionChip(
      label: Text(label),
      onPressed: () => _updateWeight(weight),
      backgroundColor: isSelected
          ? (isReset
              ? theme.colorScheme.primaryContainer
              : weight > 1.0
                  ? Colors.orange.withOpacity(0.2)
                  : Colors.blue.withOpacity(0.2))
          : null,
      labelStyle: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected
            ? (isReset
                ? theme.colorScheme.onPrimaryContainer
                : weight > 1.0
                    ? Colors.orange.shade700
                    : Colors.blue.shade700)
            : null,
      ),
      side: isSelected
          ? BorderSide(
              color: isReset
                  ? theme.colorScheme.primary
                  : weight > 1.0
                      ? Colors.orange
                      : Colors.blue,
            )
          : null,
    );
  }
}

/// 标签编辑对话框（双击编辑）
class TagEditDialog extends StatefulWidget {
  final PromptTag tag;
  final ValueChanged<String> onTextChanged;

  const TagEditDialog({
    super.key,
    required this.tag,
    required this.onTextChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required PromptTag tag,
    required ValueChanged<String> onTextChanged,
  }) {
    return showDialog(
      context: context,
      builder: (context) => TagEditDialog(
        tag: tag,
        onTextChanged: onTextChanged,
      ),
    );
  }

  @override
  State<TagEditDialog> createState() => _TagEditDialogState();
}

class _TagEditDialogState extends State<TagEditDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.tag.text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.weight_editTag),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: context.l10n.weight_tagName,
          hintText: context.l10n.weight_tagNameHint,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (_) => _confirm(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.common_cancel),
        ),
        FilledButton(
          onPressed: _confirm,
          child: Text(context.l10n.common_confirm),
        ),
      ],
    );
  }

  void _confirm() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onTextChanged(text);
    }
    Navigator.pop(context);
  }
}
