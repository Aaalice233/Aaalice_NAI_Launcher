import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../data/models/character/character_prompt.dart';

/// 角色位置画布组件
///
/// 用于可视化编辑角色在画面中的位置
/// 采用 Dimensional Layering 设计风格
class CharacterPositionCanvas extends StatefulWidget {
  /// 角色位置列表
  final List<CharacterPosition> positions;

  /// 位置变更回调
  final ValueChanged<List<CharacterPosition>> onPositionsChanged;

  /// 角色数量
  final int characterCount;

  /// 是否只读
  final bool readOnly;

  /// 画布宽高比
  final double aspectRatio;

  const CharacterPositionCanvas({
    super.key,
    required this.positions,
    required this.onPositionsChanged,
    this.characterCount = 1,
    this.readOnly = false,
    this.aspectRatio = 16 / 9,
  });

  @override
  State<CharacterPositionCanvas> createState() =>
      _CharacterPositionCanvasState();
}

class _CharacterPositionCanvasState extends State<CharacterPositionCanvas> {
  int? _selectedIndex;
  int? _draggingIndex;

  // 角色颜色
  static const _characterColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 12),
        _buildCanvas(),
        const SizedBox(height: 12),
        _buildPositionList(),
        if (!widget.readOnly && widget.positions.length < widget.characterCount)
          _buildAddButton(),
      ],
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.grid_on_rounded,
            size: 20,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.diy_characterPositionTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                context.l10n.diy_characterPositionSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${widget.positions.length}/${widget.characterCount}',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCanvas() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colorScheme.surfaceContainerLowest,
                  colorScheme.surfaceContainerLow,
                ],
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    // 网格线
                    _buildGrid(constraints),
                    // 角色位置标记
                    ...widget.positions.asMap().entries.map((entry) {
                      return _buildPositionMarker(
                        entry.key,
                        entry.value,
                        constraints,
                      );
                    }),
                    // 画布提示
                    if (widget.positions.isEmpty)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.touch_app_rounded,
                              size: 40,
                              color: colorScheme.outline.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.l10n.diy_addCharacterPosition,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(BoxConstraints constraints) {
    const rows = 3;
    const cols = 3;

    return CustomPaint(
      size: Size(constraints.maxWidth, constraints.maxHeight),
      painter: _GridPainter(
        rows: rows,
        cols: cols,
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
      ),
    );
  }

  Widget _buildPositionMarker(
    int index,
    CharacterPosition position,
    BoxConstraints constraints,
  ) {
    final x = position.column * constraints.maxWidth;
    final y = position.row * constraints.maxHeight;
    final isSelected = _selectedIndex == index;
    final isDragging = _draggingIndex == index;
    final color = _characterColors[index % _characterColors.length];

    return Positioned(
      left: x - 22,
      top: y - 22,
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        onPanStart: widget.readOnly
            ? null
            : (_) => setState(() => _draggingIndex = index),
        onPanUpdate: widget.readOnly
            ? null
            : (details) => _handleDrag(index, details, constraints),
        onPanEnd: widget.readOnly
            ? null
            : (_) => setState(() => _draggingIndex = null),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, color.withValues(alpha: 0.7)],
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(
                alpha: isSelected || isDragging ? 1 : 0.72,
              ),
              width: isSelected || isDragging ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: isSelected || isDragging ? 10 : 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                shadows: [Shadow(color: Colors.black38, blurRadius: 2)],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleDrag(
    int index,
    DragUpdateDetails details,
    BoxConstraints constraints,
  ) {
    final newPositions = List<CharacterPosition>.from(widget.positions);
    final current = newPositions[index];

    final newColumn = (current.column + details.delta.dx / constraints.maxWidth)
        .clamp(0.0, 1.0);
    final newRow = (current.row + details.delta.dy / constraints.maxHeight)
        .clamp(0.0, 1.0);

    newPositions[index] = current.copyWith(row: newRow, column: newColumn);

    widget.onPositionsChanged(newPositions);
  }

  Widget _buildPositionList() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (widget.positions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.person_pin_circle_rounded,
                size: 32,
                color: colorScheme.outline,
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.diy_addCharacterPositionHint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.positions.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: colorScheme.outline.withValues(alpha: 0.1),
        ),
        itemBuilder: (context, index) {
          final position = widget.positions[index];
          final isSelected = _selectedIndex == index;
          final color = _characterColors[index % _characterColors.length];

          return Material(
            color: isSelected
                ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                : Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _selectedIndex = index),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    // 角色编号
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // 位置信息
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.diy_characterIndex(index + 1),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            position.mode == CharacterPositionMode.aiChoice
                                ? context.l10n.diy_aiPositionChoice
                                : context.l10n.diy_positionCoordinates(
                                    (position.row * 100).toStringAsFixed(0),
                                    (position.column * 100).toStringAsFixed(0),
                                  ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 模式选择
                    if (!widget.readOnly) ...[
                      _buildModeChip(
                        label: 'AI',
                        isSelected:
                            position.mode == CharacterPositionMode.aiChoice,
                        onTap: () => _updatePosition(
                          index,
                          position.copyWith(
                            mode: CharacterPositionMode.aiChoice,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _buildModeChip(
                        label: context.l10n.diy_customPosition,
                        isSelected:
                            position.mode == CharacterPositionMode.custom,
                        onTap: () => _updatePosition(
                          index,
                          position.copyWith(mode: CharacterPositionMode.custom),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: colorScheme.error.withValues(alpha: 0.7),
                        ),
                        onPressed: () => _removePosition(index),
                        tooltip: context.l10n.common_delete,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModeChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.14)
                : colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Center(
        child: FilledButton.tonalIcon(
          onPressed: _addPosition,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(context.l10n.diy_addCharacterPosition),
        ),
      ),
    );
  }

  void _addPosition() {
    final newPosition = CharacterPosition(
      mode: CharacterPositionMode.aiChoice,
      row: 0.5,
      column: 0.5 + widget.positions.length * 0.1,
    );
    widget.onPositionsChanged([...widget.positions, newPosition]);
  }

  void _updatePosition(int index, CharacterPosition position) {
    final newPositions = List<CharacterPosition>.from(widget.positions);
    newPositions[index] = position;
    widget.onPositionsChanged(newPositions);
  }

  void _removePosition(int index) {
    final newPositions = List<CharacterPosition>.from(widget.positions)
      ..removeAt(index);
    widget.onPositionsChanged(newPositions);
    if (_selectedIndex == index) {
      setState(() => _selectedIndex = null);
    }
  }
}

/// 网格绘制器
class _GridPainter extends CustomPainter {
  final int rows;
  final int cols;
  final Color color;

  _GridPainter({required this.rows, required this.cols, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    // 水平线
    for (var i = 1; i < rows; i++) {
      final y = size.height * i / rows;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // 垂直线
    for (var i = 1; i < cols; i++) {
      final x = size.width * i / cols;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return rows != oldDelegate.rows ||
        cols != oldDelegate.cols ||
        color != oldDelegate.color;
  }
}
