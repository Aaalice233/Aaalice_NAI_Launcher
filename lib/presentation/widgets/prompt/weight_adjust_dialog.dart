import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../data/models/prompt/prompt_tag.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../common/themed_switch.dart';
import '../common/translated_tag_text.dart';
import '../tag_chip.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';

/// 权重调节对话框（移动端使用）
class WeightAdjustDialog extends StatefulWidget {
  final PromptTag tag;
  final ValueChanged<double> onWeightChanged;
  final VoidCallback? onToggleEnabled;
  final VoidCallback? onDelete;
  final ScrollController? scrollController;

  const WeightAdjustDialog({
    super.key,
    required this.tag,
    required this.onWeightChanged,
    this.onToggleEnabled,
    this.onDelete,
    this.scrollController,
  });

  /// 显示权重调节对话框
  static Future<void> show(
    BuildContext context, {
    required PromptTag tag,
    required ValueChanged<double> onWeightChanged,
    VoidCallback? onToggleEnabled,
    VoidCallback? onDelete,
  }) {
    return AdaptivePresenter.showPanel<void>(
      context: context,
      title: context.l10n.weight_title,
      dialogWidth: 640,
      initialChildSize: 0.8,
      minChildSize: 0.5,
      builder: (_, scrollController) => WeightAdjustDialog(
        tag: tag,
        onWeightChanged: onWeightChanged,
        onToggleEnabled: onToggleEnabled,
        onDelete: onDelete,
        scrollController: scrollController,
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
    final clampedWeight = weight.clamp(
      PromptTag.minWeight,
      PromptTag.maxWeight,
    );
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
    final bracketLayers = ((_currentWeight - 1.0) / PromptTag.weightStep)
        .round();
    final weightColor = _currentWeight > 1.0
        ? theme.colorScheme.tertiary
        : _currentWeight < 1.0
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowUp): _incrementWeight,
        const SingleActivator(LogicalKeyboardKey.arrowRight): _incrementWeight,
        const SingleActivator(LogicalKeyboardKey.arrowDown): _decrementWeight,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): _decrementWeight,
        const SingleActivator(LogicalKeyboardKey.home): _resetWeight,
      },
      child: Focus(
        autofocus: true,
        child: AnimatedPadding(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Material(
                color: theme.colorScheme.surface,
                clipBehavior: Clip.antiAlias,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    controller: widget.scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.3,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
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
                                  TranslatedTagText(
                                    widget.tag.displayName,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
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
                        Center(
                          child: Column(
                            children: [
                              Text(
                                '$weightPercent%',
                                style: theme.textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: weightColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                bracketLayers > 0
                                    ? '${'{' * bracketLayers}...${'}' * bracketLayers}'
                                    : bracketLayers < 0
                                    ? '${'[' * (-bracketLayers)}...${']' * (-bracketLayers)}'
                                    : context.l10n.weight_noBrackets,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            IconButton.filledTonal(
                              onPressed: _decrementWeight,
                              icon: const Icon(Icons.remove),
                              tooltip: context.l10n.tooltip_decreaseWeight,
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: weightColor,
                                  inactiveTrackColor:
                                      theme.colorScheme.surfaceContainerHighest,
                                  thumbColor: weightColor,
                                  overlayColor: weightColor.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                                child: Slider(
                                  value: _currentWeight,
                                  min: PromptTag.minWeight,
                                  max: PromptTag.maxWeight,
                                  divisions:
                                      ((PromptTag.maxWeight -
                                                  PromptTag.minWeight) /
                                              PromptTag.weightStep)
                                          .round(),
                                  onChanged: _updateWeight,
                                ),
                              ),
                            ),
                            IconButton.filledTonal(
                              onPressed: _incrementWeight,
                              icon: const Icon(Icons.add),
                              tooltip: context.l10n.tooltip_increaseWeight,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildQuickWeightButton(theme, 0.5, '-50%'),
                            _buildQuickWeightButton(theme, 0.75, '-25%'),
                            _buildQuickWeightButton(theme, 0.9, '-10%'),
                            _buildQuickWeightButton(
                              theme,
                              1.0,
                              '100%',
                              isReset: true,
                            ),
                            _buildQuickWeightButton(theme, 1.1, '+10%'),
                            _buildQuickWeightButton(theme, 1.25, '+25%'),
                            _buildQuickWeightButton(theme, 1.5, '+50%'),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildActions(theme),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions(ThemeData theme) {
    final actions = <Widget>[
      if (widget.onDelete != null)
        OutlinedButton.icon(
          onPressed: () {
            widget.onDelete?.call();
            Navigator.pop(context);
          },
          icon: const Icon(Icons.delete_outline),
          label: Text(context.l10n.tag_delete),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
            side: BorderSide.none,
            backgroundColor: theme.colorScheme.errorContainer.withValues(
              alpha: 0.35,
            ),
          ),
        ),
      OutlinedButton.icon(
        onPressed: _resetWeight,
        icon: const Icon(Icons.refresh),
        label: Text(context.l10n.weight_reset),
        style: OutlinedButton.styleFrom(side: BorderSide.none),
      ),
      FilledButton.icon(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.check),
        label: Text(context.l10n.weight_done),
      ),
    ];
    final largeText = MediaQuery.textScalerOf(context).scale(14) >= 20;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420 || largeText) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < actions.length; index++) ...[
                actions[index],
                if (index != actions.length - 1) const SizedBox(height: 8),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var index = 0; index < actions.length; index++) ...[
              Expanded(child: actions[index]),
              if (index != actions.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
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
                ? Colors.orange.withValues(alpha: 0.2)
                : Colors.blue.withValues(alpha: 0.2))
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
    return AdaptivePresenter.showForm<void>(
      context: context,
      title: context.l10n.weight_editTag,
      dialogWidth: 440,
      builder: (_, __) => TagEditDialog(tag: tag, onTextChanged: onTextChanged),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(16),
            child: ThemedInput(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: context.l10n.weight_tagName,
                hintText: context.l10n.weight_tagNameHint,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _confirm(),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n.common_cancel),
                ),
                FilledButton(
                  onPressed: _confirm,
                  child: Text(context.l10n.common_confirm),
                ),
              ],
            ),
          ),
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
