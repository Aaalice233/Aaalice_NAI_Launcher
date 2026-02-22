import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

/// 虚拟化瀑布流网格组件
///
/// 基于 index-based 的虚拟化方案，只渲染可视区域内的子元素，
/// 大幅优化大数据量场景下的内存占用和滚动性能。
///
/// 性能优化：
/// - 使用 MasonryGridView.builder 实现按需渲染
/// - 支持 addAutomaticKeepAlives 控制内存释放策略
/// - 支持 addRepaintBoundaries 减少重绘范围
/// - 支持 cacheExtent 控制预渲染范围
class VirtualizedMasonryGrid extends StatelessWidget {
  /// 子元素总数
  final int itemCount;

  /// 列数
  final int crossAxisCount;

  /// 子元素构建器，根据索引返回对应的 Widget
  final IndexedWidgetBuilder itemBuilder;

  /// 主轴间距（垂直方向）
  final double mainAxisSpacing;

  /// 交叉轴间距（水平方向）
  final double crossAxisSpacing;

  /// 内边距
  final EdgeInsetsGeometry? padding;

  /// 滚动控制器
  final ScrollController? controller;

  /// 是否保持超出可视区域的状态（AutomaticKeepAlive）
  /// 设为 false 可在滚动出可视区域时释放状态以节省内存
  final bool addAutomaticKeepAlives;

  /// 是否添加重绘边界（RepaintBoundary）
  /// 设为 true 可减少滚动时的重绘范围
  final bool addRepaintBoundaries;

  /// 是否添加语义索引
  final bool addSemanticIndexes;

  /// 语义索引偏移
  final int semanticChildCount;

  /// 反向滚动（从底部开始）
  final bool reverse;

  /// 滚动方向
  final Axis scrollDirection;

  /// 物理滚动效果
  final ScrollPhysics? physics;

  /// 是否允许滚动超出边界
  final bool? primary;

  /// 预渲染范围（像素）
  final double? cacheExtent;

  /// 拖拽时保持活动状态的委托
  final DragStartBehavior dragStartBehavior;

  /// 键盘取消行为
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  /// 恢复滚动位置的标识
  final String? restorationId;

  /// 裁剪行为
  final Clip clipBehavior;

  /// 额外的尾部元素（如加载指示器）
  /// 会在 itemCount 之后显示
  final Widget? footerWidget;

  const VirtualizedMasonryGrid({
    super.key,
    required this.itemCount,
    required this.crossAxisCount,
    required this.itemBuilder,
    this.mainAxisSpacing = 0.0,
    this.crossAxisSpacing = 0.0,
    this.padding,
    this.controller,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
    this.semanticChildCount = 0,
    this.reverse = false,
    this.scrollDirection = Axis.vertical,
    this.physics,
    this.primary,
    this.cacheExtent,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
    this.footerWidget,
  });

  @override
  Widget build(BuildContext context) {
    final totalItemCount = footerWidget != null ? itemCount + 1 : itemCount;

    return MasonryGridView.builder(
      controller: controller,
      padding: padding,
      gridDelegate: SliverSimpleGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
      ),
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
      itemCount: totalItemCount,
      itemBuilder: (context, index) {
        // 尾部元素
        if (footerWidget != null && index == itemCount) {
          return footerWidget!;
        }
        return itemBuilder(context, index);
      },
      addAutomaticKeepAlives: addAutomaticKeepAlives,
      addRepaintBoundaries: addRepaintBoundaries,
      addSemanticIndexes: addSemanticIndexes,
      // semanticChildCount 应该与 itemCount 一致（包含 footer）
      semanticChildCount: semanticChildCount > 0 ? semanticChildCount : totalItemCount,
      reverse: reverse,
      scrollDirection: scrollDirection,
      physics: physics ?? const AlwaysScrollableScrollPhysics(),
      primary: primary,
      cacheExtent: cacheExtent,
      dragStartBehavior: dragStartBehavior,
      keyboardDismissBehavior: keyboardDismissBehavior,
      restorationId: restorationId,
      clipBehavior: clipBehavior,
    );
  }
}

/// 带高度计算的虚拟化瀑布流网格
///
/// 适用于需要精确控制每个项目高度的场景，
/// 通过提供 aspectRatio 或固定高度来优化布局计算
class VirtualizedMasonryGridWithHeights extends StatelessWidget {
  /// 子元素总数
  final int itemCount;

  /// 列数
  final int crossAxisCount;

  /// 子元素构建器，根据索引返回对应的 Widget
  final IndexedWidgetBuilder itemBuilder;

  /// 获取每个项目的高度回调
  /// 返回 null 表示使用自适应高度
  final double? Function(int index)? itemHeightBuilder;

  /// 获取每个项目的宽高比回调
  /// 用于计算高度：height = width / aspectRatio
  final double? Function(int index)? itemAspectRatioBuilder;

  /// 默认高度（当高度回调返回 null 时使用）
  final double defaultHeight;

  /// 主轴间距（垂直方向）
  final double mainAxisSpacing;

  /// 交叉轴间距（水平方向）
  final double crossAxisSpacing;

  /// 内边距
  final EdgeInsetsGeometry? padding;

  /// 滚动控制器
  final ScrollController? controller;

  /// 是否保持超出可视区域的状态
  final bool addAutomaticKeepAlives;

  /// 是否添加重绘边界
  final bool addRepaintBoundaries;

  /// 预渲染范围（像素）
  final double? cacheExtent;

  /// 额外的尾部元素
  final Widget? footerWidget;

  const VirtualizedMasonryGridWithHeights({
    super.key,
    required this.itemCount,
    required this.crossAxisCount,
    required this.itemBuilder,
    this.itemHeightBuilder,
    this.itemAspectRatioBuilder,
    this.defaultHeight = 200.0,
    this.mainAxisSpacing = 0.0,
    this.crossAxisSpacing = 0.0,
    this.padding,
    this.controller,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.cacheExtent,
    this.footerWidget,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final itemWidth =
            (availableWidth - (crossAxisCount - 1) * crossAxisSpacing) /
                crossAxisCount;

        return VirtualizedMasonryGrid(
          itemCount: itemCount,
          crossAxisCount: crossAxisCount,
          itemBuilder: (context, index) {
            double? height;

            // 优先使用高度回调
            if (itemHeightBuilder != null) {
              height = itemHeightBuilder!(index);
            }

            // 其次使用宽高比计算
            if (height == null && itemAspectRatioBuilder != null) {
              final aspectRatio = itemAspectRatioBuilder!(index);
              // 检查 aspectRatio 是否有效：大于 0.01 避免溢出，小于 100 避免不合理值
              if (aspectRatio != null &&
                  aspectRatio > 0.01 &&
                  aspectRatio < 100) {
                height = itemWidth / aspectRatio;
              }
            }

            // 使用默认高度
            height ??= defaultHeight;

            return SizedBox(
              height: height,
              child: itemBuilder(context, index),
            );
          },
          mainAxisSpacing: mainAxisSpacing,
          crossAxisSpacing: crossAxisSpacing,
          padding: padding,
          controller: controller,
          addAutomaticKeepAlives: addAutomaticKeepAlives,
          addRepaintBoundaries: addRepaintBoundaries,
          cacheExtent: cacheExtent,
          footerWidget: footerWidget,
        );
      },
    );
  }
}

/// 用于性能监控的虚拟化瀑布流包装器
///
/// 仅在 debug 模式下输出渲染统计信息
class DebugVirtualizedMasonryGrid extends StatefulWidget {
  /// 子元素总数
  final int itemCount;

  /// 列数
  final int crossAxisCount;

  /// 子元素构建器
  final IndexedWidgetBuilder itemBuilder;

  /// 主轴间距
  final double mainAxisSpacing;

  /// 交叉轴间距
  final double crossAxisSpacing;

  /// 内边距
  final EdgeInsetsGeometry? padding;

  /// 滚动控制器
  final ScrollController? controller;

  /// 是否打印调试信息
  final bool enableDebugLogs;

  const DebugVirtualizedMasonryGrid({
    super.key,
    required this.itemCount,
    required this.crossAxisCount,
    required this.itemBuilder,
    this.mainAxisSpacing = 0.0,
    this.crossAxisSpacing = 0.0,
    this.padding,
    this.controller,
    this.enableDebugLogs = true,
  });

  @override
  State<DebugVirtualizedMasonryGrid> createState() =>
      _DebugVirtualizedMasonryGridState();
}

class _DebugVirtualizedMasonryGridState
    extends State<DebugVirtualizedMasonryGrid> {
  final Set<int> _renderedIndices = <int>{};
  DateTime? _lastLogTime;
  Timer? _cleanupTimer;

  @override
  void initState() {
    super.initState();
    // 每 30 秒清理一次已渲染索引集合，避免内存无限增长
    _cleanupTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _renderedIndices.clear();
    });
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    _renderedIndices.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VirtualizedMasonryGrid(
      itemCount: widget.itemCount,
      crossAxisCount: widget.crossAxisCount,
      itemBuilder: (context, index) {
        _trackRender(index);
        return widget.itemBuilder(context, index);
      },
      mainAxisSpacing: widget.mainAxisSpacing,
      crossAxisSpacing: widget.crossAxisSpacing,
      padding: widget.padding,
      controller: widget.controller,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
    );
  }

  void _trackRender(int index) {
    if (!widget.enableDebugLogs) return;

    _renderedIndices.add(index);

    // 每 2 秒输出一次统计
    final now = DateTime.now();
    if (_lastLogTime == null || now.difference(_lastLogTime!).inSeconds >= 2) {
      _lastLogTime = now;
      _logStats();
    }
  }

  void _logStats() {
    if (_renderedIndices.isEmpty) return;

    final sorted = _renderedIndices.toList()..sort();
    final minIndex = sorted.first;
    final maxIndex = sorted.last;

    debugPrint(
      '[VirtualizedMasonryGrid] 渲染统计: '
      '已渲染 ${sorted.length} / ${widget.itemCount} 项, '
      '范围: $minIndex-$maxIndex',
    );
  }
}
