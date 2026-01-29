import 'package:flutter/material.dart';

import '../../common/elevated_card.dart';

/// 可拖拽网格组件
///
/// 支持拖拽排序的网格布局，用于重新排列类别和标签组
class DraggableGrid<T> extends StatefulWidget {
  const DraggableGrid({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.onReorder,
    required this.idGetter,
    this.crossAxisCount = 4,
    this.mainAxisSpacing = 12,
    this.crossAxisSpacing = 12,
    this.childAspectRatio = 1.0,
    this.padding = const EdgeInsets.all(16),
    this.enabled = true,
  });

  /// 项目列表
  final List<T> items;

  /// 构建每个项目的 Widget
  final Widget Function(T item, int index, bool isDragging) itemBuilder;

  /// 重新排序回调
  final void Function(int oldIndex, int newIndex) onReorder;

  /// 获取项目 ID
  final String Function(T item) idGetter;

  /// 每行项目数
  final int crossAxisCount;

  /// 主轴间距
  final double mainAxisSpacing;

  /// 交叉轴间距
  final double crossAxisSpacing;

  /// 子项宽高比
  final double childAspectRatio;

  /// 内边距
  final EdgeInsets padding;

  /// 是否启用拖拽
  final bool enabled;

  @override
  State<DraggableGrid<T>> createState() => _DraggableGridState<T>();
}

class _DraggableGridState<T> extends State<DraggableGrid<T>> {
  String? _draggingId;
  int? _targetIndex;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: widget.crossAxisCount,
          mainAxisSpacing: widget.mainAxisSpacing,
          crossAxisSpacing: widget.crossAxisSpacing,
          childAspectRatio: widget.childAspectRatio,
        ),
        itemCount: widget.items.length,
        itemBuilder: (context, index) {
          final item = widget.items[index];
          final id = widget.idGetter(item);
          final isDragging = _draggingId == id;
          final isTarget = _targetIndex == index;

          return _DraggableItem<T>(
            item: item,
            index: index,
            id: id,
            isDragging: isDragging,
            isTarget: isTarget,
            enabled: widget.enabled,
            itemBuilder: widget.itemBuilder,
            onDragStarted: () {
              setState(() => _draggingId = id);
            },
            onDragEnd: () {
              setState(() {
                _draggingId = null;
                _targetIndex = null;
              });
            },
            onDragTargetEnter: () {
              setState(() => _targetIndex = index);
            },
            onDragTargetLeave: () {
              if (_targetIndex == index) {
                setState(() => _targetIndex = null);
              }
            },
            onAccept: (fromIndex) {
              if (fromIndex != index) {
                widget.onReorder(fromIndex, index);
              }
            },
          );
        },
      ),
    );
  }
}

/// 可拖拽项目组件
class _DraggableItem<T> extends StatefulWidget {
  const _DraggableItem({
    required this.item,
    required this.index,
    required this.id,
    required this.isDragging,
    required this.isTarget,
    required this.enabled,
    required this.itemBuilder,
    required this.onDragStarted,
    required this.onDragEnd,
    required this.onDragTargetEnter,
    required this.onDragTargetLeave,
    required this.onAccept,
  });

  final T item;
  final int index;
  final String id;
  final bool isDragging;
  final bool isTarget;
  final bool enabled;
  final Widget Function(T item, int index, bool isDragging) itemBuilder;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnd;
  final VoidCallback onDragTargetEnter;
  final VoidCallback onDragTargetLeave;
  final void Function(int fromIndex) onAccept;

  @override
  State<_DraggableItem<T>> createState() => _DraggableItemState<T>();
}

class _DraggableItemState<T> extends State<_DraggableItem<T>> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // 构建子组件
    final child =
        widget.itemBuilder(widget.item, widget.index, widget.isDragging);

    // 目标指示器
    final targetIndicator = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isTarget ? colorScheme.primary : Colors.transparent,
          width: 2,
        ),
        boxShadow: widget.isTarget
            ? [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.2),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
    );

    if (!widget.enabled) {
      return child;
    }

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) {
        widget.onDragTargetEnter();
        return true;
      },
      onLeave: (_) => widget.onDragTargetLeave(),
      onAcceptWithDetails: (details) => widget.onAccept(details.data),
      builder: (context, candidateData, rejectedData) {
        return LongPressDraggable<int>(
          data: widget.index,
          delay: const Duration(milliseconds: 150),
          onDragStarted: widget.onDragStarted,
          onDragEnd: (_) => widget.onDragEnd(),
          feedback: Material(
            color: Colors.transparent,
            child: Transform.scale(
              scale: 1.05,
              child: Opacity(
                opacity: 0.9,
                child: SizedBox(
                  width: 150,
                  height: 150,
                  child: ElevatedCard(
                    elevation: CardElevation.level4,
                    borderRadius: 12,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: child,
          ),
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: Stack(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  transform: Matrix4.identity()..scale(_isHovered ? 1.02 : 1.0),
                  transformAlignment: Alignment.center,
                  child: child,
                ),
                Positioned.fill(child: targetIndicator),
                // 拖拽手柄指示
                if (_isHovered)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withOpacity(0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.drag_indicator,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 可拖拽列表组件
///
/// 垂直列表的拖拽排序
class DraggableList<T> extends StatefulWidget {
  const DraggableList({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.onReorder,
    required this.idGetter,
    this.itemHeight = 60,
    this.spacing = 8,
    this.padding = const EdgeInsets.all(16),
    this.enabled = true,
  });

  final List<T> items;
  final Widget Function(T item, int index, bool isDragging) itemBuilder;
  final void Function(int oldIndex, int newIndex) onReorder;
  final String Function(T item) idGetter;
  final double itemHeight;
  final double spacing;
  final EdgeInsets padding;
  final bool enabled;

  @override
  State<DraggableList<T>> createState() => _DraggableListState<T>();
}

class _DraggableListState<T> extends State<DraggableList<T>> {
  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: widget.padding,
        itemCount: widget.items.length,
        separatorBuilder: (_, __) => SizedBox(height: widget.spacing),
        itemBuilder: (context, index) {
          return SizedBox(
            height: widget.itemHeight,
            child: widget.itemBuilder(widget.items[index], index, false),
          );
        },
      );
    }

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: widget.padding,
      itemCount: widget.items.length,
      onReorder: widget.onReorder,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, animChild) {
            final scale =
                Tween<double>(begin: 1.0, end: 1.02).evaluate(animation);
            return Transform.scale(
              scale: scale,
              child: Material(
                color: Colors.transparent,
                child: ElevatedCard(
                  elevation: CardElevation.level3,
                  borderRadius: 10,
                  child: animChild ?? const SizedBox.shrink(),
                ),
              ),
            );
          },
          child: child,
        );
      },
      itemBuilder: (context, index) {
        return Container(
          key: ValueKey(widget.idGetter(widget.items[index])),
          height: widget.itemHeight,
          margin: EdgeInsets.only(bottom: widget.spacing),
          child: widget.itemBuilder(widget.items[index], index, false),
        );
      },
    );
  }
}
