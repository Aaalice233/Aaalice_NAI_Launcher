import 'package:flutter/material.dart';

import '../../../../data/models/character/character_prompt.dart';
import '../../../widgets/common/themed_divider.dart';

/// 角色位置画布组件
///
/// 用于可视化编辑角色在画面中的位置
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        _buildCanvas(),
        const SizedBox(height: 16),
        _buildPositionList(),
        if (!widget.readOnly && widget.positions.length < widget.characterCount)
          _buildAddButton(),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.grid_on),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '角色位置',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Text(
          '${widget.positions.length}/${widget.characterCount} 个角色',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildCanvas() {
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
          ),
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
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
              ],
            );
          },
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
        color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
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

    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
    ];
    final color = colors[index % colors.length];

    return Positioned(
      left: x - 20,
      top: y - 20,
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
          duration: const Duration(milliseconds: 100),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(isDragging ? 0.9 : 0.7),
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.white : Colors.transparent,
              width: 3,
            ),
            boxShadow: [
              if (isSelected || isDragging)
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
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

    newPositions[index] = current.copyWith(
      row: newRow,
      column: newColumn,
    );

    widget.onPositionsChanged(newPositions);
  }

  Widget _buildPositionList() {
    if (widget.positions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              '点击下方按钮添加角色位置',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.positions.length,
        separatorBuilder: (_, __) => const ThemedDivider(height: 1),
        itemBuilder: (context, index) {
          final position = widget.positions[index];
          final isSelected = _selectedIndex == index;

          return ListTile(
            selected: isSelected,
            leading: CircleAvatar(
              backgroundColor: [
                Colors.blue,
                Colors.green,
                Colors.orange,
                Colors.purple,
                Colors.red,
              ][index % 5],
              child: Text(
                '${index + 1}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text('角色 ${index + 1}'),
            subtitle: Text(
              position.mode == CharacterPositionMode.aiChoice
                  ? 'AI 自动选择'
                  : '行: ${(position.row * 100).toStringAsFixed(0)}%, 列: ${(position.column * 100).toStringAsFixed(0)}%',
            ),
            trailing: widget.readOnly
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ChoiceChip(
                        label: const Text('AI'),
                        selected:
                            position.mode == CharacterPositionMode.aiChoice,
                        onSelected: (selected) {
                          if (selected) {
                            _updatePosition(
                              index,
                              position.copyWith(
                                mode: CharacterPositionMode.aiChoice,
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('自定义'),
                        selected: position.mode == CharacterPositionMode.custom,
                        onSelected: (selected) {
                          if (selected) {
                            _updatePosition(
                              index,
                              position.copyWith(
                                mode: CharacterPositionMode.custom,
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _removePosition(index),
                      ),
                    ],
                  ),
            onTap: () => setState(() => _selectedIndex = index),
          );
        },
      ),
    );
  }

  Widget _buildAddButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: _addPosition,
          icon: const Icon(Icons.add),
          label: const Text('添加角色位置'),
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

  _GridPainter({
    required this.rows,
    required this.cols,
    required this.color,
  });

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
