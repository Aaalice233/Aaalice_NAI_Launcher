import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/layout_state_provider.dart';
import 'fixed_tags_sidebar.dart';
import 'resize_handle.dart';

/// 固定标签侧栏插槽（经典布局与官网式布局共用）
///
/// 自管理拖拽宽度与动画状态；侧栏收起时渲染为空。
class FixedTagsSidebarSlot extends ConsumerStatefulWidget {
  const FixedTagsSidebarSlot({super.key});

  @override
  ConsumerState<FixedTagsSidebarSlot> createState() =>
      _FixedTagsSidebarSlotState();
}

class _FixedTagsSidebarSlotState extends ConsumerState<FixedTagsSidebarSlot> {
  static const double _minWidth = 240;
  static const double _maxWidth = 400;

  bool _isResizing = false;

  @override
  Widget build(BuildContext context) {
    final layoutState = ref.watch(layoutStateNotifierProvider);
    if (!layoutState.fixedTagsSidebarExpanded) {
      return const SizedBox.shrink();
    }

    final width = layoutState.fixedTagsSidebarWidth;
    final decoration = BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(
        right: BorderSide(color: Theme.of(context).dividerColor),
      ),
    );
    final child = FixedTagsSidebar(isResizing: _isResizing);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isResizing)
          Container(width: width, decoration: decoration, child: child)
        else
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: width,
            decoration: decoration,
            child: child,
          ),
        ResizeHandle(
          onDragStart: () => setState(() => _isResizing = true),
          onDragEnd: () => setState(() => _isResizing = false),
          onDrag: (dx) {
            final currentWidth = ref
                .read(layoutStateNotifierProvider)
                .fixedTagsSidebarWidth;
            final newWidth = (currentWidth + dx).clamp(_minWidth, _maxWidth);
            ref
                .read(layoutStateNotifierProvider.notifier)
                .setFixedTagsSidebarWidth(newWidth.toDouble());
          },
        ),
      ],
    );
  }
}
