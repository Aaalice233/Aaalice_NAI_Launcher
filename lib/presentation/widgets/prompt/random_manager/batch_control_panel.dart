import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/random_preset_provider.dart';
import '../../common/elevated_card.dart';
import '../../common/app_toast.dart';

/// 批量控制面板组件
///
/// 提供批量启用/禁用、全选、反选等批量操作功能
class BatchControlPanel extends ConsumerStatefulWidget {
  const BatchControlPanel({
    super.key,
    required this.selectedIds,
    required this.onSelectionChanged,
    required this.totalCount,
  });

  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onSelectionChanged;
  final int totalCount;

  @override
  ConsumerState<BatchControlPanel> createState() => _BatchControlPanelState();
}

class _BatchControlPanelState extends ConsumerState<BatchControlPanel> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasSelection = widget.selectedIds.isNotEmpty;

    return ElevatedCard(
      elevation: hasSelection ? CardElevation.level2 : CardElevation.level1,
      borderRadius: 12,
      gradientBorder: hasSelection ? CardGradients.primary(colorScheme) : null,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 主控制栏
          Row(
            children: [
              // 选择信息
              _SelectionInfo(
                selectedCount: widget.selectedIds.length,
                totalCount: widget.totalCount,
              ),
              const Spacer(),
              // 快速操作按钮
              _QuickActions(
                hasSelection: hasSelection,
                onSelectAll: _selectAll,
                onDeselectAll: _deselectAll,
                onInvertSelection: _invertSelection,
                onToggleExpand: () =>
                    setState(() => _isExpanded = !_isExpanded),
                isExpanded: _isExpanded,
              ),
            ],
          ),
          // 展开的批量操作
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _BatchOperations(
                hasSelection: hasSelection,
                onEnableSelected: () => _batchSetEnabled(true),
                onDisableSelected: () => _batchSetEnabled(false),
                onDeleteSelected: _batchDelete,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _selectAll() {
    final preset = ref.read(randomPresetNotifierProvider).selectedPreset;
    if (preset == null) return;

    final allIds = <String>{};
    for (final category in preset.categories) {
      allIds.add(category.id);
      for (final group in category.groups) {
        allIds.add(group.id);
      }
    }
    widget.onSelectionChanged(allIds);
  }

  void _deselectAll() {
    widget.onSelectionChanged({});
  }

  void _invertSelection() {
    final preset = ref.read(randomPresetNotifierProvider).selectedPreset;
    if (preset == null) return;

    final allIds = <String>{};
    for (final category in preset.categories) {
      allIds.add(category.id);
      for (final group in category.groups) {
        allIds.add(group.id);
      }
    }

    final inverted = allIds.difference(widget.selectedIds);
    widget.onSelectionChanged(inverted);
  }

  Future<void> _batchSetEnabled(bool enabled) async {
    if (widget.selectedIds.isEmpty) return;

    final notifier = ref.read(randomPresetNotifierProvider.notifier);
    final preset = ref.read(randomPresetNotifierProvider).selectedPreset;
    if (preset == null) return;

    // 更新类别
    var updatedPreset = preset;
    for (final category in preset.categories) {
      if (widget.selectedIds.contains(category.id)) {
        final updated = category.copyWith(enabled: enabled);
        updatedPreset = updatedPreset.updateCategory(updated);
      }
    }

    await notifier.updatePreset(updatedPreset);

    if (mounted) {
      AppToast.success(
        context,
        enabled
            ? '已启用 ${widget.selectedIds.length} 个项目'
            : '已禁用 ${widget.selectedIds.length} 个项目',
      );
    }
  }

  Future<void> _batchDelete() async {
    if (widget.selectedIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('批量删除'),
        content: Text('确定要删除选中的 ${widget.selectedIds.length} 个项目吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final notifier = ref.read(randomPresetNotifierProvider.notifier);

    for (final id in widget.selectedIds) {
      await notifier.removeCategory(id);
    }

    widget.onSelectionChanged({});

    if (mounted) {
      AppToast.success(context, '已删除 ${widget.selectedIds.length} 个项目');
    }
  }
}

/// 选择信息显示
class _SelectionInfo extends StatelessWidget {
  const _SelectionInfo({
    required this.selectedCount,
    required this.totalCount,
  });

  final int selectedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasSelection = selectedCount > 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: hasSelection
                ? colorScheme.primary.withOpacity(0.15)
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            hasSelection ? Icons.check_box : Icons.check_box_outline_blank,
            size: 16,
            color: hasSelection
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hasSelection ? '已选择 $selectedCount 项' : '批量操作',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: hasSelection ? colorScheme.primary : null,
              ),
            ),
            Text(
              '共 $totalCount 项',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 快速操作按钮组
class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.hasSelection,
    required this.onSelectAll,
    required this.onDeselectAll,
    required this.onInvertSelection,
    required this.onToggleExpand,
    required this.isExpanded,
  });

  final bool hasSelection;
  final VoidCallback onSelectAll;
  final VoidCallback onDeselectAll;
  final VoidCallback onInvertSelection;
  final VoidCallback onToggleExpand;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _QuickActionButton(
          icon: Icons.select_all,
          tooltip: '全选',
          onPressed: onSelectAll,
        ),
        _QuickActionButton(
          icon: Icons.deselect,
          tooltip: '取消全选',
          onPressed: hasSelection ? onDeselectAll : null,
        ),
        _QuickActionButton(
          icon: Icons.flip_to_back,
          tooltip: '反选',
          onPressed: onInvertSelection,
        ),
        const SizedBox(width: 8),
        // 展开按钮
        _QuickActionButton(
          icon: isExpanded ? Icons.expand_less : Icons.expand_more,
          tooltip: isExpanded ? '收起' : '更多操作',
          onPressed: onToggleExpand,
          highlighted: isExpanded,
        ),
      ],
    );
  }
}

/// 快速操作按钮
class _QuickActionButton extends StatefulWidget {
  const _QuickActionButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.highlighted = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool highlighted;

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEnabled = widget.onPressed != null;

    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.highlighted || (_isHovered && isEnabled)
                  ? colorScheme.primary.withOpacity(0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              widget.icon,
              size: 18,
              color: isEnabled
                  ? (widget.highlighted
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant)
                  : colorScheme.onSurfaceVariant.withOpacity(0.4),
            ),
          ),
        ),
      ),
    );
  }
}

/// 批量操作区域
class _BatchOperations extends StatelessWidget {
  const _BatchOperations({
    required this.hasSelection,
    required this.onEnableSelected,
    required this.onDisableSelected,
    required this.onDeleteSelected,
  });

  final bool hasSelection;
  final VoidCallback onEnableSelected;
  final VoidCallback onDisableSelected;
  final VoidCallback onDeleteSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.2),
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _BatchOperationButton(
            icon: Icons.check_circle_outline,
            label: '启用选中',
            color: Colors.green,
            onPressed: hasSelection ? onEnableSelected : null,
          ),
          _BatchOperationButton(
            icon: Icons.remove_circle_outline,
            label: '禁用选中',
            color: Colors.orange,
            onPressed: hasSelection ? onDisableSelected : null,
          ),
          _BatchOperationButton(
            icon: Icons.delete_outline,
            label: '删除选中',
            color: Colors.red,
            onPressed: hasSelection ? onDeleteSelected : null,
          ),
        ],
      ),
    );
  }
}

/// 批量操作按钮
class _BatchOperationButton extends StatefulWidget {
  const _BatchOperationButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  State<_BatchOperationButton> createState() => _BatchOperationButtonState();
}

class _BatchOperationButtonState extends State<_BatchOperationButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null;
    final effectiveColor =
        isEnabled ? widget.color : widget.color.withOpacity(0.4);

    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _isHovered && isEnabled
                ? effectiveColor.withOpacity(0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: effectiveColor.withOpacity(isEnabled ? 0.4 : 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 16,
                color: effectiveColor,
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: effectiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
