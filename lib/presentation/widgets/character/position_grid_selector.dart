import 'package:flutter/material.dart';

import '../../../data/models/character/character_prompt.dart';

/// 位置网格选择器组件
///
/// 实现5x5可点击网格，用于选择角色在画面中的位置。
/// 显示选中位置的视觉指示器。
///
/// Requirements: 3.2, 3.3
class PositionGridSelector extends StatelessWidget {
  /// 当前选中的位置
  final CharacterPosition? selectedPosition;

  /// 位置选择回调
  final ValueChanged<CharacterPosition>? onPositionSelected;

  /// 是否禁用
  final bool enabled;

  /// 网格大小（默认5x5）
  static const int gridSize = 5;

  /// 单元格大小
  final double cellSize;

  /// 单元格间距
  final double cellSpacing;

  const PositionGridSelector({
    super.key,
    this.selectedPosition,
    this.onPositionSelected,
    this.enabled = true,
    this.cellSize = 28,
    this.cellSpacing = 2,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final totalSize = gridSize * cellSize + (gridSize - 1) * cellSpacing;

    return Container(
      width: totalSize,
      height: totalSize,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(gridSize, (row) {
          return Padding(
            padding: EdgeInsets.only(bottom: row < gridSize - 1 ? cellSpacing : 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(gridSize, (column) {
                final position = CharacterPosition(row: row, column: column);
                final isSelected = selectedPosition?.row == row &&
                    selectedPosition?.column == column;

                return Padding(
                  padding: EdgeInsets.only(
                    right: column < gridSize - 1 ? cellSpacing : 0,
                  ),
                  child: _GridCell(
                    position: position,
                    isSelected: isSelected,
                    enabled: enabled,
                    size: cellSize,
                    onTap: enabled
                        ? () => onPositionSelected?.call(position)
                        : null,
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }
}


/// 网格单元格组件
class _GridCell extends StatelessWidget {
  final CharacterPosition position;
  final bool isSelected;
  final bool enabled;
  final double size;
  final VoidCallback? onTap;

  const _GridCell({
    required this.position,
    required this.isSelected,
    required this.enabled,
    required this.size,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final effectiveOpacity = enabled ? 1.0 : 0.5;

    return Tooltip(
      message: position.toNaiString(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primary.withOpacity(0.8 * effectiveOpacity)
                  : colorScheme.surfaceContainerHigh
                      .withOpacity(0.5 * effectiveOpacity),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary.withOpacity(effectiveOpacity)
                    : colorScheme.outline.withOpacity(0.3 * effectiveOpacity),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.3),
                        blurRadius: 4,
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: isSelected
                ? Center(
                    child: Container(
                      width: size * 0.4,
                      height: size * 0.4,
                      decoration: BoxDecoration(
                        color: colorScheme.onPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// 带标签的位置网格选择器
///
/// 在网格周围显示行列标签（A-E, 1-5）
class LabeledPositionGridSelector extends StatelessWidget {
  /// 当前选中的位置
  final CharacterPosition? selectedPosition;

  /// 位置选择回调
  final ValueChanged<CharacterPosition>? onPositionSelected;

  /// 是否禁用
  final bool enabled;

  const LabeledPositionGridSelector({
    super.key,
    this.selectedPosition,
    this.onPositionSelected,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    const cellSize = 28.0;
    const cellSpacing = 2.0;
    const labelWidth = 16.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 列标签 (A-E)
        Padding(
          padding: const EdgeInsets.only(left: labelWidth + 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(PositionGridSelector.gridSize, (column) {
              final label = String.fromCharCode('A'.codeUnitAt(0) + column);
              return SizedBox(
                width: cellSize + (column < 4 ? cellSpacing : 0),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 4),
        // 行标签 + 网格
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 行标签 (1-5)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(PositionGridSelector.gridSize, (row) {
                return SizedBox(
                  width: labelWidth,
                  height: cellSize + (row < 4 ? cellSpacing : 0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        '${row + 1}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            // 网格
            PositionGridSelector(
              selectedPosition: selectedPosition,
              onPositionSelected: onPositionSelected,
              enabled: enabled,
              cellSize: cellSize,
              cellSpacing: cellSpacing,
            ),
          ],
        ),
      ],
    );
  }
}
