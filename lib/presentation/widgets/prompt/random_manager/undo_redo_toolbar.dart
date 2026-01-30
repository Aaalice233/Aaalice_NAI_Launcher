import 'package:flutter/material.dart';

import '../../common/elevated_card.dart';

/// 操作历史记录
class OperationHistory<T> {
  final List<T> _undoStack = [];
  final List<T> _redoStack = [];
  final int maxHistorySize;

  OperationHistory({this.maxHistorySize = 50});

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  int get undoCount => _undoStack.length;
  int get redoCount => _redoStack.length;

  /// 添加操作到历史
  void push(T state) {
    _undoStack.add(state);
    _redoStack.clear();

    // 限制历史大小
    while (_undoStack.length > maxHistorySize) {
      _undoStack.removeAt(0);
    }
  }

  /// 撤销操作
  T? undo(T currentState) {
    if (!canUndo) return null;

    _redoStack.add(currentState);
    return _undoStack.removeLast();
  }

  /// 重做操作
  T? redo(T currentState) {
    if (!canRedo) return null;

    _undoStack.add(currentState);
    return _redoStack.removeLast();
  }

  /// 清空历史
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}

/// 撤销/重做工具栏组件
///
/// 提供撤销和重做按钮，以及操作历史预览
class UndoRedoToolbar extends StatefulWidget {
  const UndoRedoToolbar({
    super.key,
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
    this.undoCount = 0,
    this.redoCount = 0,
    this.showCounts = true,
    this.compact = false,
  });

  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final int undoCount;
  final int redoCount;
  final bool showCounts;
  final bool compact;

  @override
  State<UndoRedoToolbar> createState() => _UndoRedoToolbarState();
}

class _UndoRedoToolbarState extends State<UndoRedoToolbar> {
  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _buildCompact(context);
    }
    return _buildFull(context);
  }

  Widget _buildCompact(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _UndoRedoButton(
          icon: Icons.undo,
          tooltip: '撤销 (Ctrl+Z)',
          enabled: widget.canUndo,
          onPressed: widget.onUndo,
        ),
        const SizedBox(width: 4),
        _UndoRedoButton(
          icon: Icons.redo,
          tooltip: '重做 (Ctrl+Y)',
          enabled: widget.canRedo,
          onPressed: widget.onRedo,
        ),
      ],
    );
  }

  Widget _buildFull(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ElevatedCard(
      elevation: CardElevation.level1,
      borderRadius: 10,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 撤销按钮
          _UndoRedoButton(
            icon: Icons.undo,
            tooltip: '撤销 (Ctrl+Z)',
            enabled: widget.canUndo,
            onPressed: widget.onUndo,
            badge: widget.showCounts && widget.undoCount > 0
                ? widget.undoCount.toString()
                : null,
          ),
          // 分隔线
          Container(
            width: 1,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: colorScheme.outlineVariant.withOpacity(0.3),
          ),
          // 重做按钮
          _UndoRedoButton(
            icon: Icons.redo,
            tooltip: '重做 (Ctrl+Y)',
            enabled: widget.canRedo,
            onPressed: widget.onRedo,
            badge: widget.showCounts && widget.redoCount > 0
                ? widget.redoCount.toString()
                : null,
          ),
        ],
      ),
    );
  }
}

/// 撤销/重做按钮
class _UndoRedoButton extends StatefulWidget {
  const _UndoRedoButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onPressed,
    this.badge,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onPressed;
  final String? badge;

  @override
  State<_UndoRedoButton> createState() => _UndoRedoButtonState();
}

class _UndoRedoButtonState extends State<_UndoRedoButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      cursor:
          widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          if (widget.enabled) widget.onPressed();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: Tooltip(
          message: widget.tooltip,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _isPressed && widget.enabled
                  ? colorScheme.primary.withOpacity(0.2)
                  : _isHovered && widget.enabled
                      ? colorScheme.primary.withOpacity(0.1)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedScale(
                  scale: _isPressed ? 0.9 : 1.0,
                  duration: const Duration(milliseconds: 100),
                  child: Icon(
                    widget.icon,
                    size: 20,
                    color: widget.enabled
                        ? (_isHovered
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant)
                        : colorScheme.onSurfaceVariant.withOpacity(0.4),
                  ),
                ),
                // 数量徽章
                if (widget.badge != null)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.badge!,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 操作历史下拉菜单
class HistoryDropdown<T> extends StatelessWidget {
  const HistoryDropdown({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.onSelect,
    this.title = '操作历史',
    this.emptyMessage = '无历史记录',
  });

  final List<T> items;
  final Widget Function(T item, int index) itemBuilder;
  final void Function(int index) onSelect;
  final String title;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: 280,
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.history,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${items.length} 项',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // 列表
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                emptyMessage,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return _HistoryItem(
                    index: index,
                    onTap: () => onSelect(index),
                    child: itemBuilder(items[index], index),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryItem extends StatefulWidget {
  const _HistoryItem({
    required this.index,
    required this.onTap,
    required this.child,
  });

  final int index;
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_HistoryItem> createState() => _HistoryItemState();
}

class _HistoryItemState extends State<_HistoryItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _isHovered
                ? colorScheme.primary.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${widget.index + 1}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: widget.child),
            ],
          ),
        ),
      ),
    );
  }
}
